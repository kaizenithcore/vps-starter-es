# shellcheck shell=bash
# Utilidades para las pruebas con bats.
#
# Cada prueba copia un escenario de tests/fixtures a una carpeta temporal:
#   raiz/    sistema de archivos falso (los scripts lo leen vía VPS_ROOT)
#   estado/  lo que devuelven los comandos simulados (sshd, ss, docker...)
# Los comandos que tocarían el sistema se sustituyen por simuladores que
# apuntan cada llamada en estado/llamadas.

RAIZ_REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Herramientas reales que los scripts pueden usar.
UTILIDADES="bash env awk grep sed cat sort uniq tr cut head tail wc dirname basename mktemp install cp mv rm mkdir chmod date sleep"

# preparar ESCENARIO [UID]
preparar() {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  rm -rf "$FIXTURE"
  cp -R "$RAIZ_REPO/tests/fixtures/$1" "$FIXTURE"
  ESTADO="$FIXTURE/estado"
  BIN="$BATS_TEST_TMPDIR/bin"
  rm -rf "$BIN"
  mkdir -p "$BIN"
  echo "${2:-0}" >"$ESTADO/uid"
  : >"$ESTADO/llamadas"

  local u real
  for u in $UTILIDADES; do
    real="$(command -v "$u" || true)"
    [ -n "$real" ] && ln -s "$real" "$BIN/$u"
  done
  crear_simuladores
  export FIXTURE ESTADO BIN
}

# ejecutar_script NOMBRE ARGS...  (con PATH limitado a los simuladores)
ejecutar_script() {
  local script="$1"
  shift
  run "$BIN/env" -i PATH="$BIN" VPS_ROOT="$FIXTURE/raiz" ESTADO="$ESTADO" NO_COLOR=1 \
    "$BIN/bash" "$RAIZ_REPO/scripts/$script" "$@"
}

# no_aparece PATRÓN ARCHIVO: falla si el patrón aparece.
# (En bats, una línea "! grep ..." que no es la última no hace fallar la prueba.)
no_aparece() {
  if grep -Eq -- "$1" "$2" 2>/dev/null; then
    echo "No debería aparecer '$1' en $2:" >&2
    grep -E -- "$1" "$2" >&2
    return 1
  fi
}

# Huella de todos los archivos del escenario (para comprobar que nada cambia).
huella() {
  (cd "$FIXTURE/raiz" && find . -type f -exec cksum {} + | sort)
}

simulador() {
  printf '#!%s\n' "$(command -v bash)" >"$BIN/$1"
  cat >>"$BIN/$1"
  chmod +x "$BIN/$1"
}

crear_simuladores() {
  simulador id <<'EOF'
echo "$(cat "$ESTADO/uid")"
EOF

  simulador sshd <<'EOF'
echo "sshd $*" >>"$ESTADO/llamadas"
case "$1" in
  -T) if [ -f "$ESTADO/sshd_T" ]; then cat "$ESTADO/sshd_T"; else exit 255; fi ;;
  -t) [ ! -f "$ESTADO/sshd_t_falla" ] ;;
esac
EOF

  simulador systemctl <<'EOF'
if [ "$1" = "is-active" ]; then
  grep -qx "${!#}" "$ESTADO/activos"
  exit
fi
echo "systemctl $*" >>"$ESTADO/llamadas"
case "$*" in
  *"--now"* | restart*) echo "${!#}" >>"$ESTADO/activos" ;;
esac
EOF

  simulador journalctl <<'EOF'
cat "$ESTADO/journal"
EOF

  simulador apt-get <<'EOF'
for a in "$@"; do
  if [ "$a" = "-s" ]; then cat "$ESTADO/apt_sim"; exit 0; fi
done
echo "apt-get $*" >>"$ESTADO/llamadas"
instalar=0
for a in "$@"; do
  if [ "$instalar" -eq 1 ] && [ "${a#-}" = "$a" ]; then echo "$a" >>"$ESTADO/paquetes"; fi
  [ "$a" = "install" ] && instalar=1
done
exit 0
EOF

  simulador dpkg-query <<'EOF'
if grep -qx "${!#}" "$ESTADO/paquetes"; then
  printf 'install ok installed'
else
  exit 1
fi
EOF

  simulador df <<'EOF'
case "$1" in
  -Pm) cat "$ESTADO/df_m" ;;
  *) cat "$ESTADO/df_k" ;;
esac
EOF

  simulador ss <<'EOF'
cat "$ESTADO/ss"
EOF

  simulador swapon <<'EOF'
if [ "$1" = "--show" ]; then cat "$ESTADO/swap"; exit 0; fi
echo "swapon $*" >>"$ESTADO/llamadas"
echo "$1 file 2G 0B -2" >>"$ESTADO/swap"
EOF

  simulador mkswap <<'EOF'
echo "mkswap $*" >>"$ESTADO/llamadas"
echo "$1" >>"$ESTADO/mkswap"
EOF

  simulador fallocate <<'EOF'
echo "fallocate $*" >>"$ESTADO/llamadas"
: >"${!#}"
EOF

  simulador blkid <<'EOF'
if grep -qx "${!#}" "$ESTADO/mkswap" 2>/dev/null; then echo swap; else exit 2; fi
EOF

  simulador sysctl <<'EOF'
echo "sysctl $*" >>"$ESTADO/llamadas"
EOF

  simulador getent <<'EOF'
if [ "$2" = "root" ]; then
  echo "root:x:0:0:root:/root:/bin/bash"
else
  echo "$2:x:1000:1000::/home/$2:/bin/bash"
fi
EOF

  if [ -f "$ESTADO/docker_ps" ]; then
    simulador docker <<'EOF'
case "$1" in
  info) exit 0 ;;
  ps) cat "$ESTADO/docker_ps" ;;
esac
EOF
  fi
}

#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# check.sh: revisa tu servidor SIN cambiar nada.
# Cada comprobación sale como [OK], [AVISO] o [FALLO], con qué significa y qué guía mirar.
#
# Uso:  sudo scripts/check.sh [--json] [--section NOMBRE[,NOMBRE...]]
#
# Código de salida: 0 todo OK, 1 hay AVISO, 2 hay FALLO, 3 error de uso.

set -uo pipefail

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR_SCRIPT/lib/common.sh"

SECCIONES_VALIDAS="sistema memoria disco ssh actualizaciones docker puertos firewall"

GUIA_00="docs/00-necesitas-un-vps.md"
GUIA_01="docs/01-conectar-al-servidor.md"
GUIA_02="docs/02-proteger-el-servidor.md"
GUIA_03="docs/03-firewall-de-hostinger.md"
GUIA_04="docs/04-vigilar-tu-servidor.md"
GUIA_99="docs/99-problemas-comunes.md"

FORMATO="texto"
SECCIONES_PEDIDAS=""
N_OK=0
N_AVISO=0
N_FALLO=0
JSON_ITEMS=()
COOLIFY_DETECTADO=0

uso() {
  cat <<'EOF'
check.sh: revisa tu servidor sin cambiar nada.

Uso:
  sudo scripts/check.sh                      Revisa todo.
  sudo scripts/check.sh --section ssh        Revisa solo una parte.
  sudo scripts/check.sh --section ssh,disco  Varias partes, separadas por comas.
  sudo scripts/check.sh --json               Resultado en JSON (para agentes).

Partes: sistema, memoria, disco, ssh, actualizaciones, docker, puertos, firewall.

Funciona sin sudo, pero entonces no puede revisar SSH ni los contenedores.

Código de salida: 0 todo OK, 1 hay algún AVISO, 2 hay algún FALLO, 3 error de uso.
EOF
}

# resultado ESTADO SECCION ID MENSAJE [GUIA]
resultado() {
  local estado="$1" seccion="$2" id="$3" mensaje="$4" guia="${5:-}"
  local color=""
  case "$estado" in
    OK) N_OK=$((N_OK + 1)); color="$C_VERDE" ;;
    AVISO) N_AVISO=$((N_AVISO + 1)); color="$C_AMARILLO" ;;
    FALLO) N_FALLO=$((N_FALLO + 1)); color="$C_ROJO" ;;
  esac

  if [ "$FORMATO" = "json" ]; then
    JSON_ITEMS+=("{\"seccion\":\"$seccion\",\"id\":\"$id\",\"estado\":\"$estado\",\"mensaje\":\"$(json_escape "$mensaje")\",\"guia\":\"$(json_escape "$guia")\"}")
    return
  fi

  printf '%s%-8s%s %s\n' "$color" "[$estado]" "$C_FIN" "$mensaje"
  if [ "$estado" != "OK" ] && [ -n "$guia" ]; then
    printf '         %sQué hacer: mira %s%s\n' "$C_GRIS" "$guia" "$C_FIN"
  fi
}

titulo() {
  [ "$FORMATO" = "texto" ] || return 0
  printf '\n%s%s%s\n' "$C_NEGRITA" "$1" "$C_FIN"
}

seccion_pedida() {
  [ -z "$SECCIONES_PEDIDAS" ] && return 0
  case ",$SECCIONES_PEDIDAS," in
    *",$1,"*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------- sistema

c_sistema() {
  titulo "Sistema"
  local os
  os="$(leer_os || true)"
  case "$os" in
    "ubuntu 24.04")
      resultado OK sistema version "Ubuntu 24.04, la versión para la que están escritas las guías."
      ;;
    ubuntu*)
      resultado AVISO sistema version "Es Ubuntu ${os#ubuntu }, no 24.04. Casi todo debería valer, pero las guías solo se han probado en 24.04." "$GUIA_00"
      ;;
    *)
      resultado AVISO sistema version "No es Ubuntu (${os:-desconocido}). Las guías están pensadas para Ubuntu 24.04." "$GUIA_00"
      ;;
  esac
}

# ---------------------------------------------------------------- memoria

valor_meminfo() {
  awk -v k="$1:" '$1 == k { print $2; exit }' "$(ruta /proc/meminfo)" 2>/dev/null
}

c_memoria() {
  titulo "Memoria"
  local total disponible swap swappiness pct oom
  total="$(valor_meminfo MemTotal)"
  disponible="$(valor_meminfo MemAvailable)"
  swap="$(valor_meminfo SwapTotal)"

  if [ -z "$total" ]; then
    resultado AVISO memoria lectura "No se pudo leer la memoria del sistema." "$GUIA_99"
    return
  fi

  pct=$((disponible * 100 / total))
  if [ "$pct" -lt 10 ]; then
    resultado AVISO memoria libre "Queda poca memoria libre ($pct %). Si se llena, el sistema empezará a cerrar programas." "$GUIA_99#el-sistema-mata-procesos-por-falta-de-memoria"
  else
    resultado OK memoria libre "Memoria: $((total / 1024)) MB en total, $pct % libre."
  fi

  if [ "${swap:-0}" -eq 0 ]; then
    resultado AVISO memoria swap "No hay memoria de intercambio (swap). Es un colchón en disco: sin él, si la memoria se llena, el sistema mata procesos." "$GUIA_02#memoria-de-intercambio-swap"
  else
    resultado OK memoria swap "Hay memoria de intercambio (swap) de $((swap / 1024)) MB."
    swappiness="$(cat "$(ruta /proc/sys/vm/swappiness)" 2>/dev/null || true)"
    if [ -n "$swappiness" ] && [ "$swappiness" -gt 30 ]; then
      resultado AVISO memoria swappiness "El sistema usa la swap demasiado pronto (swappiness=$swappiness). Lo recomendable en un servidor es 10." "$GUIA_02#memoria-de-intercambio-swap"
    fi
  fi

  if hay_comando journalctl; then
    oom="$(journalctl -k --since "-7d" --no-pager -q 2>/dev/null | grep -Eci 'out of memory|oom-kill|killed process' || true)"
    oom="${oom:-0}"
    if [ "$oom" -gt 0 ]; then
      resultado AVISO memoria oom "En los últimos 7 días el sistema ha cerrado programas por falta de memoria ($oom avisos en el registro)." "$GUIA_99#el-sistema-mata-procesos-por-falta-de-memoria"
    else
      resultado OK memoria oom "Ningún programa cerrado por falta de memoria en los últimos 7 días."
    fi
  fi
}

# ---------------------------------------------------------------- disco

c_disco() {
  titulo "Disco"
  local linea uso libre_kb
  linea="$(df -Pk "$(ruta /)" 2>/dev/null | awk 'NR == 2 { gsub("%", "", $5); print $5, $4 }')"
  if [ -z "$linea" ]; then
    resultado AVISO disco lectura "No se pudo leer el uso del disco." "$GUIA_99"
    return
  fi
  uso="${linea% *}"
  libre_kb="${linea#* }"
  local libre_gb=$((libre_kb / 1024 / 1024))
  if [ "$uso" -ge 90 ]; then
    resultado FALLO disco uso "El disco está al $uso % (quedan $libre_gb GB). Con el disco lleno, las apps y las bases de datos dejan de funcionar." "$GUIA_99#disco-lleno"
  elif [ "$uso" -ge 80 ]; then
    resultado AVISO disco uso "El disco está al $uso % (quedan $libre_gb GB). Conviene liberar espacio pronto." "$GUIA_99#disco-lleno"
  else
    resultado OK disco uso "Disco al $uso %, quedan $libre_gb GB libres."
  fi
}

# ---------------------------------------------------------------- ssh

# Lee la configuración de SSH de sus archivos, como lo hace sshd:
# sigue los Include en orden y, para cada opción, gana el PRIMER valor.
# Imprime "opción valor" en minúsculas, una por línea.
leer_config_ssh_archivos() {
  local principal
  principal="$(ruta /etc/ssh/sshd_config)"
  [ -r "$principal" ] || return 1
  _leer_archivo_ssh "$principal" | awk '!visto[$1]++'
}

_leer_archivo_ssh() {
  local clave resto patron f
  local -a patrones archivos
  while read -r clave resto || [ -n "$clave" ]; do
    clave="${clave,,}"
    case "$clave" in
      "" | \#*) continue ;;
      match) return 0 ;; # lo que sigue a Match solo vale para casos concretos
      include)
        # read -a separa sin expandir el *: la expansión se hace después,
        # ya dentro de VPS_ROOT (si no, en las pruebas miraría el /etc real).
        read -r -a patrones <<<"$resto"
        for patron in "${patrones[@]}"; do
          [[ "$patron" == /* ]] || patron="/etc/ssh/$patron"
          # Ordenados como lo hace sshd: el orden decide qué valor gana.
          mapfile -t archivos < <(compgen -G "$(ruta "$patron")" | LC_ALL=C sort)
          for f in "${archivos[@]}"; do
            if [ -f "$f" ]; then _leer_archivo_ssh "$f"; fi
          done
        done
        ;;
      *) printf '%s %s\n' "$clave" "${resto,,}" ;;
    esac
  done <"$1"
}

c_ssh() {
  titulo "Acceso por SSH"
  local sshd_bin conf pass kbd root

  sshd_bin="$(command -v sshd || true)"
  if [ -z "$sshd_bin" ] && [ -x "$(ruta /usr/sbin/sshd)" ]; then
    sshd_bin="$(ruta /usr/sbin/sshd)"
  fi

  if [ -z "$sshd_bin" ]; then
    resultado AVISO ssh servidor "No se encontró el servidor SSH. Es raro en un VPS: comprueba cómo entras al servidor." "$GUIA_01"
  elif ! es_root; then
    resultado AVISO ssh permisos "Para revisar SSH hace falta sudo. Ejecuta: sudo scripts/check.sh" "$GUIA_02"
  else
    conf="$("$sshd_bin" -T 2>/dev/null || true)"
    if [ -z "$conf" ]; then
      # sshd -T falla si SSH aún no ha arrancado (en Ubuntu 24.04 arranca bajo demanda).
      conf="$(leer_config_ssh_archivos || true)"
    fi
    if [ -z "$conf" ]; then
      resultado AVISO ssh lectura "No se pudo leer la configuración de SSH." "$GUIA_99"
    else
      pass="$(awk '$1 == "passwordauthentication" { print $2; exit }' <<<"$conf")"
      kbd="$(awk '$1 == "kbdinteractiveauthentication" { print $2; exit }' <<<"$conf")"
      root="$(awk '$1 == "permitrootlogin" { print $2; exit }' <<<"$conf")"
      # Valores por defecto de OpenSSH si ningún archivo los fija.
      pass="${pass:-yes}"
      kbd="${kbd:-yes}"
      root="${root:-prohibit-password}"

      if [ "$pass" = "yes" ]; then
        resultado FALLO ssh contrasena "SSH acepta contraseñas. Cualquiera en Internet puede intentar adivinarlas; con clave no." "$GUIA_02#ssh-solo-con-clave"
      elif [ "$kbd" = "yes" ]; then
        resultado FALLO ssh contrasena "SSH acepta contraseñas por otra vía (teclado interactivo). Hay que desactivarla también." "$GUIA_02#ssh-solo-con-clave"
      else
        resultado OK ssh contrasena "SSH no acepta contraseñas: solo se entra con clave."
      fi

      case "$root" in
        yes)
          resultado FALLO ssh root "El usuario root puede entrar con contraseña. Es el primer usuario que prueban los ataques." "$GUIA_02#ssh-solo-con-clave"
          ;;
        no)
          resultado OK ssh root "El usuario root no puede entrar por SSH."
          ;;
        prohibit-password | without-password | forced-commands-only)
          resultado OK ssh root "El usuario root solo puede entrar con clave."
          ;;
        *)
          resultado AVISO ssh root "Valor inesperado para el acceso de root: '${root:-vacío}'." "$GUIA_02#ssh-solo-con-clave"
          ;;
      esac
    fi
  fi

  if hay_comando systemctl; then
    if systemctl is-active --quiet fail2ban; then
      resultado OK ssh fail2ban "fail2ban está activo: bloquea durante un rato a quien falla muchas veces al entrar."
    else
      resultado AVISO ssh fail2ban "fail2ban no está activo. Es un vigilante que bloquea a quien prueba contraseñas una y otra vez." "$GUIA_02#vigilante-de-intentos-fail2ban"
    fi
  fi
}

# ---------------------------------------------------------------- actualizaciones

c_actualizaciones() {
  titulo "Actualizaciones"
  local auto_conf pendientes seguridad simulacion
  auto_conf="$(ruta /etc/apt/apt.conf.d/20auto-upgrades)"

  if hay_comando dpkg-query && paquete_instalado unattended-upgrades \
    && grep -Eq '^[[:space:]]*APT::Periodic::Unattended-Upgrade[[:space:]]+"1"' "$auto_conf" 2>/dev/null; then
    resultado OK actualizaciones automaticas "Las actualizaciones de seguridad se instalan solas cada día."
  else
    resultado AVISO actualizaciones automaticas "Las actualizaciones automáticas de seguridad no están activadas." "$GUIA_02#actualizaciones-automáticas"
  fi

  if hay_comando apt-get; then
    simulacion="$(apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null || true)"
    pendientes="$(grep -c '^Inst ' <<<"$simulacion" || true)"
    seguridad="$(grep -c '^Inst .*-security' <<<"$simulacion" || true)"
    pendientes="${pendientes:-0}"
    seguridad="${seguridad:-0}"
    if [ "$pendientes" -gt 0 ]; then
      resultado AVISO actualizaciones pendientes "Hay $pendientes actualizaciones pendientes ($seguridad de seguridad), según la última vez que el sistema buscó." "$GUIA_02#actualizaciones-automáticas"
    else
      resultado OK actualizaciones pendientes "No hay actualizaciones pendientes (según la última vez que el sistema buscó)."
    fi
  fi

  if [ -f "$(ruta /var/run/reboot-required)" ]; then
    resultado AVISO actualizaciones reinicio "El servidor necesita reiniciarse para terminar de aplicar actualizaciones. Hazlo en un momento tranquilo." "$GUIA_99#hay-que-reiniciar-el-servidor"
  else
    resultado OK actualizaciones reinicio "No hace falta reiniciar."
  fi
}

# ---------------------------------------------------------------- docker

detectar_coolify() {
  [ -d "$(ruta /data/coolify/source)" ] && COOLIFY_DETECTADO=1
  return 0
}

c_docker() {
  titulo "Contenedores (Docker)"
  local lista nombre estado detalle parados=() reiniciando=() enfermos=() total=0

  if ! hay_comando docker; then
    resultado OK docker instalado "Docker no está instalado. No hace falta para las guías 00 a 03."
    return
  fi

  if ! docker info >/dev/null 2>&1; then
    if es_root; then
      resultado FALLO docker servicio "Docker está instalado pero no responde. Tus apps en contenedores no funcionarán." "$GUIA_99#docker-no-responde"
    else
      resultado AVISO docker permisos "Para revisar los contenedores hace falta sudo. Ejecuta: sudo scripts/check.sh" "$GUIA_99"
    fi
    return
  fi

  lista="$(docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' 2>/dev/null || true)"
  while IFS='|' read -r nombre estado detalle; do
    [ -n "$nombre" ] || continue
    total=$((total + 1))
    [ "$nombre" = "coolify" ] && COOLIFY_DETECTADO=1
    case "$estado" in
      running)
        case "$detalle" in
          *"(unhealthy)"*) enfermos+=("$nombre") ;;
        esac
        ;;
      restarting) reiniciando+=("$nombre") ;;
      *) parados+=("$nombre") ;;
    esac
  done <<<"$lista"

  if [ "$total" -eq 0 ]; then
    resultado OK docker contenedores "Docker funciona y no hay contenedores todavía."
  elif [ "${#parados[@]}" -eq 0 ] && [ "${#reiniciando[@]}" -eq 0 ] && [ "${#enfermos[@]}" -eq 0 ]; then
    if [ "$total" -eq 1 ]; then
      resultado OK docker contenedores "El contenedor está en marcha."
    else
      resultado OK docker contenedores "Los $total contenedores están en marcha."
    fi
  fi
  if [ "${#reiniciando[@]}" -gt 0 ]; then
    resultado FALLO docker reiniciando "Contenedores que arrancan y se caen una y otra vez: ${reiniciando[*]}." "$GUIA_99#un-contenedor-se-reinicia-sin-parar"
  fi
  if [ "${#enfermos[@]}" -gt 0 ]; then
    resultado AVISO docker salud "Contenedores en marcha pero que dicen no estar bien: ${enfermos[*]}." "$GUIA_99#un-contenedor-se-reinicia-sin-parar"
  fi
  if [ "${#parados[@]}" -gt 0 ]; then
    resultado AVISO docker parados "Contenedores parados: ${parados[*]}. Si no los paraste tú, algo ha fallado." "$GUIA_99"
  fi

  detectar_coolify
  if [ "$COOLIFY_DETECTADO" -eq 1 ]; then
    c_coolify "$lista"
  fi
}

c_coolify() {
  local lista="$1"
  en_marcha() { grep -q "^$1|running|" <<<"$lista"; }
  if ! en_marcha coolify; then
    resultado FALLO docker coolify "Coolify está instalado pero su panel está parado. Tus apps pueden seguir funcionando, pero no podrás gestionarlas." "$GUIA_99#el-panel-de-coolify-no-carga"
  elif ! en_marcha coolify-proxy; then
    resultado FALLO docker coolify-proxy "El proxy de Coolify (el que da paso a tus apps desde Internet) está parado." "$GUIA_99#el-panel-de-coolify-no-carga"
  else
    resultado OK docker coolify "Coolify detectado y en marcha. (La guía de Coolify llegará en una versión futura.)"
  fi
}

# ---------------------------------------------------------------- puertos

# Puertos TCP a los que se puede llegar desde Internet, uno por línea.
# Se ignoran los que solo escuchan dentro del servidor o en redes privadas.
puertos_publicos() {
  ss -Hltn 2>/dev/null | awk '{ print $4 }' | while read -r direccion; do
    local host="${direccion%:*}" puerto="${direccion##*:}"
    host="${host%%\%*}" # quita el nombre de interfaz (127.0.0.53%lo)
    case "$host" in
      127.* | "[::1]" | "[::ffff:127."*) continue ;;
      10.* | 192.168.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[01].*) continue ;;
      100.6[4-9].* | 100.[7-9][0-9].* | 100.1[01][0-9].* | 100.12[0-7].*) continue ;;
      "[fe80:"* | "[fd"* | "[fc"*) continue ;;
    esac
    printf '%s\n' "$puerto"
  done | sort -un
}

c_puertos() {
  titulo "Puertos abiertos"
  local puertos puerto esperados="22 80 443" raros=0

  if ! hay_comando ss; then
    resultado AVISO puertos lectura "No se pudo comprobar qué puertos escuchan (falta el programa ss)." "$GUIA_03"
    return
  fi

  detectar_coolify
  if [ "$COOLIFY_DETECTADO" -eq 1 ]; then
    esperados="$esperados 8000 6001 6002"
  fi

  puertos="$(puertos_publicos)"
  for puerto in $puertos; do
    case " $esperados " in
      *" $puerto "*) continue ;;
    esac
    raros=$((raros + 1))
    case "$puerto" in
      8080)
        resultado AVISO puertos "p$puerto" "El puerto 8080 escucha hacia Internet. Suele ser el panel del proxy de Coolify: ciérralo en el firewall de Hostinger." "$GUIA_03"
        ;;
      3001)
        resultado AVISO puertos "p$puerto" "El puerto 3001 (Uptime Kuma) escucha hacia Internet. Asegúrate de que en el firewall de Hostinger solo tu IP puede entrar." "$GUIA_04"
        ;;
      *)
        resultado AVISO puertos "p$puerto" "El puerto $puerto escucha hacia Internet y no es de los habituales. Si no sabes qué es, ciérralo en el firewall de Hostinger." "$GUIA_03"
        ;;
    esac
  done

  if [ "$raros" -eq 0 ]; then
    if [ -z "$puertos" ]; then
      resultado OK puertos esperados "Ningún puerto escucha hacia Internet."
    else
      resultado OK puertos esperados "Solo escuchan hacia Internet los puertos esperados: ${puertos//$'\n'/, }."
    fi
  fi
}

# ---------------------------------------------------------------- firewall

c_firewall() {
  titulo "Firewall"
  resultado AVISO firewall externo "El firewall de Hostinger no se ve desde dentro del servidor. Revísalo en hPanel: permite 22, 80 y 443 (y 8000, 6001 y 6002 si usas Coolify) y nada más." "$GUIA_03"

  if grep -Eq '^[[:space:]]*ENABLED=yes' "$(ruta /etc/ufw/ufw.conf)" 2>/dev/null; then
    if hay_comando docker; then
      resultado AVISO firewall ufw "ufw está activo, pero Docker publica puertos saltándose sus reglas. No confíes solo en él: usa el firewall de Hostinger." "$GUIA_03"
    else
      resultado OK firewall ufw "ufw está activo."
    fi
  fi
}

# ---------------------------------------------------------------- principal

imprimir_json() {
  local i primero=1
  printf '{"resumen":{"ok":%d,"aviso":%d,"fallo":%d},"comprobaciones":[' "$N_OK" "$N_AVISO" "$N_FALLO"
  for i in "${JSON_ITEMS[@]}"; do
    if [ "$primero" -eq 1 ]; then primero=0; else printf ','; fi
    printf '%s' "$i"
  done
  printf ']}\n'
}

imprimir_resumen() {
  printf '\n%sResumen:%s %d OK, %d AVISO, %d FALLO.\n' "$C_NEGRITA" "$C_FIN" "$N_OK" "$N_AVISO" "$N_FALLO"
  if [ "$N_FALLO" -gt 0 ]; then
    printf 'Hay cosas que arreglar. Empieza por las líneas [FALLO].\n'
  elif [ "$N_AVISO" -gt 0 ]; then
    printf 'Nada grave. Revisa los avisos cuando puedas.\n'
  else
    printf 'Todo en orden.\n'
  fi
  if ! es_root; then
    printf '%sConsejo: ejecuta con sudo para revisarlo todo.%s\n' "$C_GRIS" "$C_FIN"
  fi
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) FORMATO="json" ;;
      --section | --seccion)
        [ $# -ge 2 ] || { error "Falta el nombre de la parte después de $1."; exit 3; }
        SECCIONES_PEDIDAS="$2"
        shift
        ;;
      --section=* | --seccion=*) SECCIONES_PEDIDAS="${1#*=}" ;;
      -h | --help) uso; exit 0 ;;
      *) error "Opción desconocida: $1"; uso >&2; exit 3 ;;
    esac
    shift
  done

  if [ -n "$SECCIONES_PEDIDAS" ]; then
    local s
    for s in ${SECCIONES_PEDIDAS//,/ }; do
      case " $SECCIONES_VALIDAS " in
        *" $s "*) ;;
        *) error "Parte desconocida: $s. Valen: $SECCIONES_VALIDAS."; exit 3 ;;
      esac
    done
  fi

  seccion_pedida sistema && c_sistema
  seccion_pedida memoria && c_memoria
  seccion_pedida disco && c_disco
  seccion_pedida ssh && c_ssh
  seccion_pedida actualizaciones && c_actualizaciones
  seccion_pedida docker && c_docker
  seccion_pedida puertos && c_puertos
  seccion_pedida firewall && c_firewall

  if [ "$FORMATO" = "json" ]; then
    imprimir_json
  else
    imprimir_resumen
  fi

  if [ "$N_FALLO" -gt 0 ]; then
    exit 2
  elif [ "$N_AVISO" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main "$@"

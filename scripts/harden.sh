#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# harden.sh: protege un servidor Ubuntu 24.04 nuevo.
#
# Por defecto SOLO SIMULA: enseña lo que haría y no cambia nada.
#   --apply       aplica swap, fail2ban y actualizaciones automáticas.
#   --apply-ssh   aplica el cambio de SSH (solo con clave). Va aparte porque
#                 si algo sale mal puede dejarte fuera del servidor.
#
# Se puede ejecutar varias veces: lo que ya está hecho no se repite.
# Nunca reinicia el servidor; si hace falta, lo avisa.

set -euo pipefail

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR_SCRIPT/lib/common.sh"

APLICAR_BASE=0
APLICAR_SSH=0
SIMULAR_PEDIDO=0
TAMANO_SWAP="2G"
SIMULAR=1             # modo del paso en curso (1 = simular)
CAMBIOS_REALES=0      # cosas que ha cambiado esta ejecución
CAMBIOS_SIMULADOS=0   # cosas que cambiaría si se aplicara
APT_ACTUALIZADO=0

ARCHIVO_SSH="/etc/ssh/sshd_config.d/00-hardening.conf"
ARCHIVO_SYSCTL="/etc/sysctl.d/99-vps-starter.conf"
ARCHIVO_JAIL="/etc/fail2ban/jail.d/vps-starter.local"
ARCHIVO_AUTO="/etc/apt/apt.conf.d/20auto-upgrades"
ARCHIVO_SWAP="/swapfile"

uso() {
  cat <<'EOF'
harden.sh: protege un servidor Ubuntu 24.04 nuevo.

Uso:
  sudo scripts/harden.sh                 Simula: enseña lo que haría, no cambia nada.
  sudo scripts/harden.sh --apply         Aplica swap, fail2ban y actualizaciones automáticas.
  sudo scripts/harden.sh --apply-ssh     Aplica el cambio de SSH (solo con clave).
                                         Lee antes la guía 02: puede dejarte fuera.

Opciones:
  --dry-run          Simular (es lo que hace sin opciones).
  --swap-size TAM    Tamaño de la swap, por ejemplo 1G, 2G o 512M. Por defecto 2G.
  -h, --help         Esta ayuda.

Se puede ejecutar varias veces sin problema. Nunca reinicia el servidor.
EOF
}

titulo() {
  printf '\n%s== %s ==%s\n' "$C_NEGRITA" "$1" "$C_FIN"
}

hecho() {
  printf '  %s✓%s %s\n' "$C_VERDE" "$C_FIN" "$1"
}

nota() {
  printf '  %s\n' "$1"
}

avisar() {
  printf '  %s!%s %s\n' "$C_AMARILLO" "$C_FIN" "$1"
}

contar_cambio() {
  if [ "$SIMULAR" -eq 1 ]; then
    CAMBIOS_SIMULADOS=$((CAMBIOS_SIMULADOS + 1))
  else
    CAMBIOS_REALES=$((CAMBIOS_REALES + 1))
  fi
}

# ejecutar CMD ARGS...: en simulación lo enseña; si no, lo ejecuta.
ejecutar() {
  contar_cambio
  if [ "$SIMULAR" -eq 1 ]; then
    printf '  %s[simulación]%s %s\n' "$C_GRIS" "$C_FIN" "$*"
    return 0
  fi
  printf '  → %s\n' "$*"
  "$@"
}

# asegurar_archivo RUTA CONTENIDO [PERMISOS]
# Escribe el archivo solo si su contenido es distinto. Deja ARCHIVO_CAMBIADO=1 si cambia.
ARCHIVO_CAMBIADO=0
asegurar_archivo() {
  local destino actual
  destino="$(ruta "$1")"
  ARCHIVO_CAMBIADO=0
  if [ -f "$destino" ]; then
    actual="$(cat "$destino")"
    if [ "$actual" = "$2" ]; then
      hecho "$1 ya estaba bien."
      return 0
    fi
  fi
  ARCHIVO_CAMBIADO=1
  contar_cambio
  if [ "$SIMULAR" -eq 1 ]; then
    printf '  %s[simulación]%s escribir %s con:\n' "$C_GRIS" "$C_FIN" "$1"
    printf '%s\n' "$2" | sed 's/^/      | /'
    return 0
  fi
  printf '  → escribir %s\n' "$1"
  mkdir -p "$(dirname "$destino")"
  local temporal
  temporal="$(mktemp)"
  printf '%s\n' "$2" >"$temporal"
  install -m "${3:-0644}" "$temporal" "$destino"
  rm -f "$temporal"
}

instalar_paquetes() {
  local faltan=() p
  for p in "$@"; do
    paquete_instalado "$p" || faltan+=("$p")
  done
  if [ "${#faltan[@]}" -eq 0 ]; then
    hecho "Ya instalado: $*."
    return 0
  fi
  if [ "$APT_ACTUALIZADO" -eq 0 ]; then
    ejecutar apt-get -o DPkg::Lock::Timeout=300 update -q
    APT_ACTUALIZADO=1
  fi
  ejecutar env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -q "${faltan[@]}"
}

servicio_activo() {
  systemctl is-active --quiet "$1" 2>/dev/null
}

# ---------------------------------------------------------------- comprobaciones previas

comprobar_sistema() {
  local os
  os="$(leer_os || true)"
  case "$os" in
    "ubuntu 24.04") hecho "Sistema: Ubuntu 24.04." ;;
    ubuntu*) avisar "Sistema: Ubuntu ${os#ubuntu }. El script está probado en 24.04; revisa bien la simulación." ;;
    *)
      if [ "$APLICAR_BASE" -eq 1 ] || [ "$APLICAR_SSH" -eq 1 ]; then
        morir "Este script es para Ubuntu y aquí hay '${os:-desconocido}'. No se aplica nada."
      fi
      avisar "Sistema: '${os:-desconocido}'. Este script es para Ubuntu 24.04."
      ;;
  esac
}

# ---------------------------------------------------------------- swap

paso_swap() {
  titulo "Memoria de intercambio (swap)"
  SIMULAR=$((1 - APLICAR_BASE))

  local activa mib libre_mib necesario_mib tipo
  activa="$(swapon --show --noheadings 2>/dev/null || true)"
  if [ -n "$activa" ]; then
    hecho "Ya hay swap activa; no se toca."
  elif [ -f "$(ruta "$ARCHIVO_SWAP")" ]; then
    tipo="$(blkid -o value -s TYPE "$(ruta "$ARCHIVO_SWAP")" 2>/dev/null || true)"
    if [ "$tipo" = "swap" ]; then
      nota "Existe $ARCHIVO_SWAP pero no está activo. Se activa."
      ejecutar swapon "$(ruta "$ARCHIVO_SWAP")"
    else
      avisar "Existe $ARCHIVO_SWAP pero no es un archivo de swap. No lo toco: revísalo a mano."
      return 0
    fi
  else
    mib="$(tamano_a_mib "$TAMANO_SWAP")"
    libre_mib="$(df -Pm "$(ruta /)" | awk 'NR == 2 { print $4 }')"
    necesario_mib=$((mib + 1024))
    if [ "${libre_mib:-0}" -lt "$necesario_mib" ]; then
      avisar "No hay disco suficiente para una swap de $TAMANO_SWAP (hay $libre_mib MB libres y hacen falta $necesario_mib MB contando 1 GB de margen). No se crea."
      return 0
    fi
    nota "Se crea una swap de $TAMANO_SWAP en $ARCHIVO_SWAP."
    if ! ejecutar fallocate -l "${mib}M" "$(ruta "$ARCHIVO_SWAP")"; then
      ejecutar dd if=/dev/zero of="$(ruta "$ARCHIVO_SWAP")" bs=1M count="$mib" status=none
    fi
    ejecutar chmod 600 "$(ruta "$ARCHIVO_SWAP")"
    ejecutar mkswap "$(ruta "$ARCHIVO_SWAP")"
    ejecutar swapon "$(ruta "$ARCHIVO_SWAP")"
  fi

  # Que siga activa después de reiniciar.
  local fstab
  fstab="$(ruta /etc/fstab)"
  if [ -f "$(ruta "$ARCHIVO_SWAP")" ] || [ "$SIMULAR" -eq 1 ]; then
    if grep -Eq "^[[:space:]]*${ARCHIVO_SWAP}[[:space:]]" "$fstab" 2>/dev/null; then
      hecho "La swap ya está en /etc/fstab (se activa al arrancar)."
    elif [ -n "$activa" ] && [[ "$activa" != *"$ARCHIVO_SWAP"* ]]; then
      : # Hay otra swap gestionada por el sistema: no tocamos fstab.
    else
      contar_cambio
      if [ "$SIMULAR" -eq 1 ]; then
        printf '  %s[simulación]%s añadir a /etc/fstab: %s none swap sw 0 0\n' "$C_GRIS" "$C_FIN" "$ARCHIVO_SWAP"
      else
        printf '  → añadir a /etc/fstab: %s none swap sw 0 0\n' "$ARCHIVO_SWAP"
        printf '%s none swap sw 0 0\n' "$ARCHIVO_SWAP" >>"$fstab"
      fi
    fi
  fi

  asegurar_archivo "$ARCHIVO_SYSCTL" "# Creado por vps-starter-es (scripts/harden.sh)
# Usar la swap solo cuando la memoria esté casi llena.
vm.swappiness=10"
  if [ "$ARCHIVO_CAMBIADO" -eq 1 ]; then
    ejecutar sysctl -q -p "$(ruta "$ARCHIVO_SYSCTL")"
  fi
}

# ---------------------------------------------------------------- fail2ban

paso_fail2ban() {
  titulo "Vigilante de intentos de entrada (fail2ban)"
  SIMULAR=$((1 - APLICAR_BASE))

  instalar_paquetes fail2ban python3-systemd
  asegurar_archivo "$ARCHIVO_JAIL" "# Creado por vps-starter-es (scripts/harden.sh)
# Bloquea 1 hora a quien falle 5 veces en 10 minutos al entrar por SSH.
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h"

  if [ "$ARCHIVO_CAMBIADO" -eq 1 ]; then
    ejecutar systemctl enable fail2ban
    ejecutar systemctl restart fail2ban
  elif ! servicio_activo fail2ban; then
    ejecutar systemctl enable --now fail2ban
  else
    hecho "fail2ban ya está activo."
  fi
}

# ---------------------------------------------------------------- actualizaciones

paso_actualizaciones() {
  titulo "Actualizaciones automáticas de seguridad"
  SIMULAR=$((1 - APLICAR_BASE))

  instalar_paquetes unattended-upgrades
  local conf
  conf="$(ruta "$ARCHIVO_AUTO")"
  if grep -Eq '^[[:space:]]*APT::Periodic::Update-Package-Lists[[:space:]]+"1"' "$conf" 2>/dev/null \
    && grep -Eq '^[[:space:]]*APT::Periodic::Unattended-Upgrade[[:space:]]+"1"' "$conf" 2>/dev/null; then
    hecho "Las actualizaciones automáticas ya estaban activadas."
  else
    asegurar_archivo "$ARCHIVO_AUTO" 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";'
  fi
  nota "El servidor no se reiniciará solo. Si una actualización lo pide, te lo dirá check.sh."
}

# ---------------------------------------------------------------- ssh

# Cuenta las claves públicas válidas de un archivo authorized_keys.
contar_claves() {
  grep -Ec '(^|[[:space:]])(ssh-(ed25519|rsa|dss)|ecdsa-sha2-nistp[0-9]+|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+AAAA' "$1" 2>/dev/null || true
}

comprobar_claves() {
  local usuario="${SUDO_USER:-root}" casa archivo n
  casa="$(getent passwd "$usuario" | cut -d: -f6)"
  if [ -z "$casa" ]; then
    avisar "No encuentro la carpeta personal de '$usuario'."
    return 1
  fi
  archivo="$(ruta "$casa/.ssh/authorized_keys")"
  n="$(contar_claves "$archivo")"
  if [ "${n:-0}" -gt 0 ]; then
    hecho "El usuario '$usuario' tiene $n clave(s) autorizada(s) para entrar."
    return 0
  fi
  avisar "El usuario '$usuario' no tiene ninguna clave autorizada en $casa/.ssh/authorized_keys."
  avisar "Si desactivo las contraseñas ahora, te quedarías fuera. Sigue antes la guía 01 para añadir tu clave."
  return 1
}

paso_ssh() {
  titulo "SSH: entrar solo con clave"
  SIMULAR=$((1 - APLICAR_SSH))

  if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$(ruta /etc/ssh/sshd_config)" 2>/dev/null; then
    avisar "La configuración de SSH no lee la carpeta sshd_config.d. No es la de Ubuntu 24.04: no toco nada."
    return 0
  fi

  if ! es_root; then
    avisar "Sin sudo no puedo comprobar tus claves. Ejecuta: sudo scripts/harden.sh"
    if [ "$APLICAR_SSH" -eq 1 ]; then
      morir "Para aplicar el cambio de SSH hace falta sudo."
    fi
  elif ! comprobar_claves; then
    if [ "$APLICAR_SSH" -eq 1 ]; then
      morir "No se cambia SSH: no hay ninguna clave con la que entrar después."
    fi
    return 0
  fi

  local anterior=""
  if [ -f "$(ruta "$ARCHIVO_SSH")" ]; then
    anterior="$(cat "$(ruta "$ARCHIVO_SSH")")"
  fi

  asegurar_archivo "$ARCHIVO_SSH" "# Creado por vps-starter-es (scripts/harden.sh)
# Solo se entra con clave. root puede entrar, pero solo con clave
# (Coolify lo necesita). Para deshacerlo, borra este archivo y recarga SSH.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes"

  if [ "$ARCHIVO_CAMBIADO" -eq 0 ]; then
    return 0
  fi

  if [ "$SIMULAR" -eq 1 ]; then
    printf '  %s[simulación]%s sshd -t   (comprobar que la configuración es válida)\n' "$C_GRIS" "$C_FIN"
    printf '  %s[simulación]%s systemctl reload ssh\n' "$C_GRIS" "$C_FIN"
    nota "Para aplicarlo de verdad: sudo scripts/harden.sh --apply-ssh"
    return 0
  fi

  # Ubuntu 24.04 crea esta carpeta al arrancar SSH; sshd -t la necesita.
  mkdir -p "$(ruta /run/sshd)"
  if ! sshd -t; then
    error "La nueva configuración de SSH no es válida. La deshago."
    if [ -n "$anterior" ]; then
      printf '%s\n' "$anterior" >"$(ruta "$ARCHIVO_SSH")"
    else
      rm -f "$(ruta "$ARCHIVO_SSH")"
    fi
    exit 1
  fi
  hecho "La configuración de SSH es válida."

  if servicio_activo ssh; then
    ejecutar systemctl reload ssh
  else
    nota "SSH arranca bajo demanda: la próxima conexión ya usará la configuración nueva."
  fi

  local efectiva
  efectiva="$(sshd -T 2>/dev/null || true)"
  efectiva="$(awk '$1 == "passwordauthentication" { print $2; exit }' <<<"$efectiva")"
  if [ "$efectiva" = "no" ]; then
    hecho "Comprobado: SSH ya no acepta contraseñas."
  else
    avisar "Otro archivo de configuración sigue permitiendo contraseñas. Revisa /etc/ssh/sshd_config.d/."
  fi

  cat <<EOF

  ${C_AMARILLO}IMPORTANTE: no cierres esta sesión todavía.${C_FIN}
  1. Abre OTRA terminal y entra al servidor como siempre.
  2. Si entra, ya está: puedes cerrar esta.
  3. Si NO entra, deshazlo desde ESTA sesión:
       sudo rm $ARCHIVO_SSH && sudo systemctl reload ssh
EOF
}

# ---------------------------------------------------------------- principal

resumen() {
  titulo "Resumen"
  if [ "$CAMBIOS_REALES" -eq 0 ] && [ "$CAMBIOS_SIMULADOS" -eq 0 ]; then
    hecho "Todo estaba ya hecho. No hay nada que cambiar."
  fi
  if [ "$CAMBIOS_REALES" -gt 0 ]; then
    hecho "Cambios aplicados: $CAMBIOS_REALES."
  fi
  if [ "$CAMBIOS_SIMULADOS" -gt 0 ]; then
    nota "Lo marcado como [simulación] NO se ha cambiado."
    if [ "$APLICAR_BASE" -eq 0 ]; then
      nota "Para aplicar swap, fail2ban y actualizaciones: sudo scripts/harden.sh --apply"
    fi
    if [ "$APLICAR_SSH" -eq 0 ]; then
      nota "Para aplicar SSH (lee antes la guía 02):        sudo scripts/harden.sh --apply-ssh"
    fi
  fi
  if [ -f "$(ruta /var/run/reboot-required)" ]; then
    avisar "El servidor necesita reiniciarse por unas actualizaciones. Este script no reinicia: hazlo tú cuando te venga bien."
  fi
  nota "Comprueba el resultado con: sudo scripts/check.sh"
}

main() {
  local argumentos="$*"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) SIMULAR_PEDIDO=1 ;;
      --apply) APLICAR_BASE=1 ;;
      --apply-ssh) APLICAR_SSH=1 ;;
      --swap-size)
        [ $# -ge 2 ] || morir "Falta el tamaño después de --swap-size." 3
        TAMANO_SWAP="$2"
        shift
        ;;
      --swap-size=*) TAMANO_SWAP="${1#*=}" ;;
      -h | --help) uso; exit 0 ;;
      *) error "Opción desconocida: $1"; uso >&2; exit 3 ;;
    esac
    shift
  done

  if [ "$SIMULAR_PEDIDO" -eq 1 ] && { [ "$APLICAR_BASE" -eq 1 ] || [ "$APLICAR_SSH" -eq 1 ]; }; then
    morir "--dry-run no se puede combinar con --apply ni --apply-ssh. Elige uno." 3
  fi

  local mib
  mib="$(tamano_a_mib "$TAMANO_SWAP")" || morir "Tamaño de swap no válido: $TAMANO_SWAP. Usa por ejemplo 1G, 2G o 512M." 3
  if [ "$mib" -lt 256 ] || [ "$mib" -gt 16384 ]; then
    morir "La swap debe estar entre 256M y 16G." 3
  fi

  if { [ "$APLICAR_BASE" -eq 1 ] || [ "$APLICAR_SSH" -eq 1 ]; } && ! es_root; then
    morir "Para aplicar cambios hace falta sudo: sudo scripts/harden.sh $argumentos" 1
  fi

  if [ "$APLICAR_BASE" -eq 0 ] && [ "$APLICAR_SSH" -eq 0 ]; then
    printf '%sModo SIMULACIÓN:%s se enseña lo que se haría. No se cambia nada.\n' "$C_NEGRITA" "$C_FIN"
  fi

  titulo "Comprobaciones previas"
  comprobar_sistema

  paso_swap
  paso_fail2ban
  paso_actualizaciones
  paso_ssh
  resumen
}

main "$@"

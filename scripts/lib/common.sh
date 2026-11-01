# shellcheck shell=bash
# Funciones comunes de vps-starter-es.
# Este archivo se carga con `source` desde check.sh y harden.sh; no se ejecuta solo.

# Raíz del sistema de archivos. Vacía en un servidor real.
# Las pruebas la apuntan a una carpeta falsa para no tocar el sistema.
VPS_ROOT="${VPS_ROOT:-}"

# Devuelve la ruta real de un archivo del sistema (respeta VPS_ROOT).
ruta() {
  printf '%s%s' "$VPS_ROOT" "$1"
}

hay_comando() {
  command -v "$1" >/dev/null 2>&1
}

es_root() {
  [ "$(id -u)" = "0" ]
}

# Nota: con `set -o pipefail`, "comando | grep -q" o "comando | awk '{...; exit}'"
# pueden fallar al azar (el primer comando recibe SIGPIPE). Por eso aquí se
# comparan textos o se usa "<<<" en vez de tuberías que se cortan antes de tiempo.

paquete_instalado() {
  [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
}

# Colores solo si la salida es una terminal y NO_COLOR no está definido.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_VERDE=$'\033[32m'
  C_AMARILLO=$'\033[33m'
  C_ROJO=$'\033[31m'
  C_GRIS=$'\033[2m'
  C_NEGRITA=$'\033[1m'
  C_FIN=$'\033[0m'
else
  C_VERDE=''
  C_AMARILLO=''
  C_ROJO=''
  C_GRIS=''
  C_NEGRITA=''
  C_FIN=''
fi
export C_VERDE C_AMARILLO C_ROJO C_GRIS C_NEGRITA C_FIN

error() {
  printf '%sError:%s %s\n' "$C_ROJO" "$C_FIN" "$1" >&2
}

# morir "mensaje" [código]
morir() {
  error "$1"
  exit "${2:-1}"
}

# Imprime "id versión" del sistema operativo, por ejemplo "ubuntu 24.04".
leer_os() {
  local archivo
  archivo="$(ruta /etc/os-release)"
  [ -r "$archivo" ] || return 1
  (
    # shellcheck source=/dev/null
    . "$archivo"
    printf '%s %s\n' "${ID:-desconocido}" "${VERSION_ID:-}"
  )
}

# Escapa un texto para meterlo entre comillas en JSON.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Convierte un tamaño como 512M o 2G a mebibytes. Falla si el formato no vale.
tamano_a_mib() {
  local valor="$1" numero unidad
  if [[ ! "$valor" =~ ^([0-9]+)([MmGg])$ ]]; then
    return 1
  fi
  numero="${BASH_REMATCH[1]}"
  unidad="${BASH_REMATCH[2]}"
  case "$unidad" in
    G | g) printf '%s' "$((numero * 1024))" ;;
    *) printf '%s' "$numero" ;;
  esac
}

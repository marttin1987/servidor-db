#!/usr/bin/env bash
# Motor de respaldos rotatorios para servidor-db.
# Comprime el directorio de preparacion, valida el archivo,
# genera SHA-256 y elimina respaldos propios con mas de N dias.

set -Eeuo pipefail
export LC_ALL=C
umask 077

CONFIG_FILE="${1:-/etc/respaldos/db.conf}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: no existe la configuracion: $CONFIG_FILE" >&2
    exit 2
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${DIR_ORIGEN:?Falta DIR_ORIGEN}"
: "${DIR_DESTINO:?Falta DIR_DESTINO}"
: "${LOG_FILE:?Falta LOG_FILE}"
: "${DIAS_RETENCION:?Falta DIAS_RETENCION}"
: "${UMBRAL_DISCO_MAX:?Falta UMBRAL_DISCO_MAX}"

if [[ ! "$DIAS_RETENCION" =~ ^[0-9]+$ ]] ||
   [[ ! "$UMBRAL_DISCO_MAX" =~ ^[0-9]+$ ]] ||
   (( UMBRAL_DISCO_MAX > 100 )); then
    echo "ERROR: retencion o umbral de disco no validos." >&2
    exit 2
fi

if [[ ! -d "$DIR_ORIGEN" ]]; then
    echo "ERROR: no existe el origen: $DIR_ORIGEN" >&2
    exit 2
fi

mkdir -p "$DIR_DESTINO" "$(dirname "$LOG_FILE")"

exec 9>>"$LOG_FILE"
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&9; }
error() { log "ERROR: $*"; printf 'ERROR: %s\n' "$*" >&2; }

uso=$(df --output=pcent "$DIR_DESTINO" | tail -n 1 | tr -dc '0-9')
if [[ ! "$uso" =~ ^[0-9]+$ ]] || (( uso > UMBRAL_DISCO_MAX )); then
    error "uso de disco no valido o superior al umbral: ${uso:-desconocido}%."
    exit 2
fi

fecha=$(date '+%Y-%m-%d_%H-%M-%S')
nombre="respaldo_mariadb_${fecha}.tar.gz"
temporal="$DIR_DESTINO/.${nombre}.tmp"
final="$DIR_DESTINO/$nombre"
suma_tmp="$DIR_DESTINO/.${nombre}.sha256.tmp"
suma_final="${final}.sha256"

limpiar() {
    rm -f -- "$temporal" "$suma_tmp"
}
trap limpiar EXIT

log "Inicio de respaldo MariaDB."
if ! tar -czf "$temporal" -C "$(dirname "$DIR_ORIGEN")" \
    "$(basename "$DIR_ORIGEN")"; then
    error "fallo la compresion."
    exit 2
fi

if ! tar -tzf "$temporal" >/dev/null; then
    error "el archivo comprimido no supera la validacion."
    exit 2
fi

mv -- "$temporal" "$final"

if ! (cd "$DIR_DESTINO" && sha256sum "$nombre" > "$(basename "$suma_tmp")"); then
    rm -f -- "$final"
    error "no se pudo generar el SHA-256."
    exit 2
fi
mv -- "$suma_tmp" "$suma_final"

if ! (cd "$DIR_DESTINO" && sha256sum -c "$(basename "$suma_final")" >/dev/null); then
    rm -f -- "$final" "$suma_final"
    error "fallo la verificacion SHA-256."
    exit 2
fi

log "Respaldo validado: $nombre"

# Eliminar solo archivos propios de servidor-db y sus firmas.
while IFS= read -r -d '' archivo; do
    rm -f -- "$archivo" "${archivo}.sha256"
    log "Respaldo antiguo eliminado: $(basename "$archivo")"
done < <(
    find "$DIR_DESTINO" -maxdepth 1 -type f \
        -name 'respaldo_mariadb_*.tar.gz' \
        -mmin "+$((DIAS_RETENCION * 1440))" -print0
)

log "Respaldo finalizado correctamente."
printf 'OK: %s\n' "$final"
printf 'OK: %s\n' "$suma_final"

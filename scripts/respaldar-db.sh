#!/usr/bin/env bash
# Respalda bases de MariaDB: vuelca cada base a una carpeta de preparacion
# y llama al motor de respaldo rotatorio, que comprime, firma con SHA-256
# y rota las copias viejas.
#
# Entra a la base por el socket como root, sin guardar contrasenas.
#
# Codigos de salida: 0 = OK, 2 = error (o el codigo del motor)
# Uso: sudo ./scripts/respaldar-db.sh
#
# Variables opcionales: BASES, MOTOR, CONFIG

set -u
set -o pipefail
export LC_ALL=C
umask 077

BASES="${BASES:-inventario}"
MOTOR="${MOTOR:-/usr/local/sbin/respaldo-rotatorio.sh}"
CONFIG="${CONFIG:-/etc/respaldos/db.conf}"
DUMP_BIN="${DUMP_BIN:-mariadb-dump}"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecutar con sudo." >&2
    exit 2
fi

if [ ! -x "$MOTOR" ] || [ ! -f "$CONFIG" ]; then
    echo "ERROR: falta '$MOTOR' o '$CONFIG'." >&2
    exit 2
fi

# La carpeta de preparacion es el origen que define la configuracion
# shellcheck source=/dev/null
. "$CONFIG"
PREPARACION="${DIR_ORIGEN:?falta DIR_ORIGEN en la configuracion}"

exec 9>/run/lock/respaldar-db.lock
if ! flock -n 9; then
    echo "ERROR: ya hay un respaldo en curso." >&2
    exit 2
fi
trap 'find "${PREPARACION:?}" -mindepth 1 -delete' EXIT

mkdir -p "$PREPARACION"
chmod 700 "$PREPARACION"
find "${PREPARACION:?}" -mindepth 1 -delete

for base in $BASES; do
    destino="$PREPARACION/${base}.sql"
    if "$DUMP_BIN" --single-transaction --routines --triggers --events "$base" > "$destino" \
        && tail -n 1 "$destino" | grep -q '^-- Dump completed'; then
        echo "OK: volcado de '$base'."
    else
        echo "ERROR: fallo el volcado de '$base'." >&2
        find "${PREPARACION:?}" -mindepth 1 -delete
        exit 2
    fi
done

# Usuarios y permisos (incluye los hashes de las contrasenas)
usuarios="$PREPARACION/usuarios.sql"
if "$DUMP_BIN" --system=users > "$usuarios" \
    && tail -n 1 "$usuarios" | grep -q '^-- Dump completed'; then
    echo "OK: volcado de usuarios y permisos."
else
    echo "ERROR: fallo el volcado de usuarios y permisos." >&2
    exit 2
fi

"$MOTOR" "$CONFIG"
codigo=$?

# Los volcados sin comprimir no deben quedar en disco
find "${PREPARACION:?}" -mindepth 1 -delete
exit "$codigo"

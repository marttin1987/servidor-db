#!/usr/bin/env bash

# Respalda bases de MariaDB con mariadb-dump: volcado comprimido, escritura
# atomica, firma SHA-256 y rotacion por antiguedad.
#
# Entra a la base por el socket como root, sin guardar contrasenas.
#
# Codigos de salida: 0 = OK, 2 = error
# Uso: sudo ./scripts/respaldar-db.sh
#
# Variables opcionales: BASES, DESTINO, RETENCION_DIAS

set -u
set -o pipefail
export LC_ALL=C
umask 077

BASES="${BASES:-inventario}"
DESTINO="${DESTINO:-/var/backups/db}"
RETENCION_DIAS="${RETENCION_DIAS:-7}"
DUMP_BIN="${DUMP_BIN:-mariadb-dump}"

if [ "$(id -u)" -ne 0 ]; then
	echo "ERROR: ejecutar con sudo." >&2
	exit 2
fi

mkdir -p "$DESTINO"
chmod 700 "$DESTINO"

FECHA=$(date '+%Y-%m-%d_%H-%M-%S')
ERRORES=0

for base in $BASES; do
	final="$DESTINO/${base}_${FECHA}.sql.gz"
	temporal="$final.tmp"
	if "$DUMP_BIN" --single-transaction --routines --triggers --events "$base" | gzip > "$temporal" && gzip -t < "$temporal"; then
		mv "$temporal" "$final"
		(cd "$DESTINO" && sha256sum "$(basename "$final")" > "$(basename "$final").sha256")
		echo "OK: $final"
	else
		rm -f "$temporal"
		echo "ERROR: fallo el respaldo de '$base'." >&2
		ERRORES=$((ERRORES + 1))
	fi
done

find "$DESTINO" -maxdepth 1 -type f \( -name '*.sql.gz' -o -name '*.sql.gz.sha256' \) -mtime +"$RETENCION_DIAS" -delete

if [ "$ERRORES" -gt 0 ]; then
	exit 2
fi

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
		if "$DUMP_BIN" --single-transaction --routines --triggers --events "$base" | gzip > "$temporal" \
			&& gzip -t < "$temporal"; then
		if mv "$temporal" "$final"; then
		checksum="$final.sha256"
		checksum_temporal="$checksum.tmp"

		if (cd "$DESTINO" && sha256sum "$(basename "$final")" > "$(basename "$checksum_temporal")") \
			&& mv "$checksum_temporal" "$checksum"; then
			echo "OK: $final"
		else
			rm -f "$final" "$checksum_temporal" "$checksum"
			echo "ERROR: no se pudo generar el SHA-256 de '$base'." >&2
			ERRORES=$((ERRORES + 1))
		fi

		else
			rm -f "$temporal"
			echo "ERROR: no se pudo publicar el respaldo de '$base'." >&2
			ERRORES=$((ERRORES + 1))
		fi
	else
		rm -f "$temporal"
		echo "ERROR: fallo el respaldo de '$base'." >&2
		ERRORES=$((ERRORES + 1))
	fi
done


if [ "$ERRORES" -gt 0 ]; then
    echo "ERROR: $ERRORES base(s) fallaron; no se rota para conservar las copias anteriores." >&2
	exit 2
fi

find "$DESTINO" -maxdepth 1 -type f \( -name '*.sql.gz' -o -name '*.sql.gz.sha256' \) -mtime +"$RETENCION_DIAS" -delete

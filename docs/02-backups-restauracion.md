# 02 - Backups de MariaDB y restauración

## Objetivo

Tener copias automáticas de la base de datos y comprobar que se pueden restaurar. Incluye el *runbook*: la guía paso a paso para recuperar la base en caso de desastre.

## Diseño

El script `scripts/respaldar-db.sh` hace una copia de cada base indicada en `BASES` (por defecto `inventario`):

- Genera un volcado con `mariadb-dump --single-transaction --routines --triggers --events`. La opción `--single-transaction` toma una copia consistente sin bloquear la base.
- Lo comprime y lo escribe en un archivo temporal. Solo si el volcado y la compresión terminaron bien lo renombra a su nombre final, así nunca queda una copia a medias.
- Crea una firma SHA-256 junto al archivo.
- Borra las copias de más de 7 días.
- Entra a la base como `root` por el socket del sistema: no guarda ninguna contraseña.
- Deja los archivos con permisos `600` en una carpeta `700` (`/var/backups/db`).

Códigos de salida: `0` correcto, `2` error (falta de `sudo` o fallo de algún volcado).

## Instalación

El script se instala en una ruta que solo puede modificar root, porque `cron` lo ejecuta con privilegios:

```bash
sudo install -m 750 -o root -g root ~/respaldar-db.sh /usr/local/sbin/respaldar-db.sh
```

## Pruebas del script

Antes de usar la base real se probó con un `mariadb-dump` simulado, incluido un caso de falla:

| Caso | Resultado |
| --- | --- |
| Volcado correcto | Archivo y firma creados, la firma verifica, `rc=0` |
| Volcado que falla | No queda ningún archivo, `rc=2` |
| Copia de 10 días de antigüedad | La rotación la borra |
| Permisos | Carpeta `700`, archivos `600` |

Con la base real: `sudo /usr/local/sbin/respaldar-db.sh` devolvió `rc=0` y creó el `.sql.gz` y su `.sha256`.

## Prueba de restauración

Se restauró la copia en una base **nueva**, sin tocar la original, y se compararon las tablas:

```bash
sudo bash -c 'cd /var/backups/db && sha256sum -c *.sha256'
sudo mariadb -e "CREATE DATABASE inventario_restaurada CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo bash -c 'zcat "$(ls -t /var/backups/db/*.sql.gz | head -1)" | mariadb inventario_restaurada'
sudo mariadb -e "CHECKSUM TABLE inventario.productos, inventario_restaurada.productos;"
```

La firma dio `OK` y las dos tablas devolvieron el mismo `Checksum` (`2544526812`): son idénticas.

## Simulación de desastre

Se borró la base con `DROP DATABASE inventario;`, se la recreó vacía y se restauró desde la copia. La tabla `productos` volvió con sus tres filas, y el usuario `app_inventario` pudo leerlas de nuevo.

## Runbook: recuperar la base `inventario`

Reemplazar `FECHA` por la de la copia que se quiere usar (`sudo ls /var/backups/db`).

```bash
# 1. Verificar que la copia no esté dañada
sudo bash -c 'cd /var/backups/db && sha256sum -c inventario_FECHA.sql.gz.sha256'

# 2. Crear la base vacía (si existe y está dañada, borrarla antes con DROP DATABASE)
sudo mariadb -e "CREATE DATABASE inventario CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 3. Restaurar los datos
sudo bash -c 'zcat /var/backups/db/inventario_FECHA.sql.gz | mariadb inventario'

# 4. Comprobar
sudo mariadb inventario -e "SELECT COUNT(*) FROM productos;"
```

Si se perdió todo el servidor y no solo la base, hay que volver a crear antes a `app_inventario` y sus permisos (doc 01), porque la copia **no incluye usuarios**.

## Automatización

El archivo `/etc/cron.d/db-backup` ejecuta el backup todos los días a las 03:00, después de la exportación de configuraciones del servidor:

```cron
0 3 * * * root /usr/local/sbin/respaldar-db.sh >> /var/log/db-backup.log 2>&1
```

Antes de dejar el horario definitivo se programó una prueba para dos minutos más tarde. El log mostró la línea `OK: ...` y apareció un segundo par de archivos. La prueba se borró y se creó el archivo definitivo con permisos `644`.

Error cometido: el primer intento de crear el archivo de `cron` se ejecutó en el anfitrión y no en la VM. Se detectó al revisar el prompt y se quitó. En la VM, además, quedaba activa la prueba de cada día, que hubo que borrar.

## Limitaciones

- Las copias están en el mismo disco que el servidor: no protegen de perder el disco.
- La copia no incluye usuarios ni permisos, ni el archivo `/root/app_inventario.pass`.
- `cron` solo corre con la VM encendida a las 03:00.
- Se respalda una sola base; para más se usa la variable `BASES`.

## Próximos pasos

- Guardar también los usuarios y permisos.
- Copiar las copias fuera del servidor y verificarlas allá, como en el proyecto `servidor-seguro`.
- Agregar el estado de este backup al reporte con semáforo.

## Aprendizajes

- Una copia solo vale cuando se probó restaurarla: el desastre simulado es la prueba real.
- Escribir en un archivo temporal y renombrar evita copias a medias.
- Entrar por el socket como `root` evita guardar contraseñas en el script.
- Cada comando de `cron` se prueba en pequeño antes de dejar el horario definitivo, y hay que leer el prompt para saber en qué máquina se está.

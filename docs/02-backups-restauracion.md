# Backups y restauración de MariaDB

## Objetivo

Respaldar bases de datos MariaDB y usuarios/permisos, integrar los volcados
con el motor de respaldo rotatorio y documentar una restauración de prueba
sin modificar la base de datos original.

## Diseño

El proceso se divide en dos componentes:

1. `scripts/respaldar-db.sh`: genera los volcados SQL en una carpeta temporal
   de preparación y comprueba que cada volcado haya finalizado correctamente.
2. `/usr/local/sbin/respaldo-rotatorio-db.sh`: recibe la configuración y se
   encarga de comprimir los archivos, generar la firma SHA-256 y aplicar
   la política de rotación.

El script principal:

- Usa `mariadb-dump --single-transaction --routines --triggers --events`
  para cada base indicada en `BASES` (por defecto, `inventario`).
- Genera también un volcado de usuarios y permisos mediante
  `mariadb-dump --system=users`.
- Comprueba la marca final de los volcados.
- Usa `flock` para impedir ejecuciones simultáneas.
- Aplica permisos restrictivos mediante `umask 077` y permisos `700`
  en la carpeta de preparación.
- Limpia los volcados SQL sin comprimir al terminar, incluso ante errores,
  mediante un `trap`.
- Delega la compresión, la firma y la retención al motor rotatorio.

Los respaldos finales son archivos `.tar.gz` acompañados por archivos
`.sha256`, según el comportamiento del motor rotatorio.

## Configuración

El archivo de configuración utilizado en producción es:

`/etc/respaldos/db.conf`

El repositorio incluye una plantilla en `config/db.conf.ejemplo`:

```bash
DIR_ORIGEN="/var/backups/mariadb/origen"
DIR_DESTINO="/var/backups/mariadb/copias"
LOG_FILE="/var/log/respaldo-mariadb.log"
DIAS_RETENCION=7
UMBRAL_DISCO_MAX=90
```

La configuración contiene:

- `DIR_ORIGEN`: carpeta temporal con los volcados SQL.
- `DIR_DESTINO`: destino de las copias rotatorias.
- `LOG_FILE`: archivo de registro del motor.
- `DIAS_RETENCION`: antigüedad de retención configurada.
- `UMBRAL_DISCO_MAX`: umbral de ocupación de disco configurado.

El archivo real debe ser propiedad de `root` y tener permisos restrictivos.
No guardar credenciales ni secretos en el repositorio.

## Ejecución manual

El script requiere privilegios de administrador y que existan tanto
el motor rotatorio como la configuración:

```bash
sudo /usr/local/sbin/respaldar-db.sh
```

Se pueden cambiar las bases mediante la variable `BASES`:

```bash
sudo env BASES="inventario otra_base" \
  /usr/local/sbin/respaldar-db.sh
```

El código de salida `0` indica éxito; `2` indica un error del proceso
principal. También puede propagarse el código de salida del motor rotatorio.

## Verificación de los respaldos

Después de una ejecución correcta, comprobar que existan el archivo
comprimido y su firma en el destino configurado:

```bash
sudo ls -lh /var/backups/mariadb/copias
```

Verificar la firma SHA-256 usando el archivo de firma correspondiente.
Ejecutar el comando desde el directorio donde estén ambos archivos:

```bash
sudo sha256sum -c ARCHIVO.tar.gz.sha256
```

Sustituir el nombre de ejemplo por el nombre real generado por el motor.
El resultado esperado es `OK`.

Inspeccionar el contenido del archivo sin extraerlo:

```bash
sudo tar -tzf ARCHIVO.tar.gz
```

El archivo debe contener los volcados SQL esperados, incluida la copia
de usuarios y permisos. Confirmar los nombres exactos con la salida
del comando, ya que dependen de la estructura del motor rotatorio.

## Restauración de prueba no destructiva

Realizar la prueba en un entorno de laboratorio y utilizar un nombre
de base de datos exclusivo para la restauración. No ejecutar `DROP DATABASE`
ni sobrescribir la base original como parte de una prueba rutinaria.

1. Seleccionar una copia y verificar su SHA-256.
2. Inspeccionar el contenido con `tar -tzf`.
3. Extraer el volcado de la base a un directorio temporal protegido.
4. Crear una base de prueba vacía, por ejemplo `inventario_restore_test`.
5. Restaurar únicamente el volcado de esa base en la base de prueba.
6. Comparar tablas, estructura y cantidad de registros con los datos
   esperados.
7. Registrar los comandos, resultados y fecha en la evidencia del proyecto.
8. Eliminar la base de prueba y los archivos temporales una vez verificado
   el resultado.

Ejemplo de extracción a un directorio temporal:

```bash
umask 077
mkdir -p /tmp/restauracion-db
sudo tar -xzf ARCHIVO.tar.gz -C /tmp/restauracion-db
sudo find /tmp/restauracion-db -maxdepth 3 -type f -print
```

Antes de restaurar, identificar la ruta exacta del volcado de la base.
No importar `usuarios.sql` en una instancia compartida durante una prueba:
ese archivo puede contener información sensible y modificar cuentas
y permisos. Probar la recuperación de usuarios en una instancia aislada.

## systemd

El proyecto incluye:

- `systemd/respaldar-db.service`
- `systemd/respaldar-db.timer`

Consultar el estado y las últimas ejecuciones:

```bash
systemctl status respaldar-db.timer
systemctl list-timers respaldar-db.timer
sudo journalctl -u respaldar-db.service -n 50 --no-pager
```

La prueba operativa debe confirmar que el servicio finaliza correctamente,
que los respaldos se generan y que la verificación de SHA-256 es satisfactoria.

## Seguridad y limitaciones

- Los volcados SQL y el respaldo de usuarios pueden contener información
  confidencial.
- Mantener permisos restrictivos sobre configuración, preparación y copias.
- Una firma SHA-256 permite detectar cambios en los archivos, pero por sí sola
  no demuestra que la restauración funcione.
- Una copia local no sustituye una copia externa ni una política de recuperación
  ante pérdida del servidor.
- La restauración debe probarse periódicamente en un entorno aislado.

## Evidencias de validación

Registrar en el repositorio los resultados comprobados de:

- Volcado de bases y usuarios/permisos.
- Integración con el motor rotatorio.
- Verificación SHA-256.
- Prueba de fallo y limpieza de temporales.
- Prevención de ejecuciones simultáneas.
- Ejecución programada con systemd.
- Restauración de prueba sin alterar la base original.

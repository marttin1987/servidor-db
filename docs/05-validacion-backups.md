# 05 — Validación del sistema de respaldos MariaDB

**Fecha de validación:** 2026-10-26
**Entorno:** Debian 13, MariaDB 11.8.6, laboratorio VirtualBox.

## 1. Ejecución del respaldo

Se ejecutó manualmente el servicio `respaldar-db.service`.

Resultado: `status=0/SUCCESS`.

Se generaron correctamente los volcados de:
- Base de datos `inventario`.
- Usuarios y permisos de MariaDB.

El motor independiente generó el archivo:

`/var/backups/mariadb/copias/respaldo_mariadb_2026-10-26_18-02-35.tar.gz`

También generó el archivo de verificación SHA-256 asociado.

## 2. Integridad del archivo

Se ejecutó la verificación SHA-256 del archivo generado.

**Resultado:** la suma coincide.

El contenido del archivo comprimido incluyó:
- `origen/inventario.sql`
- `origen/usuarios.sql`

## 3. Prueba de restauración

Se extrajo el respaldo en un directorio temporal y se inspeccionó el SQL.

Se creó una base aislada llamada `inventario_restore_test` y se restauró en ella el volcado de `inventario.sql`.

Consulta de validación:

`SELECT COUNT(*) FROM inventario_restore_test.productos;`

**Resultado:** 3 productos restaurados.

La prueba no importó el volcado de usuarios ni modificó la base original `inventario`.

## 4. Automatización y rotación de logs

Se verificó que los temporizadores `respaldar-db.timer` y `logrotate.timer` estuvieran activos.

La configuración de logrotate establece:
- Rotación diaria.
- Conservación de 14 archivos rotados.
- Compresión de logs.
- Creación del log con propietario `root` y permisos `0600`.

## 5. Resultado y limitaciones

**Validado:**
- Ejecución manual del servicio.
- Generación del archivo comprimido.
- Verificación de integridad SHA-256.
- Restauración de la tabla y sus datos en una base aislada.
- Estado activo de los temporizadores.

**Pendiente de validar:**
- Reconstrucción completa en una VM limpia.
- Restauración de usuarios y permisos en un entorno aislado.
- Comportamiento de la retención ante respaldos que superen los siete días.

Esta validación corresponde al laboratorio y no sustituye una prueba de recuperación ante un desastre real.

## 6. Prueba de retención

Se realizó una prueba aislada en un directorio temporal de Debian, con archivos ficticios de respaldo.

- Archivo antiguo: antigüedad de 8 días.
- Archivo reciente: antigüedad de 1 hora.
- Umbral configurado: 7 días (10.080 minutos).

Resultado:
- Se seleccionó únicamente el respaldo antiguo.
- Se eliminó el archivo antiguo junto con su firma `.sha256`.
- Se conservaron el respaldo reciente y su firma.

La prueba reprodujo la regla de selección y eliminación del motor, sin ejecutar la retención sobre los respaldos reales.

**Resultado:** prueba de retención aprobada en entorno aislado.


## 7. Validación de usuarios y permisos

Se inspeccionó el archivo `origen/usuarios.sql` incluido en el respaldo MariaDB del 27/10/2026.

Comprobaciones realizadas:

- El archivo contiene instrucciones para crear usuarios y asignar permisos.
- Se identificó el usuario `app_inventario`@`localhost`.
- Se verificaron los permisos actuales de esa cuenta mediante `SHOW GRANTS`.
- Los permisos observados coinciden con los incluidos en el respaldo: `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `inventario`.*.

**Resultado:** contenido del respaldo y permisos actuales inspeccionados correctamente.

**Pendiente:** restaurar usuarios y permisos en una instancia aislada de MariaDB y verificar el resultado. El archivo no se importó en el servidor principal porque contiene instrucciones que pueden modificar cuentas administrativas.

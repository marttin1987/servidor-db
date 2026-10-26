# Runbook: reconstrucción desde una Debian limpia

## 1. Objetivo

Reconstruir el servicio de backups de MariaDB desde una instalación
limpia de Debian, utilizando el repositorio y los artefactos necesarios.

La reconstrucción debe ser reproducible y verificable.

## 2. Precauciones

- No reconstruir sobre la VM de producción del laboratorio.
- No borrar backups existentes ni datos de MariaDB.
- No guardar contraseñas, claves ni secretos en Git.
- No considerar recuperado el servicio hasta completar una restauración.
- El motor externo de rotación y su configuración deben estar
  disponibles antes de ejecutar el coordinador de backups.

## 3. Inventario de componentes

- Sistema operativo: Debian 13.
- Base de datos: MariaDB.
- Coordinador: scripts/respaldar-db.sh.
- Motor de rotación: /usr/local/sbin/respaldo-rotatorio-db.sh.
- Configuración de ejemplo: config/db.conf.ejemplo.
- Servicio systemd: systemd/respaldar-db.service.
- Temporizador systemd: systemd/respaldar-db.timer.
- Regla Logrotate: config/logrotate-respaldo-mariadb.
- Sincronización horaria: Chrony.

## 4. Procedimiento de reconstrucción

1. Preparar una VM Debian aislada.
2. Actualizar los paquetes e instalar las dependencias.
3. Instalar MariaDB y comprobar que el servicio esté activo.
4. Crear la base de datos de prueba y el usuario de mínimo privilegio.
5. Instalar el coordinador y configurar permisos de ejecución.
6. Recuperar e instalar el motor de rotación y su configuración.
7. Crear los directorios requeridos y asignar permisos mínimos.
8. Instalar la configuración de Logrotate.
9. Instalar y habilitar el servicio y temporizador systemd.
10. Ejecutar un backup manual y comprobar su resultado.
11. Verificar integridad mediante SHA-256.
12. Restaurar en una base de datos aislada y validar los datos.
13. Comprobar el temporizador, los registros y la rotación.
14. Registrar evidencias y documentar cualquier diferencia.

## 5. Criterios de aceptación

- MariaDB inicia correctamente.
- El coordinador termina sin errores.
- Se genera el archivo de backup esperado.
- La verificación SHA-256 es satisfactoria.
- La restauración recupera la estructura y los datos esperados.
- El servicio y el temporizador systemd funcionan.
- Logrotate acepta la configuración.
- No se exponen secretos ni se alteran los datos originales.

## 6. Estado de la prueba

Pendiente: ejecutar el procedimiento en una VM limpia aislada.

Este documento define el procedimiento previsto; no implica que
la reconstrucción completa ya haya sido probada.

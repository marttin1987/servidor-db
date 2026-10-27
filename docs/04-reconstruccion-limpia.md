# Runbook: reconstrucción desde una Debian limpia

## 1. Objetivo

Reconstruir el servicio de backups de MariaDB en una VM Debian 13
aislada, utilizando el repositorio y sus artefactos versionados.

Este procedimiento debe poder ejecutarse sin modificar la VM actual
ni sobrescribir bases de datos o respaldos existentes.

## 2. Precauciones

- Utilizar una VM aislada y confirmar su identidad antes de comenzar.
- No borrar backups existentes ni datos de MariaDB.
- No guardar contraseñas, claves ni secretos en Git.
- Proteger los volcados, especialmente el de usuarios y permisos.
- No importar `usuarios.sql` en el servidor principal: puede modificar
  cuentas administrativas y privilegios.
- No considerar recuperado el servicio hasta probar una restauración.
- No sobrescribir una configuración real con la plantilla del repositorio.
- Registrar los resultados reales; no marcar como probada una etapa
  que solo se haya documentado.

## 3. Componentes

- Sistema operativo: Debian 13.
- Base de datos: MariaDB.
- Coordinador: `scripts/respaldar-db.sh`.
- Motor de rotación: `scripts/respaldo-rotatorio-db.sh`.
- Configuración de ejemplo: `config/db.conf.ejemplo`.
- Servicio: `systemd/respaldar-db.service`.
- Temporizador: `systemd/respaldar-db.timer`.
- Logrotate: `config/logrotate-respaldo-mariadb`.
- Sincronización horaria: Chrony.

## 4. Preparación de la VM

1. Crear o iniciar una VM Debian 13 aislada.
2. Confirmar que se está trabajando en esa VM y no en el servidor
   habitual del laboratorio.
3. Actualizar los índices e instalar las dependencias:

   ```bash
   sudo apt update
   sudo apt install -y mariadb-server logrotate chrony
   ```

4. Instalar las herramientas necesarias para inspeccionar y verificar
   los respaldos:

   ```bash
   sudo apt install -y git gzip tar coreutils
   ```

5. Instalar y comprobar MariaDB:

   ```bash
   sudo systemctl enable --now mariadb
   systemctl is-active mariadb
   mariadb --version
   ```

6. Seguir el procedimiento de instalación y preparación de la base de
   práctica descrito en `docs/01-mariadb-instalacion-usuarios.md`.
   No reutilizar usuarios ni contraseñas de otros entornos.

## 5. Instalación del servicio de respaldo

1. Situarse en la raíz del repositorio y verificar los artefactos:

   ```bash
   git status --short
   git ls-files scripts systemd config
   ```

2. Instalar ambos scripts con permisos restrictivos:

   ```bash
   sudo install -o root -g root -m 750 \
     scripts/respaldo-rotatorio-db.sh \
     /usr/local/sbin/respaldo-rotatorio-db.sh

   sudo install -o root -g root -m 750 \
     scripts/respaldar-db.sh \
     /usr/local/sbin/respaldar-db.sh
   ```

3. Crear el directorio de configuración e instalar la plantilla
   solamente si todavía no existe una configuración real:

   ```bash
   sudo install -d -o root -g root -m 750 /etc/respaldos

   sudo test -f /etc/respaldos/db.conf ||
     sudo install -o root -g root -m 600 \
       config/db.conf.ejemplo /etc/respaldos/db.conf
   ```

4. Revisar `/etc/respaldos/db.conf` y confirmar que las rutas,
   la retención y el umbral de disco sean adecuados para esta VM.
   No sobrescribir una configuración existente ni copiar secretos
   al repositorio.

5. Crear los directorios necesarios según la configuración elegida.
   Comprobar que el usuario que ejecuta el servicio pueda escribir
   donde corresponda. El servicio systemd se ejecuta como root.

6. Instalar el servicio y el temporizador:

   ```bash
   sudo install -o root -g root -m 644 \
     systemd/respaldar-db.service /etc/systemd/system/

   sudo install -o root -g root -m 644 \
     systemd/respaldar-db.timer /etc/systemd/system/

   sudo systemctl daemon-reload
   ```

7. Verificar que `DIR_DESTINO` sea un directorio exclusivo para los
   respaldos de esta práctica, con propietario y permisos restrictivos.
   No cambiar recursivamente los permisos de directorios que ya
   contienen datos. Confirmar también que `LOG_FILE` no sobrescriba
   registros de otro servicio.

8. Instalar y validar la regla de Logrotate:

   ```bash
   sudo install -o root -g root -m 644 \
     config/logrotate-respaldo-mariadb \
     /etc/logrotate.d/respaldo-mariadb

   sudo logrotate --debug /etc/logrotate.d/respaldo-mariadb
   ```

9. Habilitar Chrony y comprobar su estado:

   ```bash
   sudo systemctl enable --now chrony
   chronyc tracking
   ```

## 6. Validación del respaldo

1. Revisar los permisos y la configuración antes de ejecutar el
   servicio. No continuar si las rutas apuntan a datos ajenos a la VM.

2. Ejecutar un respaldo manual:

   ```bash
   sudo /usr/local/sbin/respaldar-db.sh
   ```

3. Revisar el código de salida y los registros. Confirmar que se
   generaron los archivos esperados en `DIR_DESTINO`, sin asumir
   nombres fijos.

4. Verificar el checksum del archivo generado:

   ```bash
   sudo sha256sum -c /ruta/al/archivo.tar.gz.sha256
   ```

5. Inspeccionar el contenido del archivo sin extraerlo sobre
   directorios existentes:

   ```bash
   sudo tar -tzf /ruta/al/archivo.tar.gz
   ```

6. Revisar el estado del temporizador y la última ejecución:

   ```bash
   systemctl is-enabled respaldar-db.timer
   systemctl list-timers respaldar-db.timer
   systemctl status respaldar-db.service --no-pager
   journalctl -u respaldar-db.service -n 50 --no-pager
   ```

7. Ejecutar una restauración de prueba siguiendo
   `docs/02-backups-restauracion.md`, usando una base de datos
   aislada y datos de prueba conocidos. Validar estructura y registros.

8. No importar volcados de usuarios o permisos en el servidor
   principal. Su restauración debe realizarse únicamente en una
   instancia aislada y siguiendo el procedimiento específico.

## 7. Criterios de aceptación

- La VM utilizada es la VM aislada prevista.
- MariaDB y Chrony están instalados y sus estados fueron comprobados.
- Ambos scripts están instalados con permisos restrictivos.
- La configuración existe y sus rutas fueron verificadas.
- El respaldo manual termina correctamente y genera los artefactos
  esperados.
- La verificación SHA-256 resulta satisfactoria.
- El contenido del archivo fue inspeccionado.
- La restauración recupera la estructura y los datos esperados.
- El temporizador y Logrotate pasan sus verificaciones.
- No se modificaron los backups originales ni se expusieron secretos.

## 8. Estado de la prueba

**Estado inicial:** pendiente de ejecutar el procedimiento completo
en una VM Debian 13 limpia y aislada.

Registrar la fecha, la versión del repositorio, los comandos ejecutados,
los resultados y las incidencias. Cambiar este estado únicamente
cuando existan evidencias de cada criterio de aceptación.

Este runbook describe el procedimiento previsto; su documentación
no demuestra por sí sola que la reconstrucción haya sido probada.

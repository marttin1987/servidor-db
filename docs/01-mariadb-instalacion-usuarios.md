# 01 - MariaDB: instalación, revisión y usuarios

## Objetivo

Instalar MariaDB en el servidor Debian, revisar su seguridad de fábrica y crear una base de práctica con un usuario de mínimo privilegio.

## Instalación

Antes de empezar se tomó la instantánea de VirtualBox `07-antes-mariadb`.

```bash
sudo apt update && sudo apt install -y mariadb-server
systemctl is-active mariadb
sudo ss -tlnp | grep 3306
```

| Comprobación | Resultado |
| --- | --- |
| Servicio | `active` |
| Puerto | `3306` escuchando solo en `127.0.0.1` |

Que escuche solo en `127.0.0.1` significa que no se puede entrar desde otra máquina, ni siquiera desde el anfitrión. Cualquier aplicación tiene que estar en el mismo servidor.

### Un error útil

La primera instalación se hizo por error en el anfitrión (`kingtero`) en vez de la VM. Se detectó a tiempo y se corrigió así:

1. Se simuló la desinstalación sin tocar nada: `apt-get -s purge mariadb-server | grep '^Purg'`.
2. La simulación mostró solo la metapaquete, no el motor (`mariadb-server-10.3`), así que se listó todo lo instalado con `dpkg -l | grep -i mariadb`.
3. Se quitaron los dos paquetes con `sudo apt purge`, y se comprobó que el servicio quedara inactivo y que no hubiera nada en el puerto `3306`.

**Aprendizaje:** leer el prompt antes de ejecutar, y simular (`-s`) antes de borrar.

## Revisión de seguridad de fábrica

```bash
sudo mariadb -e "SELECT user, host, plugin FROM mysql.user; SHOW DATABASES;"
sudo mariadb -e "SHOW CREATE USER 'root'@'localhost';"
```

| Punto | Resultado |
| --- | --- |
| Usuarios anónimos | No hay |
| Base `test` | No existe |
| Acceso de `root` | `IDENTIFIED VIA mysql_native_password USING 'invalid' OR unix_socket` |

La contraseña de `root` es `invalid`: no sirve para entrar. Solo entra quien ejecuta `sudo mariadb`, porque MariaDB confía en el usuario del sistema. No hizo falta corregir nada con `mariadb-secure-installation`.

## Base de práctica

```bash
sudo mariadb -e "CREATE DATABASE inventario CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb inventario -e "CREATE TABLE productos (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(100) NOT NULL, stock INT NOT NULL DEFAULT 0, creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP); INSERT INTO productos (nombre, stock) VALUES ('Teclado', 10), ('Mouse', 25), ('Monitor', 5);"
```

La tabla `productos` quedó con tres filas.

## Usuario de la aplicación

El usuario `app_inventario` solo puede leer y modificar filas de la base `inventario`. La contraseña la genera el sistema y se guarda en un archivo que solo lee root, para que no aparezca en pantalla, en el historial ni en un repositorio:

```bash
PASS=$(openssl rand -base64 18 | tr -d '/+=')
sudo mariadb <<SQL
CREATE USER 'app_inventario'@'localhost' IDENTIFIED BY '$PASS';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventario.* TO 'app_inventario'@'localhost';
SQL
echo "$PASS" | sudo tee /root/app_inventario.pass > /dev/null
sudo chmod 600 /root/app_inventario.pass
unset PASS
```

## Pruebas de límites

```bash
export MYSQL_PWD=$(sudo cat /root/app_inventario.pass)
mariadb -u app_inventario inventario -e "SELECT COUNT(*) AS filas FROM productos;"
mariadb -u app_inventario inventario -e "DROP TABLE productos;"
mariadb -u app_inventario -e "SHOW DATABASES;"
unset MYSQL_PWD
```

| Prueba | Resultado esperado | Resultado |
| --- | --- | --- |
| Contar filas | `3` | Correcto |
| Borrar la tabla | `ERROR 1142 ... DROP command denied` | Correcto |
| Listar bases | Solo `information_schema` e `inventario` | Correcto |

## Limitaciones

- La contraseña del usuario está en un archivo de root: cuando haya una aplicación, tendrá que leerla desde su propia configuración, con permisos mínimos.
- No hay cifrado en la conexión porque todo ocurre dentro de la misma máquina.
- La base es de práctica: no hay datos reales.

## Próximos pasos

- Backups automáticos y restauración probada (doc 02).
- Una aplicación web que use la base (Nginx + PHP-FPM).

## Aprendizajes

- Las versiones nuevas de MariaDB vienen mejor protegidas de fábrica: conviene comprobarlo en vez de asumirlo.
- La contraseña de un usuario nunca se escribe en un comando: se genera, se guarda con permisos `600` y se lee desde ahí.
- Una prueba de seguridad es útil cuando incluye lo que tiene que fallar.

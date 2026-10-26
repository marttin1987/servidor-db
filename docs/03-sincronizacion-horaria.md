# Sincronización horaria

## Estado inicial

- Sistema operativo: Debian 13.
- Zona horaria: America/Argentina/Buenos_Aires.
- Servicio NTP: systemd-timesyncd.
- Estado del servicio: activo y habilitado.
- Estado de sincronización: sincronizado.
- Fuente observada: 170.210.222.2:123.
- Fuente configurada: 2.debian.pool.ntp.org.

## Verificaciones

Comandos ejecutados en la VM:

- `timedatectl status`
- `timedatectl timesync-status`
- `systemctl status systemd-timesyncd --no-pager`

## Decisión técnica

La sincronización horaria funciona con systemd-timesyncd.
Chrony queda como mejora futura para practicar su instalación,
configuración y verificación mediante una transición controlada.

No se afirma que Chrony esté instalado ni configurado.

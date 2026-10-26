# Sincronización horaria

## Estado final

- Sistema operativo: Debian 13.
- Zona horaria: America/Argentina/Buenos_Aires.
- Servicio: Chrony.
- Estado del servicio: activo y habilitado.
- Sincronización del sistema: confirmada por timedatectl.
- Fuente seleccionada observada: evlbi.aggo-conicet.gob.ar.
- Estrato observado: 3.

## Verificaciones realizadas

```bash
systemctl is-active chrony
systemctl is-enabled chrony
timedatectl status
chronyc tracking
chronyc sources -v
```

## Resultado

Chrony está activo y habilitado para iniciar con el sistema.
timedatectl confirma que el reloj está sincronizado.
chronyc sources -v identifica la fuente seleccionada mediante
el indicador ^*.

La dispersión y las estimaciones de frecuencia observadas
durante la primera verificación deben revisarse nuevamente
si se necesita evaluar la estabilidad a lo largo del tiempo.

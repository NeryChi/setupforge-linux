# Módulo: Cloudflare Tunnel (system-wide)

Este módulo instala y configura un túnel de Cloudflare usando el paquete .deb oficial (sin repos APT), y crea un servicio systemd de mínimo privilegio para ejecutarlo a nivel de sistema.

## Qué hace

1. Detecta la arquitectura y descarga el .deb oficial desde GitHub Releases (canal "latest").
2. Instala `cloudflared` desde ese .deb (APT resuelve dependencias).
3. Realiza el login contra tu cuenta de Cloudflare (interactivo).
4. Crea o reutiliza el túnel, guarda su credencial en `/etc/cloudflared`, y genera `config.yml`.
5. Instala el servicio systemd endurecido, opcionalmente habilitado al arranque.
6. Crea o asegura el registro DNS del hostname hacia el túnel.

## Archivos y permisos

- Configuración: `/etc/cloudflared/config.yml` (root:root, 0644)
- Credenciales del túnel: `/etc/cloudflared/<UUID>.json` (cloudflared:cloudflared, 0600)
- Servicio: `/etc/systemd/system/cloudflared.service` (root:root, 0644)

## Flujo de uso

1. Ejecuta el router del repositorio y elige Cloudflare Tunnel:
   - `sudo ./setup.sh`
2. Autoriza el login de `cloudflared` (se mostrará una URL).
3. Ingresa `tunnel_name`, `hostname` y `service_url`.
4. Decide si habilitar autostart.
5. Verifica:
   - `systemctl status cloudflared`
   - `journalctl -u cloudflared -f`
   - `cloudflared tunnel list`

## Idempotencia

- Si `cloudflared` ya está instalado con la misma versión, la reinstalación no hace cambios.
- Si el túnel ya existe/DNS ya existe, las tareas lo detectan y no duplican.
- Plantillas y servicio se actualizan solo si cambian las variables o archivos base.
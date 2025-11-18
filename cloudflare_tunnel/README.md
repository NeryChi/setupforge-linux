# Módulo: Cloudflare Tunnel (nivel de servidor)

Este módulo instala y configura un túnel de Cloudflare (`cloudflared`) para exponer un servicio local del servidor a Internet mediante un hostname público. La configuración y el servicio se aplican a nivel de sistema (system-wide), de modo que el túnel puede iniciar automáticamente al arrancar el servidor sin requerir una sesión de usuario.

## Qué hace este módulo

1. Instala `cloudflared` desde el repositorio oficial (APT).
2. Realiza autenticación contra tu cuenta de Cloudflare (interactiva) para obtener la credencial de administración.
3. Crea (si no existe) un túnel con el nombre especificado.
4. Asegura la credencial del túnel y la configuración en `/etc/cloudflared/`.
5. Crea y gestiona el servicio systemd `cloudflared.service`.
6. Crea/asegura el registro DNS para el hostname indicado.

## Variables que se te pedirán (prompts)

- `tunnel_name` (por defecto: `server-tunnel`)
  - Nombre lógico para identificar el túnel.
- `hostname` (obligatorio)
  - Dominio/hostname público que apuntará al túnel (ejemplo: `app.midominio.com`).
- `service_url` (por defecto: `http://localhost:80`)
  - Servicio local que se expondrá a través del túnel (puede ser `http://localhost:8080`, `ssh://localhost:22`, etc.).
- `enable_autostart` (S/n al finalizar)
  - Si respondes Sí, el servicio `cloudflared` se habilitará para iniciar automáticamente al arrancar el servidor.

## Secretos y archivos importantes

- Secreto (auth de cuenta):
  - `/root/.cloudflared/cert.pem`
  - Origen: generado por `cloudflared tunnel login` (interactivo).
  - Uso: permite crear/administrar túneles y DNS contra tu cuenta de Cloudflare.

- Secreto (credencial del túnel):
  - `/etc/cloudflared/<TUNNEL_UUID>.json` (propietario root, modo 0600)
  - Uso: clave que `cloudflared` necesita para ejecutar `tunnel run`.

- Configuración:
  - `/etc/cloudflared/config.yml` (propietario root, modo 0644)
  - Contiene: `tunnel: <UUID>`, `credentials-file: ...`, e `ingress` con el mapeo `hostname -> service_url`.

- Servicio systemd:
  - `/etc/systemd/system/cloudflared.service`
  - Ejecuta `cloudflared tunnel run --config /etc/cloudflared/config.yml`.

## Permisos y seguridad

- Directorio `/etc/cloudflared`: root:root, 0755.
- `*.json` de credenciales: root:root, 0600 (sensibles).
- `config.yml`: root:root, 0644 (no contiene secretos, solo referencias).
- El servicio corre como root porque gestiona red y arranca al boot; la información sensible está protegida por permisos.

## Uso

1) Ejecuta el router principal:
```bash
sudo ./setup.sh
```

2) Elige "Cloudflare Tunnel" y sigue los prompts:
- Autenticación (abrirás una URL en tu navegador).
- Nombre del túnel, hostname público, y `service_url`.
- Decide si habilitar autostart al arrancar el servidor.

3) Verifica:
```bash
systemctl status cloudflared
journalctl -u cloudflared -f
cloudflared tunnel list
cloudflared tunnel info <tunnel_name>
```

## Idempotencia (qué ocurre al re-ejecutar)

- Si `cloudflared` ya está instalado: no se reinstala.
- Si el túnel ya existe: se reutiliza su UUID.
- Si el DNS ya existe: no se modifica (la tarea detecta "already exists").
- `config.yml` y el servicio systemd se recrean solo si cambian las plantillas/variables.

## Problemas comunes

- Error resolviendo UUID del túnel:
  - Asegúrate de haber completado el login (debe existir `/root/.cloudflared/cert.pem`).
- Servicio no arranca:
  - Revisa `journalctl -u cloudflared -f`. Verifica que `service_url` sea accesible localmente.
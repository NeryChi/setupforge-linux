#!/usr/bin/env bash
# cloudflare/setup.sh
# Propósito:
# - Proveer una experiencia tipo "instalador" en consola para crear y configurar un túnel Cloudflare.
# - Mantener la lógica de configuración en Ansible (idempotente), usando este script solo para interacción y orquestación.
#
# Diseño:
# - Nivel: servidor (system-wide). Los archivos quedan en /etc/cloudflared y el servicio es systemd de sistema.
# - Seguridad: credenciales sensibles con permisos estrictos; nada se guarda en el repositorio.
#
# Interacción (prompts):
# - Login de Cloudflare (abre una URL para autorizar este servidor).
# - Solicitar tunnel_name, hostname público y service_url.
# - Preguntar si se habilita el autostart al arrancar el servidor.
#
# Resultado:
# - Servicio cloudflared activo y (opcionalmente) habilitado al boot.
# - Registro DNS creado (idempotente).

set -euo pipefail

require_root() {
  # Este módulo instala paquetes y configura systemd: requiere root.
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root. Usa: sudo ./cloudflare/setup.sh"
    exit 1
  fi
}

show_invoker() {
  # Estético/informativo: indica quién lanzó el instalador.
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    INVOKER="${SUDO_USER}"
  else
    INVOKER="$(logname 2>/dev/null || whoami)"
  fi
  echo "Ejecutado por: ${INVOKER}"
}

here_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_dependencies() {
  # Instala dependencias necesarias de forma idempotente.
  echo "Verificando dependencias (Git, Ansible, jq, cloudflared)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -qq
  command -v git >/dev/null 2>&1 || apt-get install -y -qq git
  command -v ansible >/dev/null 2>&1 || apt-get install -y -qq ansible
  command -v jq >/dev/null 2>&1 || apt-get install -y -qq jq

  # Instala cloudflared a través de Ansible (agrega repo oficial y paquete).
  ansible-playbook -i localhost, --connection=local "${here_dir}/playbook.yml" --tags install
}

interactive_login() {
  # El login genera /root/.cloudflared/cert.pem para autorizar operaciones con tu cuenta de Cloudflare.
  echo ""
  echo "Autenticación con Cloudflare (modo servidor, como root)."
  echo "Se mostrará una URL. Ábrela en tu navegador y autoriza este servidor."
  cloudflared tunnel login
  echo "Login completado. Se generó /root/.cloudflared/cert.pem"
}

collect_vars() {
  # Recopila variables requeridas para el playbook.
  echo ""
  echo "Configuración del túnel:"
  read -rp "Nombre del túnel [server-tunnel]: " TUNNEL_NAME
  TUNNEL_NAME="${TUNNEL_NAME:-server-tunnel}"

  read -rp "Hostname público (ej: app.tudominio.com): " CF_HOSTNAME
  if [[ -z "${CF_HOSTNAME}" ]]; then
    echo "El hostname es requerido."
    exit 1
  fi

  read -rp "Servicio local a exponer [http://localhost:80]: " SERVICE_URL
  SERVICE_URL="${SERVICE_URL:-http://localhost:80}"
}

ask_autostart_boot() {
  # Decide si el servicio debe iniciar automáticamente al arrancar el servidor.
  echo ""
  read -rp "¿Quieres que el túnel se inicie automáticamente al arrancar el servidor? [S/n]: " aut
  aut="${aut:-S}"
  if [[ "$aut" =~ ^[sS]$ ]]; then
    ENABLE_AUTOSTART="true"
  else
    ENABLE_AUTOSTART="false"
  fi
}

apply_configuration() {
  # Ejecuta el playbook (idempotente) con las variables recolectadas.
  echo ""
  echo "Aplicando configuración idempotente..."
  extra_vars="$(jq -n \
    --arg tn "$TUNNEL_NAME" \
    --arg hn "$CF_HOSTNAME" \
    --arg su "$SERVICE_URL" \
    --arg ea "$ENABLE_AUTOSTART" \
    '{tunnel_name:$tn, hostname:$hn, service_url:$su, enable_autostart:($ea=="true")}'
  )"

  ansible-playbook -i localhost, --connection=local "${here_dir}/playbook.yml" \
    --tags configure \
    --extra-vars "${extra_vars}"
}

require_root
show_invoker
install_dependencies
interactive_login
collect_vars
ask_autostart_boot
apply_configuration

echo ""
echo "Instalación completada."
echo "Comandos útiles:"
echo "  - Estado del servicio:       systemctl status cloudflared"
echo "  - Iniciar/Detener/Restart:   systemctl start|stop|restart cloudflared"
echo "  - Habilitar al arranque:     systemctl enable cloudflared"
echo "  - Logs (tiempo real):        journalctl -u cloudflared -f"
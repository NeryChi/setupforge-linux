#!/usr/bin/env bash
# cloudflare_tunnel/setup.sh
# Propósito:
# - Proveer experiencia de instalación y configuración del túnel de Cloudflare a nivel de servidor.
# - Mantener la lógica idempotente en Ansible (este script solo orquesta y recopila variables).
#
# Notas:
# - La instalación de cloudflared se hace desde el .deb oficial (sin repos APT) dentro del playbook (tag install).
# - Este script requiere root para instalar paquetes del sistema y configurar systemd.

set -euo pipefail

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root. Usa: sudo ./cloudflare_tunnel/setup.sh"
    exit 1
  fi
}

show_invoker() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    INVOKER="${SUDO_USER}"
  else
    INVOKER="$(logname 2>/dev/null || whoami)"
  fi
  echo "Ejecutado por: ${INVOKER}"
}

here_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_dependencies() {
  echo "Verificando dependencias (Git, Ansible, jq)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -qq
  command -v git >/dev/null 2>&1 || apt-get install -y -qq git
  command -v ansible >/dev/null 2>&1 || apt-get install -y -qq ansible
  command -v jq >/dev/null 2>&1 || apt-get install -y -qq jq

  # Instala cloudflared desde .deb con Ansible (tag install)
  ansible-playbook -i localhost, --connection=local "${here_dir}/playbook.yml" --tags install
}

interactive_login() {
  echo ""
  echo "Autenticación con Cloudflare."
  echo "Se mostrará una URL. Ábrela en tu navegador y autoriza este servidor."
  cloudflared tunnel login
  echo "Login completado."
}

collect_vars() {
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
  echo ""
  read -rp "¿Iniciar el túnel automáticamente al arrancar el servidor? [S/n]: " aut
  aut="${aut:-S}"
  if [[ "$aut" =~ ^[sS]$ ]]; then
    ENABLE_AUTOSTART="true"
  else
    ENABLE_AUTOSTART="false"
  fi
}

apply_configuration() {
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
echo "Listo. Comandos útiles:"
echo "  systemctl status cloudflared"
echo "  journalctl -u cloudflared -f"
echo "  cloudflared tunnel list"
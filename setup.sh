#!/usr/bin/env bash
# setup.sh (raíz)
# Propósito:
# - Actúa como "router" del sistema modular.
# - Realiza el bootstrap idempotente de dependencias mínimas (Git y Ansible).
# - Presenta un menú y delega el control al módulo elegido, manteniendo el diseño desacoplado.
#
# Notas:
# - Este script se ejecuta con privilegios de root porque instala paquetes del sistema.
# - Los módulos pueden pedir autenticaciones o variables; la configuración real se aplica con Ansible.

set -euo pipefail

require_root() {
  # En Linux, instalar paquetes del sistema requiere privilegios de administrador (root).
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root. Usa: sudo ./setup.sh"
    exit 1
  fi
}

show_invoker() {
  # Muestra quién invocó el instalador (estético, útil en servidores multiusuario).
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    INVOKER="${SUDO_USER}"
  else
    INVOKER="$(logname 2>/dev/null || whoami)"
  fi
  echo "Ejecutado por: ${INVOKER}"
}

bootstrap_dependencies() {
  # Instala Git y Ansible de manera idempotente (si ya existen, no hace nada).
  echo "Verificando dependencias (Git y Ansible) de manera idempotente..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -qq
  command -v git >/dev/null 2>&1 || apt-get install -y -qq git
  command -v ansible >/dev/null 2>&1 || apt-get install -y -qq ansible
}

main_menu() {
  # Menú simple. Cada módulo es un subdirectorio con su propio setup.sh.
  echo ""
  echo "========================================"
  echo "  Sistema de Configuración Modular"
  echo "========================================"
  echo "Seleccione una opción:"
  echo "  1) Cloudflare Tunnel (nivel de servidor)"
  echo "  2) Kasm Workspace (próximamente)"
  echo "  0) Salir"
  echo "----------------------------------------"
  read -rp "Opción: " opt
  case "$opt" in
    1)
      if [[ -x "./cloudflare_tunnel/setup.sh" ]]; then
        exec ./cloudflare_tunnel/setup.sh
      else
        echo "No se encontró ./cloudflare_tunnel/setup.sh o no es ejecutable."
        exit 1
      fi
      ;;
    2)
      echo "Módulo Kasm aún no implementado. Próximamente."
      ;;
    0)
      echo "Saliendo."
      exit 0
      ;;
    *)
      echo "Opción inválida."
      ;;
  esac
}

require_root
show_invoker
bootstrap_dependencies
main_menu
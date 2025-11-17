# Sistema de Configuración Modular (Ubuntu/Kubuntu)

Este repositorio implementa un sistema modular e idempotente para automatizar configuraciones de servidor en Ubuntu/Kubuntu usando Ansible. El archivo `setup.sh` en la raíz actúa como "router": realiza el bootstrap mínimo (instalar Git/Ansible si faltan), muestra un menú y delega la ejecución al módulo seleccionado.

## Estructura general

```
.
├── setup.sh                     # Router principal (bootstrap + menú)
├── cloudflare/
│   ├── README.md                # Documentación del módulo Cloudflare Tunnel
│   ├── setup.sh                 # Interacción (prompts, login) y ejecución del playbook
│   ├── playbook.yml             # Lógica idempotente de Ansible (nivel de servidor)
│   └── files/
│       ├── config.yml.j2        # Plantilla de configuración de cloudflared
│       └── cloudflared.service.j2  # Plantilla de servicio systemd (system-wide)
└── kasm/
    └── README.md                # Placeholder con objetivos y variables esperadas
```

- Cada módulo es autocontenido: tiene su propio `setup.sh` (interactivo), su `playbook.yml` (idempotente) y sus archivos auxiliares en `files/`.
- La configuración se aplica con conexión local de Ansible (el servidor se configura a sí mismo).

## Flujo de ejecución (resumen)

1. Ejecuta como root: `sudo ./setup.sh`
2. Elige un módulo (por ejemplo, Cloudflare Tunnel).
3. El módulo:
   - Instala dependencias necesarias (idempotente).
   - Realiza autenticaciones o solicita variables (prompts).
   - Ejecuta el playbook Ansible con las variables recolectadas.
   - Opcionalmente habilita el servicio para iniciar al arrancar el servidor.
4. Al finalizar, verás un resumen y comandos útiles (estado del servicio, logs, etc.).

## Estándares de documentación

- Cada módulo incluye su propio README con:
  - Variables requeridas y opcionales.
  - Secretos utilizados (tipo, ubicación, permisos).
  - Rutas relevantes y archivos generados.
  - Flujo de interacción y comandos de verificación.
- Los scripts y plantillas están comentados con explicaciones de propósito y decisiones técnicas.

## Seguridad

- Los secretos NUNCA se guardan en el repositorio.
- Permisos estrictos en archivos sensibles (0600) y directorios (0700/0755 según corresponda).
- Ansible se usa para garantizar idempotencia y reproducibilidad.

## Evolución futura (plan)

- CLI parametrizable (además de prompts), sin duplicar lógica: los mismos playbooks, con entrada por argumentos o archivo de variables.
- API opcional (microservicio) que invocará la CLI parametrizable. La API no reimplementa la lógica; solo orquesta la ejecución.
- Este plan de evolución no requiere cambios conceptuales en los módulos actuales, solo agregar una capa de entrada alternativa más adelante.

## Requisitos

- Ubuntu/Kubuntu Server con acceso root.
- Conexión a Internet para instalar paquetes (Git, Ansible, cloudflared, etc.).

## Comandos de referencia

- Ver estado de un servicio: `systemctl status <servicio>`
- Logs en tiempo real: `journalctl -u <servicio> -f`
- Habilitar al arranque: `systemctl enable <servicio>`
- Iniciar/Parar/Restart: `systemctl start|stop|restart <servicio>`
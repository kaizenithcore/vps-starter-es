# Cambios

## [Sin publicar]

- Esqueleto inicial del repositorio.
- `scripts/check.sh`: revisa el servidor sin cambiar nada (sistema, memoria, disco, SSH, fail2ban, actualizaciones, contenedores, Coolify, puertos y firewall). Salida en texto o `--json`, y `--section` para revisar una parte.
- `scripts/harden.sh`: swap, fail2ban y actualizaciones automáticas con `--apply`; SSH solo con clave con `--apply-ssh`. Simula por defecto y se puede repetir sin efectos.
- Pruebas con bats sobre escenarios simulados (`tests/`).
- Contrato para agentes (`AGENTS.md`, `llms.txt`) y guías 00 a 03, problemas comunes y glosario.
- `README.md`, `SECURITY.md` y `CONTRIBUTING.md`.
- `tests/comprobar_docs.py`: revisa metadatos, secciones de la plantilla, enlaces, anclas e IPs.
- `docker-compose.yml` con Uptime Kuma 2.5.9 (slim, sin root): arranca cerrado en 127.0.0.1, límite de 512 MB y registros acotados. `.env.example` para abrirlo.
- Guía 04: vigilar tu servidor con Uptime Kuma.

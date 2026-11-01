# Cambios

## [Sin publicar]

- Esqueleto inicial del repositorio.
- `scripts/check.sh`: revisa el servidor sin cambiar nada (sistema, memoria, disco, SSH, fail2ban, actualizaciones, contenedores, Coolify, puertos y firewall). Salida en texto o `--json`, y `--section` para revisar una parte.
- `scripts/harden.sh`: swap, fail2ban y actualizaciones automáticas con `--apply`; SSH solo con clave con `--apply-ssh`. Simula por defecto y se puede repetir sin efectos.
- Pruebas con bats sobre escenarios simulados (`tests/`).

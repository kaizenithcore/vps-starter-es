# Seguridad

## Cómo avisar de un fallo de seguridad

Si encuentras algo en los scripts o las guías que pueda dejar a alguien sin acceso a su servidor o exponerlo, **no abras una incidencia pública**. Usa la opción privada de GitHub: pestaña **Security** → **Report a vulnerability**.

Cuéntanos qué pasa, cómo reproducirlo y en qué versión de Ubuntu. No incluyas IPs, contraseñas ni claves reales.

## Qué hacen los scripts para no dejarte fuera

- `check.sh` solo lee: nunca cambia nada.
- `harden.sh` simula por defecto y solo aplica con `--apply`.
- El cambio de SSH va aparte (`--apply-ssh`): se niega si no hay ninguna clave autorizada para tu usuario, comprueba la configuración con `sshd -t` antes de recargar y la deshace si no es válida.
- Ningún script reinicia el servidor ni toca el firewall.

## Responsabilidad

Este proyecto se ofrece tal cual, sin garantías (ver [LICENSE](LICENSE)). Lee cada paso antes de aplicarlo y mantén siempre una sesión abierta cuando cambies SSH.

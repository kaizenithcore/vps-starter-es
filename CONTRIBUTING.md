# Cómo contribuir

Gracias por querer mejorar estas guías. Unas pocas reglas para que sigan siendo útiles para quien no es técnico.

## Guías

- Cada guía empieza con los metadatos (`id`, `objetivo`, `riesgo`, `requiere_confirmacion_humana`, `tiempo_estimado`, `requisitos`, `verificacion`, `reversion`) y sigue la misma estructura: *Antes de empezar*, *Pasos*, *Cómo saber que ha ido bien*, *Si algo falla*, *Cómo deshacerlo*. Copia una existente como plantilla.
- Español llano: una idea por paso, frases cortas, ninguna sigla sin explicar (enlaza al [glosario](docs/glosario.md) la primera vez).
- Cada paso dice qué hace, por qué importa, qué verás si va bien y qué hacer si no.
- Debajo de cada comando, la salida esperada.
- Los pasos con riesgo (SSH, firewall, reiniciar, borrar) llevan la marca `> **ALTO: necesita confirmación humana.**`.
- Nada de IPs, nombres de usuario, claves ni datos reales. Usa `IP_DE_TU_SERVIDOR`, `TU_IP`, `NOMBRE`.

## Scripts

- `shellcheck` sin avisos.
- Idempotentes: ejecutarlos dos veces no cambia nada la segunda vez.
- Simulan por defecto; aplicar exige una opción explícita.
- Cada cambio con pruebas en `tests/` (bats).

## Pruebas

En Ubuntu 24.04 (o WSL con Ubuntu 24.04):

```bash
sudo apt install -y bats shellcheck
shellcheck -x scripts/*.sh scripts/lib/*.sh tests/helpers.bash
bats tests
```

Las pruebas no tocan tu sistema: usan escenarios simulados en `tests/fixtures/`.

Antes de proponer un cambio en `harden.sh`, pruébalo también en una máquina virtual desechable con Ubuntu 24.04.

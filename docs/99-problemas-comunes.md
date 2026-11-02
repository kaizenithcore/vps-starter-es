---
id: 99-problemas-comunes
objetivo: Encontrar la causa y la solución de los problemas más habituales a partir de lo que ves
riesgo: medio
requiere_confirmacion_humana: true
tiempo_estimado: según el problema
requisitos: [01-conectar-al-servidor]
verificacion: scripts/check.sh
reversion: "#cómo-deshacerlo"
---

# Problemas comunes

**En una frase:** busca lo que te pasa, mira por qué suele pasar y sigue los pasos para arreglarlo.

Todos estos casos han pasado de verdad en un VPS de Hostinger con Ubuntu 24.04.

## Antes de empezar

- Empieza siempre con `sudo scripts/check.sh` (dentro del servidor, en la carpeta del repositorio). Cada `[AVISO]` y `[FALLO]` te dice a qué sección de esta página ir.
- Algunos arreglos reinician o borran cosas: van marcados con **ALTO**.

## Pasos

Busca tu síntoma y sigue sus pasos.

### Me he quedado fuera del servidor

**Síntoma:** no puedes entrar por SSH.

| Lo que ves | Causa probable | Solución |
| --- | --- | --- |
| `Connection timed out` | El firewall de Hostinger no deja pasar el puerto 22 | En hPanel, desactiva el firewall y espera dos minutos. Corrige las reglas con la [guía 03](03-firewall-de-hostinger.md) |
| `Permission denied (publickey)` | El servidor ya no acepta contraseñas y tu clave no está o no es la correcta | Si tienes otra sesión abierta, deshaz el cambio de SSH ([guía 02](02-proteger-el-servidor.md#cómo-deshacerlo)). Si no, prueba la terminal del navegador de hPanel |
| `Connection refused` tras varios intentos | fail2ban te ha bloqueado | Mira [fail2ban me ha bloqueado](#fail2ban-me-ha-bloqueado) |

Si nada de eso funciona: en hPanel comprueba que el VPS está encendido (estado "en ejecución") y, si sigue sin entrar, contacta con el soporte de Hostinger. Evita reinstalar el sistema: borra todo lo que hay en el servidor.

### fail2ban me ha bloqueado

**Síntoma:** después de varios intentos fallidos, el servidor te rechaza aunque ahora uses la clave buena.

**Causa:** fail2ban bloquea durante una hora a quien falla 5 veces en 10 minutos. A veces pasa si tu ordenador prueba varias claves antes de la buena.

**Solución:** espera una hora, o desbloquéate desde otra sesión o desde la terminal del navegador de hPanel. Cambia `TU_IP` por tu IP pública (búscala en tu navegador con "cuál es mi IP"):

```bash
sudo fail2ban-client set sshd unbanip TU_IP
```

Deberías ver `1`. Para que tu ordenador use siempre la clave correcta, conéctate con `ssh -i ~/.ssh/id_ed25519 root@IP_DE_TU_SERVIDOR`.

### El panel de Coolify no carga

**Síntoma:** el panel de Coolify se queda cargando hasta dar error de tiempo de espera, pero tus apps siguen funcionando.

**Causa:** los contenedores del propio Coolify están parados, aunque el proxy y tus apps sigan vivos. `check.sh` lo marca como `[FALLO]  Coolify está instalado pero su panel está parado.`

**Solución:**

1. Mira qué contenedores de Coolify están parados:

   ```bash
   sudo docker ps -a --filter name=coolify --format '{{.Names}}: {{.Status}}'
   ```

   Deberías ver algunos con `Exited`.

2. Vuelve a levantarlos con la misma configuración con la que se instaló Coolify. No actualiza Coolify:

   ```bash
   cd /data/coolify/source && sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
   ```

   Si en esa carpeta existe `docker-compose.custom.yml`, añade `-f docker-compose.custom.yml` después de `docker-compose.prod.yml`.

3. Comprueba que escuchan sus puertos:

   ```bash
   sudo ss -ltn | grep -E ':(8000|6001|6002) '
   ```

   Deberías ver tres líneas, una por puerto.

4. Si el panel sigue sin cargar desde fuera, revisa que el firewall de Hostinger permite 8000, 6001 y 6002 ([guía 03](03-firewall-de-hostinger.md)).

### El sistema mata procesos por falta de memoria

**Síntoma:** tu app se cae sin motivo aparente, sobre todo mientras construyes otra. `check.sh` avisa de que el sistema ha cerrado programas por falta de memoria.

**Causa:** la memoria se llena (4 GB se quedan cortos con builds o agentes) y, sin swap, el sistema cierra programas a la fuerza para sobrevivir. En el registro aparece como `oom-kill` o `Out of memory`.

**Solución:**

1. Mira qué se ha cerrado:

   ```bash
   sudo journalctl -k --since "-7d" | grep -i "killed process"
   ```

2. Si no tienes swap, créala con la [guía 02](02-proteger-el-servidor.md#memoria-de-intercambio-swap).
3. Mira qué consume más memoria y para lo que no uses:

   ```bash
   sudo docker stats --no-stream --format '{{.Name}}: {{.MemUsage}}'
   ```

4. A medio plazo: construye tu app fuera del servidor (por ejemplo en GitHub Actions) y despliega solo la imagen ya construida. Así el servidor no necesita memoria extra para construir.

### Disco lleno

**Síntoma:** `check.sh` dice que el disco está por encima del 80 %, o las apps empiezan a fallar al guardar.

**Causa habitual:** imágenes viejas de Docker, registros que crecen sin límite o copias que se acumulan.

**Solución:**

1. Mira qué ocupa más:

   ```bash
   df -h /
   sudo docker system df
   sudo du -xh / --max-depth=1 2>/dev/null | sort -h | tail -n 8
   ```

2. Limpia lo seguro (no toca nada en uso):

   ```bash
   sudo apt clean && sudo journalctl --vacuum-size=200M
   ```

3. Imágenes de Docker que no usa ningún contenedor:

   > **ALTO: necesita confirmación humana.** Se borran las imágenes de Docker que no usa ningún contenedor. Si paraste una app a propósito, su imagen se borrará y tendrá que descargarse de nuevo.

   ```bash
   sudo docker image prune -a
   ```

No borres carpetas de `/data` ni volúmenes de Docker para liberar espacio: ahí están los datos de tus apps.

### Hay que reiniciar el servidor

**Síntoma:** `check.sh` dice que el servidor necesita reiniciarse.

**Causa:** se han instalado actualizaciones (normalmente del núcleo del sistema) que solo se aplican al reiniciar.

**Solución:** sigue el paso 4 de la [guía 02](02-proteger-el-servidor.md#4-pon-el-sistema-al-día-y-reinicia-si-hace-falta). Resumido: apunta qué contenedores están en marcha, reinicia con `sudo reboot`, espera dos minutos, vuelve a entrar y comprueba con `sudo scripts/check.sh` que todo ha vuelto.

### Docker no responde

**Síntoma:** `check.sh` dice `Docker está instalado pero no responde`.

**Causa habitual:** el servicio de Docker se ha parado, a menudo por disco lleno o falta de memoria.

**Solución:**

1. Mira su estado:

   ```bash
   sudo systemctl status docker --no-pager | head -n 5
   ```

2. Si el disco está lleno, resuelve primero [disco lleno](#disco-lleno).
3. Arráncalo:

   > **ALTO: necesita confirmación humana.** Se reinicia Docker. Todos los contenedores se paran y vuelven a arrancar.

   ```bash
   sudo systemctl restart docker
   ```

### Un contenedor se reinicia sin parar

**Síntoma:** `check.sh` dice que hay contenedores que arrancan y se caen una y otra vez.

**Causa habitual:** un error de configuración (falta una variable de entorno) o falta de memoria.

**Solución:** mira sus últimos mensajes. Cambia `NOMBRE` por el nombre que te dio `check.sh`:

```bash
sudo docker logs --tail 50 NOMBRE
```

Si ves `Killed` o nada al final, mira [falta de memoria](#el-sistema-mata-procesos-por-falta-de-memoria). Si ves un error de tu app, el problema está en su configuración: enséñale esos mensajes a tu agente. **No le pegues líneas que contengan contraseñas o tokens.**

### El escáner de malware deja el VPS sin gestión

**Síntoma:** después de pedir en hPanel que se instale el escáner de malware, el VPS no responde a las acciones del panel durante un buen rato.

**Causa:** según Hostinger, su instalación puede tardar hasta 60 minutos.

**Solución:** espera. La próxima vez, instálalo al final, cuando no tengas otras tareas a medias.

### La terminal del navegador de hPanel ya no entra

**Síntoma:** después de la guía 02, la terminal del navegador pide contraseña y no te deja entrar.

**Causa:** el servidor ya no acepta contraseñas por SSH, y esa terminal puede necesitarla.

**Solución:** entra por SSH con tu clave desde tu ordenador. Si necesitas la terminal del navegador, puedes volver a aceptar contraseñas ([guía 02, cómo deshacerlo](02-proteger-el-servidor.md#cómo-deshacerlo)), sabiendo que el servidor queda más expuesto.

## Cómo saber que ha ido bien

`sudo scripts/check.sh` ya no muestra el `[FALLO]` o `[AVISO]` que te trajo aquí.

## Si algo falla

Si tu problema no está aquí o la solución no funciona, abre una incidencia en el repositorio con la salida de `sudo scripts/check.sh`. Antes de pegarla, revisa que no incluya IPs, nombres de usuario ni nada privado.

## Cómo deshacerlo

Cada solución de esta página indica sus riesgos. Lo que se borra (imágenes de Docker, registros antiguos) no se puede recuperar, pero las imágenes se vuelven a descargar solas cuando una app las necesita.

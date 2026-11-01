---
id: 04-vigilar-tu-servidor
objetivo: Instalar Uptime Kuma para recibir un aviso cuando tu web o tu app dejen de responder
riesgo: medio
requiere_confirmacion_humana: true
tiempo_estimado: 20 min
requisitos: [02-proteger-el-servidor, 03-firewall-de-hostinger]
verificacion: scripts/check.sh --section docker,puertos
reversion: "#cómo-deshacerlo"
---

# Vigilar tu servidor

**En una frase:** vas a instalar [Uptime Kuma](glosario.md#uptime-kuma), un vigilante que visita tu web cada minuto y te avisa (por Telegram, correo u otras vías) si deja de responder.

Así te enteras tú antes que tus usuarios.

**Una limitación que debes conocer:** Uptime Kuma vive en tu propio servidor. Si se cae el servidor entero, el vigilante cae con él y no podrá avisarte. Para eso necesitarías un servicio de vigilancia externo; esta guía cubre lo más habitual, que se caiga tu app.

## Antes de empezar

- Has hecho la [guía 02](02-proteger-el-servidor.md) y la [guía 03](03-firewall-de-hostinger.md): el firewall de Hostinger está activo.
- Tu servidor tiene [Docker](glosario.md#docker). Compruébalo dentro del servidor con `docker --version`. Si dice `command not found`, la forma más sencilla es elegir en hPanel una plantilla de Ubuntu 24.04 con Docker (ojo: cambiar de plantilla reinstala el servidor y borra lo que haya).
- Sabes tu IP pública: búscala en tu navegador con "cuál es mi IP". En los comandos aparece como `TU_IP`.

### Por qué el panel empieza cerrado

Uptime Kuma deja crear la cuenta de administrador a **la primera persona que abre el panel**. Si lo abres a Internet sin más, cualquiera que pase por ahí antes que tú puede quedárselo. Por eso el archivo de este repositorio lo arranca escuchando solo **dentro** del servidor. Lo abrirás únicamente para tu IP, y solo después de poner la regla en el firewall.

## Pasos

### 1. Arranca Uptime Kuma

Dentro del servidor, en la carpeta del repositorio:

```bash
cd ~/vps-starter-es && sudo docker compose up -d
```

La primera vez descarga la imagen (unos segundos). Deberías ver al final:

```text
Container uptime-kuma  Started
```

(Según tu terminal, puede salir con un ✔ delante.)

### 2. Comprueba que está en marcha y cerrado

```bash
sudo docker ps --filter name=uptime-kuma --format '{{.Names}}: {{.Status}}' && sudo ss -ltn | grep 3001
```

Deberías ver algo así (tras medio minuto pone `healthy`):

```text
uptime-kuma: Up 40 seconds (healthy)
LISTEN 0      4096       127.0.0.1:3001       0.0.0.0:*
```

El `127.0.0.1` significa que de momento solo se puede llegar desde dentro del servidor. Nadie de fuera puede verlo todavía.

### 3. Añade la regla del 3001 en el firewall, solo para tu IP

En hPanel, en el grupo de reglas de tu firewall (el que creaste en la [guía 03](03-firewall-de-hostinger.md#3-crea-el-grupo-de-reglas)), añade:

- **Acción:** Aceptar.
- **Protocolo:** TCP. **Puerto:** 3001.
- **Origen:** personalizado, con tu IP (`TU_IP`). **No** elijas "Cualquiera".

Comprueba que el firewall está **activo** en tu servidor. Espera dos minutos a que se aplique.

> **ALTO: necesita confirmación humana.** En el paso siguiente el panel se abre hacia fuera. Solo es seguro si la regla del 3001 está limitada a tu IP y el firewall está activo. Si no lo está, cualquiera podría crear el administrador antes que tú.

### 4. Abre el panel hacia fuera

Crea tu archivo de configuración a partir del ejemplo y cambia una línea:

```bash
cp .env.example .env && sed -i 's/^KUMA_BIND=.*/KUMA_BIND=0.0.0.0/' .env && sudo docker compose up -d
```

Comprueba:

```bash
sudo ss -ltn | grep 3001
```

Deberías ver `0.0.0.0:3001` en lugar de `127.0.0.1:3001`.

### 5. Crea tu administrador enseguida

En tu navegador, abre `http://IP_DE_TU_SERVIDOR:3001`. Uptime Kuma te hará dos preguntas:

1. **Base de datos:** elige **SQLite** (la opción sencilla, sin nada más que instalar).
2. **Cuenta de administrador:** elige un usuario y una contraseña larga. Guárdala en tu gestor de contraseñas.

Hazlo en cuanto se abra el panel. Si en vez de esas preguntas ves una pantalla de inicio de sesión que no reconoces, alguien se te ha adelantado: ve a [Si algo falla](#si-algo-falla).

**Escribe la contraseña tú en el navegador.** Si te ayuda un agente de IA, no se la digas.

### 6. Vigila tu web o tu app

En el panel, pulsa **Añadir monitor**:

- **Tipo:** HTTP(s).
- **Nombre:** el de tu app.
- **URL:** la dirección pública de tu app, por ejemplo `https://tu-dominio.com`.
- **Intervalo:** 60 segundos está bien.

Guarda. En un minuto deberías ver el monitor en verde con la palabra **Up**.

### 7. Elige cómo quieres que te avise

En **Ajustes** → **Notificaciones** → **Configurar notificación**, elige el canal que uses (Telegram, correo, Discord, Slack...). Cada uno pide sus datos, como el token de un bot de Telegram o el servidor de correo.

Esos datos son secretos: **escríbelos tú en el panel**, no los pegues en un chat. Después pulsa **Probar** y comprueba que te llega el mensaje. Por último, entra en tu monitor, pulsa **Editar** y activa esa notificación.

### 8. Comprueba con check.sh

```bash
sudo scripts/check.sh --section docker,puertos
```

Deberías ver:

```text
[OK]     El contenedor está en marcha.
[AVISO]  El puerto 3001 (Uptime Kuma) escucha hacia Internet. Asegúrate de que en el firewall de Hostinger solo tu IP puede entrar.
```

Ese AVISO es el recordatorio de que la seguridad del panel depende de la regla del firewall. Si usas Coolify u otras apps en Docker, verás más contenedores.

## Cómo saber que ha ido bien

- El monitor de tu app está en verde.
- La notificación de prueba te ha llegado.
- Desde otra conexión que no sea la tuya (por ejemplo, los datos del móvil con el wifi apagado), `http://IP_DE_TU_SERVIDOR:3001` **no** carga.

## Si algo falla

| Lo que ves | Qué significa | Qué hacer |
| --- | --- | --- |
| El panel no carga desde tu ordenador | Falta la regla del 3001, tu IP ha cambiado o `KUMA_BIND` sigue en `127.0.0.1` | Revisa el paso 3 (¿coincide tu IP actual?) y el paso 4 |
| Funcionaba y un día deja de cargar | Tu proveedor de Internet te ha cambiado la IP (pasa a menudo en casa) | Actualiza la IP en la regla del 3001 del firewall |
| Ves una pantalla de inicio de sesión que no es tuya | Alguien ha creado el administrador antes que tú | Cierra el panel (abajo, "Cómo deshacerlo"), **borra los datos** con `sudo docker compose down -v` y empieza de nuevo desde el paso 1, con la regla del firewall ya puesta |
| El monitor está en rojo pero tu web carga | La URL está mal o tu app tarda mucho en responder | Revisa la URL y sube el tiempo de espera del monitor |
| `uptime-kuma: Restarting` | El contenedor no arranca | `sudo docker logs --tail 50 uptime-kuma` y mira [problemas comunes](99-problemas-comunes.md#un-contenedor-se-reinicia-sin-parar) |

**Si te manejas con la terminal**, hay otra forma de entrar al panel sin abrir el puerto 3001 en el firewall: un túnel SSH. Desde tu ordenador, ejecuta `ssh -L 3001:127.0.0.1:3001 root@IP_DE_TU_SERVIDOR`, deja esa ventana abierta y abre `http://localhost:3001` en tu navegador. Con este método puedes dejar `KUMA_BIND` en `127.0.0.1` para siempre.

## Cómo deshacerlo

**Volver a cerrar el panel** (Uptime Kuma sigue vigilando, pero solo se puede entrar desde dentro):

```bash
rm .env && sudo docker compose up -d
```

Quita también la regla del 3001 en el firewall de Hostinger.

**Parar Uptime Kuma conservando sus datos:**

```bash
sudo docker compose down
```

**Quitarlo del todo, datos incluidos:**

> **ALTO: necesita confirmación humana.** Se borran los monitores, las notificaciones y la cuenta de administrador de Uptime Kuma. No se puede recuperar.

```bash
sudo docker compose down -v
```

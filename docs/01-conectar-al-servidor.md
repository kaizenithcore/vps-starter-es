---
id: 01-conectar-al-servidor
objetivo: Entrar al servidor desde tu ordenador con una clave SSH y descargar este repositorio en él
riesgo: bajo
requiere_confirmacion_humana: true
tiempo_estimado: 15 min
requisitos: [00-necesitas-un-vps]
verificacion: "desde tu ordenador: ssh -o PasswordAuthentication=no root@IP_DE_TU_SERVIDOR 'echo La clave funciona'"
reversion: "#cómo-deshacerlo"
---

# Conectar a tu servidor

**En una frase:** vas a crear una llave digital (una [clave SSH](glosario.md#clave-ssh)) para entrar a tu servidor sin contraseña, que es más seguro y es lo que necesita la guía 02.

[SSH](glosario.md#ssh) es la forma de escribir órdenes en tu servidor desde tu ordenador, como si tuvieras su teclado delante. Una clave SSH tiene dos partes:

- **La clave pública** es el candado: la pones en la puerta del servidor. Se puede enseñar sin miedo.
- **La clave privada** es la llave: se queda en tu ordenador y **nunca** se comparte, ni con tu agente de IA.

## Antes de empezar

- Un VPS con Ubuntu 24.04 ya creado en Hostinger.
- Acceso a hPanel, el panel de Hostinger.
- La [IP](glosario.md#ip) de tu servidor: la ves en hPanel, en la sección VPS, en el resumen de tu servidor. En los comandos de abajo aparece como `IP_DE_TU_SERVIDOR`: cámbiala por la tuya.
- La contraseña de root que elegiste al crear el VPS.

## Pasos

### 1. Abre la terminal del navegador

En hPanel, entra en **VPS**, elige tu servidor y pulsa el botón de la **terminal del navegador**. Se abre en una pestaña nueva (si no se abre, permite las ventanas emergentes).

Escribe:

```bash
grep PRETTY_NAME /etc/os-release
```

Deberías ver:

```text
PRETTY_NAME="Ubuntu 24.04.3 LTS"
```

(El último número puede variar.)

**Apunta una cosa:** ¿la terminal te pidió usuario y contraseña, o entró sola? Lo necesitarás en la guía 02.

### 2. Crea tu clave en tu ordenador

Esto se hace en **tu ordenador**, no en el servidor.

- En Windows: abre **PowerShell**.
- En macOS: abre **Terminal**.
- En Linux: abre tu terminal.

Escribe (cambia `mi-portatil` por un nombre que te ayude a reconocer este ordenador):

```bash
ssh-keygen -t ed25519 -C "mi-portatil"
```

Te hará tres preguntas:

1. Dónde guardarla: pulsa Enter para aceptar la ubicación propuesta.
2. Una frase de paso (*passphrase*): es una contraseña que protege tu llave si alguien te roba el ordenador. Recomendable. Al escribirla no verás nada en pantalla; es normal.
3. Repetir la frase de paso.

Deberías ver, entre otras líneas:

```text
Your identification has been saved in ...id_ed25519
Your public key has been saved in ...id_ed25519.pub
```

Si te dice que el archivo ya existe, **no lo sobrescribas**: ya tienes una clave y puedes usar esa. Responde `n` y sigue.

**Guarda una copia de la clave privada** (el archivo `id_ed25519`, sin `.pub`) en un sitio seguro, por ejemplo tu gestor de contraseñas. Después de la guía 02 será tu forma de entrar al servidor.

### 3. Copia tu clave pública

En Windows (PowerShell):

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

En macOS o Linux:

```bash
cat ~/.ssh/id_ed25519.pub
```

Deberías ver **una sola línea** que empieza por `ssh-ed25519 AAAA` y termina con el nombre que pusiste. Cópiala entera.

### 4. Pon el candado en tu servidor

**Opción A, desde hPanel:** entra en **VPS**, pulsa **Gestionar** en tu servidor, ve a **Ajustes** → **Claves SSH** → **Añadir clave SSH**, y pega la línea.

**Opción B, desde la terminal del navegador** (úsala si la opción A no funciona en el paso 5). Cambia `PEGA_AQUI_TU_CLAVE_PUBLICA` por la línea que copiaste, manteniendo las comillas simples:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'PEGA_AQUI_TU_CLAVE_PUBLICA' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Estos comandos no muestran nada si van bien.

### 5. Prueba que la llave abre

Desde **tu ordenador**:

```bash
ssh -o PasswordAuthentication=no root@IP_DE_TU_SERVIDOR "echo La clave funciona"
```

La primera vez te preguntará si confías en el servidor (`Are you sure you want to continue connecting`). Escribe `yes` y pulsa Enter. Si pusiste frase de paso, te la pedirá: es la de tu llave, no la contraseña del servidor.

Deberías ver:

```text
La clave funciona
```

Si ves `Permission denied (publickey)`, la clave no está bien puesta: repite el paso 4 con la opción B.

### 6. Descarga este repositorio en el servidor

Entra al servidor desde tu ordenador:

```bash
ssh root@IP_DE_TU_SERVIDOR
```

Ya dentro, descarga el repositorio y entra en su carpeta:

```bash
git clone https://github.com/kaizenithcore/vps-starter-es.git
cd vps-starter-es
```

Haz la primera revisión. No cambia nada:

```bash
sudo scripts/check.sh
```

Es normal que en un servidor recién creado veas líneas `[FALLO]`, sobre todo en SSH. Las arregla la guía 02.

## Cómo saber que ha ido bien

- El comando del paso 5 dice `La clave funciona`.
- Dentro del servidor, `scripts/check.sh` funciona y muestra un resumen al final.

## Si algo falla

| Lo que ves | Qué significa | Qué hacer |
| --- | --- | --- |
| `ssh: command not found` o "no se reconoce" en Windows | Falta el cliente SSH | En Windows 10 y 11 viene incluido: búscalo en Configuración → Aplicaciones → Características opcionales → "Cliente OpenSSH" |
| `Permission denied (publickey)` | El servidor no tiene tu clave pública | Repite el paso 4 con la opción B y comprueba que pegaste la línea entera |
| `Connection timed out` | No llegas al servidor | Comprueba la IP. Si activaste el firewall de Hostinger, mira la [guía 03](03-firewall-de-hostinger.md) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Reinstalaste el servidor y tu ordenador recuerda el anterior | En tu ordenador: `ssh-keygen -R IP_DE_TU_SERVIDOR` y vuelve a probar |
| `git: command not found` | La plantilla no trae git | En el servidor: `sudo apt update && sudo apt install -y git` |

## Cómo deshacerlo

Para quitar tu clave del servidor:

- Si la añadiste por hPanel: **Ajustes** → **Claves SSH** → **Eliminar**.
- Si la añadiste por la terminal: abre el archivo con `nano ~/.ssh/authorized_keys`, borra la línea de tu clave y guarda con Ctrl+O, Enter y Ctrl+X.

Mientras no hagas la guía 02, la contraseña de root sigue funcionando, así que no te quedarás fuera.

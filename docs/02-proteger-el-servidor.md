---
id: 02-proteger-el-servidor
objetivo: Dejar SSH solo con clave, añadir swap, fail2ban y actualizaciones automáticas, y poner el sistema al día
riesgo: medio
requiere_confirmacion_humana: true
tiempo_estimado: 20 min
requisitos: [01-conectar-al-servidor]
verificacion: scripts/check.sh --section ssh,memoria,actualizaciones
reversion: "#cómo-deshacerlo"
---

# Proteger tu servidor

**En una frase:** con un script vas a cerrar la puerta a quien intenta adivinar contraseñas, darle a tu servidor un colchón de memoria y dejar que las actualizaciones de seguridad se instalen solas.

Todo lo hace `scripts/harden.sh`. Por defecto **solo simula**: te enseña lo que haría sin tocar nada. Para aplicar hay que pedirlo expresamente, y el cambio de SSH va aparte porque es el único que puede dejarte fuera.

## Antes de empezar

- Has terminado la [guía 01](01-conectar-al-servidor.md): entras al servidor desde tu ordenador con tu clave y el repositorio está descargado en él.
- Tienes una copia de tu clave privada en un sitio seguro.
- Estás dentro del servidor, en la carpeta del repositorio (`cd ~/vps-starter-es`).

**Sobre la terminal del navegador de hPanel:** en la guía 01 apuntaste si te pedía contraseña. Hostinger no documenta si sigue funcionando cuando el servidor deja de aceptar contraseñas. Si la usas a menudo, compruébalo en el paso 5, mientras tienes otra sesión abierta, y decide con esa información.

## Pasos

### 1. Mira cómo está el servidor

```bash
sudo scripts/check.sh
```

Verás varias líneas `[OK]`, `[AVISO]` y `[FALLO]`. En un servidor recién creado lo normal es ver algo así en la parte de SSH:

```text
Acceso por SSH
[FALLO]  SSH acepta contraseñas. Cualquiera en Internet puede intentar adivinarlas; con clave no.
         Qué hacer: mira docs/02-proteger-el-servidor.md#ssh-solo-con-clave
[FALLO]  El usuario root puede entrar con contraseña. Es el primer usuario que prueban los ataques.
         Qué hacer: mira docs/02-proteger-el-servidor.md#ssh-solo-con-clave
[AVISO]  fail2ban no está activo. Es un vigilante que bloquea a quien prueba contraseñas una y otra vez.
```

### 2. Simula los cambios

```bash
sudo scripts/harden.sh
```

Deberías ver que empieza así y que cada cambio sale marcado como `[simulación]`:

```text
Modo SIMULACIÓN: se enseña lo que se haría. No se cambia nada.

== Comprobaciones previas ==
  ✓ Sistema: Ubuntu 24.04.

== Memoria de intercambio (swap) ==
  Se crea una swap de 2G en /swapfile.
  [simulación] fallocate -l 2048M /swapfile
```

Lee la lista entera. Al final verás:

```text
== Resumen ==
  Lo marcado como [simulación] NO se ha cambiado.
```

### 3. Aplica lo básico: swap, fail2ban y actualizaciones

Esto es lo que vas a activar y por qué.

#### Memoria de intercambio (swap)

La swap es un trozo de disco que el sistema usa como memoria de reserva. Es más lenta que la memoria de verdad, pero evita lo peor: cuando la memoria se llena sin swap, el sistema empieza a cerrar programas a la fuerza, y a veces cierra tu app. En un servidor de 4 GB que además construye apps, pasa más de lo que parece.

El script crea 2 GB de swap (puedes cambiarlo con `--swap-size 1G`) y solo si hay disco libre de sobra. También le dice al sistema que la use solo cuando la memoria esté casi llena (`swappiness=10`).

#### Vigilante de intentos (fail2ban)

[fail2ban](glosario.md#fail2ban) es como un portero que se fija en quién falla al entrar. Si alguien falla 5 veces en 10 minutos, le cierra la puerta durante una hora. Frena los programas que prueban contraseñas sin parar.

#### Actualizaciones automáticas

Ubuntu puede instalar solo las actualizaciones de seguridad cada día. El script lo deja activado. No reinicia el servidor por su cuenta: si una actualización lo necesita, `check.sh` te avisará.

> **ALTO: necesita confirmación humana.** Se va a crear la swap, instalar fail2ban y activar las actualizaciones automáticas. No toca SSH ni reinicia. Riesgo bajo.

```bash
sudo scripts/harden.sh --apply
```

Deberías ver flechas `→` en cada cambio y, al final:

```text
== Resumen ==
  ✓ Cambios aplicados: 12.
  Lo marcado como [simulación] NO se ha cambiado.
  Para aplicar SSH (lee antes la guía 02):        sudo scripts/harden.sh --apply-ssh
```

(El número de cambios puede variar. La parte de SSH sigue en simulación: es lo esperado.)

Si lo ejecutas otra vez, verás `ya estaba` en cada paso y ningún cambio nuevo. Es seguro repetirlo.

### 4. Pon el sistema al día y reinicia si hace falta

Un servidor recién creado suele tener decenas de actualizaciones pendientes, y algunas necesitan reiniciar.

> **ALTO: necesita confirmación humana.** Se van a instalar todas las actualizaciones pendientes. No reinicia nada todavía.

Instala las actualizaciones (es un solo comando largo; cópialo entero):

```bash
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade
```

Lo largo sirve para que no te haga preguntas a mitad: conserva tus archivos de configuración y deja los reinicios de servicios para el reinicio completo.

Mira si hace falta reiniciar:

```bash
cd ~/vps-starter-es && sudo scripts/check.sh --section actualizaciones
```

Si ves `[OK]     No hace falta reiniciar.`, has terminado este paso. Si ves `necesita reiniciarse`, sigue leyendo. No tiene que ser ahora: puedes reiniciar más tarde, en un momento tranquilo.

> **ALTO: necesita confirmación humana.** Se va a reiniciar el servidor. Tu app estará caída uno o dos minutos.

Si usas Docker, apunta qué contenedores están en marcha antes de reiniciar:

```bash
sudo docker ps --format '{{.Names}}: {{.Status}}'
```

Reinicia:

```bash
sudo reboot
```

Perderás la conexión: es normal. Espera un par de minutos, vuelve a entrar con `ssh root@IP_DE_TU_SERVIDOR` y comprueba:

```bash
cd ~/vps-starter-es && sudo scripts/check.sh --section actualizaciones,docker
```

Deberías ver `[OK]     No hace falta reiniciar.` y, si usas Docker, tus contenedores en marcha.

### 5. Deja de aceptar contraseñas en SSH

#### SSH solo con clave

Hoy cualquiera en Internet puede intentar adivinar la contraseña de root, y lo intentan miles de veces al día. Con este paso solo entra quien tenga tu llave.

El script:

- Escribe un archivo aparte, `/etc/ssh/sshd_config.d/00-hardening.conf`, sin tocar la configuración original.
- Desactiva las contraseñas (también la vía llamada "teclado interactivo", que es otra forma de pedir contraseña).
- Deja que root entre, pero solo con clave. Coolify lo necesita.
- Se niega a seguir si tu usuario no tiene ninguna clave autorizada, para que no te quedes fuera.
- Comprueba que la configuración nueva es válida antes de aplicarla, y si no lo es, la deshace.

> **ALTO: necesita confirmación humana.** Se va a desactivar la entrada con contraseña por SSH. Si tu clave no funcionase, podrías quedarte fuera. Antes de seguir: vuelve a hacer la prueba del paso 5 de la guía 01 y comprueba que dice `La clave funciona`.

**No cierres la sesión en la que estás.** Será tu puerta de emergencia. Aplica:

```bash
sudo scripts/harden.sh --apply-ssh
```

Deberías ver:

```text
== SSH: entrar solo con clave ==
  ✓ El usuario 'root' tiene 1 clave(s) autorizada(s) para entrar.
  → escribir /etc/ssh/sshd_config.d/00-hardening.conf
  ✓ La configuración de SSH es válida.
  → systemctl reload ssh
  ✓ Comprobado: SSH ya no acepta contraseñas.

  IMPORTANTE: no cierres esta sesión todavía.
```

En lugar de `→ systemctl reload ssh` puede salir `SSH arranca bajo demanda: la próxima conexión ya usará la configuración nueva.` Las dos cosas son correctas: depende de si SSH estaba en marcha en ese momento.

Ahora, **en otra ventana de tu ordenador**, sin cerrar la primera:

```bash
ssh root@IP_DE_TU_SERVIDOR "echo Sigo pudiendo entrar"
```

Deberías ver `Sigo pudiendo entrar`.

Comprueba también que las contraseñas ya no sirven:

```bash
ssh -o PubkeyAuthentication=no root@IP_DE_TU_SERVIDOR true
```

Deberías ver `Permission denied (publickey).` Eso es lo que queremos.

Si usas la terminal del navegador de hPanel, ábrela ahora y anota si sigue entrando. Si no entra, tu forma de acceder será siempre SSH con tu clave: asegúrate de tener la copia de seguridad de la clave privada. Si prefieres conservar la terminal del navegador a cambio de seguir aceptando contraseñas, deshaz este paso (ver más abajo); `check.sh` lo seguirá marcando como FALLO.

Cuando todo vaya bien, ya puedes cerrar la primera sesión.

### 6. Comprueba el resultado

```bash
sudo scripts/check.sh
```

Deberías ver la parte de SSH así:

```text
Acceso por SSH
[OK]     SSH no acepta contraseñas: solo se entra con clave.
[OK]     El usuario root solo puede entrar con clave.
[OK]     fail2ban está activo: bloquea durante un rato a quien falla muchas veces al entrar.
```

## Cómo saber que ha ido bien

`sudo scripts/check.sh` termina sin ninguna línea `[FALLO]`. Es normal que quede un `[AVISO]` sobre el firewall de Hostinger: no se puede ver desde dentro del servidor y se revisa en la [guía 03](03-firewall-de-hostinger.md).

## Si algo falla

| Lo que ves | Qué significa | Qué hacer |
| --- | --- | --- |
| `no tiene ninguna clave autorizada` | El script no encuentra tu clave y no toca SSH para no dejarte fuera | Vuelve al paso 4 de la [guía 01](01-conectar-al-servidor.md) |
| `No hay disco suficiente para una swap` | Queda poco disco | Prueba con menos: `sudo scripts/harden.sh --apply --swap-size 1G`, o libera espacio ([problemas comunes](99-problemas-comunes.md#disco-lleno)) |
| `La nueva configuración de SSH no es válida. La deshago.` | Algo raro en la configuración de SSH | El script ya lo ha deshecho. Copia el mensaje y pide ayuda abriendo una incidencia en el repositorio |
| `Otro archivo de configuración sigue permitiendo contraseñas` | Hay otro archivo en `/etc/ssh/sshd_config.d/` que se impone | Enséñale la lista de archivos (`ls /etc/ssh/sshd_config.d/`) a tu agente o abre una incidencia |
| La nueva sesión SSH no entra después del paso 5 | Algo falla con tu clave | Desde la sesión que dejaste abierta, deshaz el cambio de SSH (abajo) y vuelve a la guía 01 |
| `Connection refused` o se corta al entrar tras varios intentos | fail2ban te ha bloqueado una hora | Mira [problemas comunes](99-problemas-comunes.md#fail2ban-me-ha-bloqueado) |

## Cómo deshacerlo

Cada parte se deshace por separado. Ejecuta solo la que quieras quitar.

**SSH** (vuelve a aceptar contraseñas):

```bash
sudo rm /etc/ssh/sshd_config.d/00-hardening.conf && sudo systemctl try-reload-or-restart ssh
```

**Swap:**

```bash
sudo swapoff /swapfile 2>/dev/null; if swapon --show | grep -q /swapfile; then echo "La swap sigue en uso: libera memoria y repite"; else sudo sed -i '\#^/swapfile #d' /etc/fstab; sudo rm -f /swapfile /etc/sysctl.d/99-vps-starter.conf; echo "Swap quitada"; fi
```

Deberías ver `Swap quitada`. Si ves `La swap sigue en uso`, el servidor la necesita ahora mismo: para alguna app y repite.

**fail2ban:**

```bash
sudo systemctl disable --now fail2ban && sudo rm /etc/fail2ban/jail.d/vps-starter.local
```

**Actualizaciones automáticas:**

```bash
sudo sed -i 's/"1"/"0"/' /etc/apt/apt.conf.d/20auto-upgrades
```

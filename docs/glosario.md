# Glosario

Palabras técnicas que salen en las guías, explicadas sin tecnicismos.

### Clave SSH

Una llave digital para entrar a tu servidor sin contraseña. Tiene dos partes: la **clave pública**, que es como un candado y se pone en el servidor (se puede compartir), y la **clave privada**, que es la llave y nunca sale de tu ordenador. Ver la [guía 01](01-conectar-al-servidor.md).

### Contenedor

Una caja cerrada donde funciona una app con todo lo que necesita. Varias apps en contenedores distintos no se molestan entre sí. Los gestiona [Docker](#docker).

### Coolify

Un panel que se instala en tu VPS para desplegar apps con unos clics, parecido a Vercel o Netlify pero en tu propio servidor. Usa los puertos 8000, 6001 y 6002.

### Docker

El programa que crea y gestiona [contenedores](#contenedor). **Docker Compose** es la forma de describir en un archivo (`docker-compose.yml`) qué contenedores quieres y cómo se conectan.

### fail2ban

Un vigilante que lee los intentos de entrada a tu servidor. Si alguien falla muchas veces seguidas, le bloquea durante un rato. Ver la [guía 02](02-proteger-el-servidor.md#vigilante-de-intentos-fail2ban).

### Firewall

El portero de tu servidor: solo deja pasar el tráfico que va a las puertas ([puertos](#puerto)) permitidas. Ver la [guía 03](03-firewall-de-hostinger.md).

### hPanel

El panel de control de Hostinger, donde gestionas tu VPS, su firewall y tus claves SSH.

### HTTP y HTTPS

Las formas en que un navegador habla con una web. HTTPS es la versión cifrada (el candado en la barra del navegador). Usan los puertos 80 y 443.

### IP

La dirección de tu servidor en Internet: cuatro números separados por puntos. La ves en hPanel. Es como la dirección postal del edificio.

### Memoria (RAM)

Donde los programas guardan lo que están usando en ese momento. Es rápida pero limitada; cuando se llena, el sistema tiene problemas. Ver [swap](#swap).

### OOM (falta de memoria)

Siglas en inglés de "sin memoria" (*out of memory*). Cuando la memoria se llena, el sistema cierra programas a la fuerza para sobrevivir. En los registros aparece como `oom-kill`.

### Puerto

Una puerta numerada del servidor. Cada servicio escucha en la suya: SSH en la 22, la web en la 80 y la 443.

### Root

El usuario administrador del servidor: puede hacerlo todo, también romperlo todo. `sudo` delante de un comando significa "hazlo como administrador".

### SSH

La forma segura de escribir órdenes en tu servidor desde tu ordenador. Las siglas vienen del inglés *Secure Shell*.

### Swap

Memoria de intercambio: un trozo del disco que el sistema usa como memoria de reserva cuando la [memoria](#memoria-ram) se llena. Es más lenta, pero evita que se cierren programas. Ver la [guía 02](02-proteger-el-servidor.md#memoria-de-intercambio-swap).

### Terminal

La ventana donde escribes órdenes en texto. En Windows se llama PowerShell; en macOS, Terminal. La **terminal del navegador** de hPanel es una terminal del servidor que se abre en una pestaña.

### Ubuntu

El sistema operativo de tu servidor, como Windows o macOS en tu ordenador. Estas guías están hechas para la versión 24.04.

### Uptime Kuma

Un programa que comprueba cada poco tiempo si tu web o tu app responden y te avisa si se caen. Ver la [guía 04](04-vigilar-tu-servidor.md).

### VPS

Servidor privado virtual (en inglés, *Virtual Private Server*): un ordenador en un centro de datos, compartido físicamente con otros pero que se comporta como si fuera solo tuyo. Ver la [guía 00](00-necesitas-un-vps.md).

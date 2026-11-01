# vps-starter-es

**Has comprado un servidor y no sabes por dónde empezar.** Estas guías te llevan, en español y sin tecnicismos, de "acabo de comprar un VPS" a "mi servidor está protegido y sé si algo va mal". Puedes seguirlas tú, o pedírselo a tu agente de IA.

<!--
  Hito 5 (pendiente de visto bueno): botón "Deploy on Hostinger" y divulgación de afiliación.
  No añadir hasta tener la aprobación explícita.
-->

## Para quién es

Para quien ha hecho su app con Lovable, Bolt, Replit, v0, Cursor o Claude Code y ahora la quiere en un servidor propio. No hace falta saber qué es SSH ni un firewall: las guías lo explican cuando hace falta.

**¿Seguro que necesitas un servidor?** Muchas apps funcionan mejor en un hosting gestionado, sin nada que mantener. La [guía 00](docs/00-necesitas-un-vps.md) te ayuda a decidirlo en 5 minutos.

## Qué conseguirás

- Entrar a tu servidor con una llave digital en vez de contraseña.
- Que nadie pueda entrar adivinando contraseñas.
- Un colchón de memoria para que tu app no se caiga cuando el servidor va justo.
- Actualizaciones de seguridad que se instalan solas.
- Un firewall que solo deja abiertas las puertas que usas.
- Una revisión rápida (`check.sh`) que te dice en lenguaje llano qué está bien y qué no.
- Un aviso en tu móvil o tu correo si tu app deja de responder.

## Cómo empezar

Sigue las guías en orden:

1. [¿Necesitas un VPS?](docs/00-necesitas-un-vps.md) (5 min)
2. [Conectar al servidor](docs/01-conectar-al-servidor.md) (15 min)
3. [Proteger el servidor](docs/02-proteger-el-servidor.md) (20 min)
4. [El firewall de Hostinger](docs/03-firewall-de-hostinger.md) (15 min)
5. [Vigilar tu servidor](docs/04-vigilar-tu-servidor.md): que te avise si tu app se cae (20 min)

Si algo va mal: [problemas comunes](docs/99-problemas-comunes.md). Si una palabra no te suena: [glosario](docs/glosario.md).

## Con tu agente de IA

Si usas Claude Code, Cursor u otro agente, puedes pedirle:

```text
Lee AGENTS.md de https://github.com/kaizenithcore/vps-starter-es y ayúdame
a dejar mi servidor en verde. Para y pregúntame antes de cada paso con riesgo.
```

El archivo [AGENTS.md](AGENTS.md) le obliga a simular antes de cambiar nada, a pedirte permiso en cada paso con riesgo y a no pedirte nunca contraseñas ni claves privadas. Aun así, lee lo que te propone antes de decir que sí.

## Cómo se ve

Antes, en un servidor recién creado:

```text
Acceso por SSH
[FALLO]  SSH acepta contraseñas. Cualquiera en Internet puede intentar adivinarlas; con clave no.
[FALLO]  El usuario root puede entrar con contraseña. Es el primer usuario que prueban los ataques.
[AVISO]  fail2ban no está activo. Es un vigilante que bloquea a quien prueba contraseñas una y otra vez.
```

Después de la guía 02:

```text
Acceso por SSH
[OK]     SSH no acepta contraseñas: solo se entra con clave.
[OK]     El usuario root solo puede entrar con clave.
[OK]     fail2ban está activo: bloquea durante un rato a quien falla muchas veces al entrar.
```

## Qué es de Hostinger y qué vale para cualquiera

Los pasos dentro del servidor valen para cualquier VPS con Ubuntu 24.04, sea del proveedor que sea. Solo la [guía 03](docs/03-firewall-de-hostinger.md), la del firewall, usa el panel de Hostinger.

## Seguridad y responsabilidad

Los scripts simulan por defecto y no cambian nada hasta que se lo pides. El cambio que puede dejarte fuera (SSH) va aparte, comprueba que tienes una llave antes de aplicarse y la guía explica cómo deshacerlo. Aun así, tu servidor es responsabilidad tuya: lee cada paso antes de aplicarlo. Este proyecto se ofrece tal cual, sin garantías (ver [LICENSE](LICENSE)).

¿Has encontrado un fallo de seguridad? Mira [SECURITY.md](SECURITY.md).

<!--
  Hito 5 (pendiente de decisión): sección "¿Prefieres que lo haga yo?" con el enlace al servicio.
-->

## Licencia

[MIT](LICENSE). Puedes usarlo, copiarlo y adaptarlo.

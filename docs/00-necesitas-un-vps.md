---
id: 00-necesitas-un-vps
objetivo: Decidir con honestidad si te hace falta un VPS o te basta un hosting gestionado
riesgo: bajo
requiere_confirmacion_humana: false
tiempo_estimado: 5 min
requisitos: []
verificacion: ninguna (es una decisión, no un cambio)
reversion: no aplica
---

# ¿De verdad necesitas un VPS?

**En una frase:** un servidor privado virtual ([VPS](glosario.md#vps)) te da control total, pero también te hace responsable de su seguridad; antes de comprar uno, comprueba si te basta con algo más sencillo.

Un VPS es como alquilar un piso vacío: puedes poner lo que quieras, pero la cerradura, el mantenimiento y las averías son cosa tuya. Un hosting gestionado es como un hotel: tienes menos libertad, pero alguien se ocupa del edificio.

## Antes de empezar

Ten a mano qué hace tu app y con qué la construiste (Lovable, Bolt, Replit, v0, Cursor, Claude Code...). No necesitas saber nada técnico para esta guía.

## Pasos

### 1. Responde a estas preguntas

| Pregunta | Si respondes "sí"... |
| --- | --- |
| ¿Tu app es una web o una app sin nada que funcione en segundo plano? | Probablemente **no** necesitas un VPS. |
| ¿La plataforma con la que la hiciste ya la publica por ti (por ejemplo Lovable o Replit)? | Probablemente **no** necesitas un VPS, al menos de momento. |
| ¿Tu app necesita algo encendido las 24 horas: un bot, tareas programadas, colas, conexiones en tiempo real? | Un VPS empieza a tener sentido. |
| ¿Quieres tener varias apps, bases de datos o herramientas en el mismo sitio y pagar una cantidad fija? | Un VPS empieza a tener sentido. |
| ¿Estás dispuesto a dedicar una hora al principio y unos 15 minutos al mes a mantenerlo? | Necesario si eliges VPS. |

### 2. Mira tu resultado

**Si casi todo fue "no":** usa un hosting gestionado. Para webs y apps de Node.js (Next.js, Astro, React...) hay opciones gestionadas en muchos proveedores, incluido Hostinger, y en plataformas como Vercel o Netlify. No tendrás que preocuparte de nada de lo que explica este repositorio.

**Si respondiste "sí" a las preguntas 3 o 4 y también a la 5:** un VPS es buena opción. Sigue con la [guía 01](01-conectar-al-servidor.md).

**Si dudas:** empieza con un hosting gestionado. Pasar a un VPS más adelante es fácil; quitarte la responsabilidad de un VPS que no necesitabas, no tanto.

### 3. Si eliges VPS, qué pedir

- **Sistema:** Ubuntu 24.04. Es la versión para la que están escritas y probadas estas guías.
- **Memoria:** 4 GB funcionan, pero van justos si construyes tu app en el propio servidor. La [guía 02](02-proteger-el-servidor.md) añade un colchón de memoria (swap) para evitar sustos.
- **Plantilla:** Ubuntu 24.04 a secas, o con Docker o Coolify si ya sabes que los vas a usar. Las guías 00 a 03 valen para cualquiera de las tres.

## Cómo saber que ha ido bien

Tienes clara una de estas dos respuestas: "me basta un hosting gestionado" o "necesito un VPS y voy a dedicarle el tiempo de mantenimiento".

## Si algo falla

Si no sabes responder a las preguntas, pregunta a tu agente de IA: "¿mi app necesita algo funcionando en segundo plano?". Si tampoco lo tiene claro, empieza con un hosting gestionado.

## Cómo deshacerlo

Esta guía no cambia nada. Lo que sí conviene saber: este repositorio no cubre copias de seguridad ni bases de datos. Si guardas datos importantes en un VPS, necesitarás resolver eso aparte.

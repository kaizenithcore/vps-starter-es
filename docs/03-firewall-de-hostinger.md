---
id: 03-firewall-de-hostinger
objetivo: Activar el firewall de Hostinger dejando abiertos solo los puertos que necesitas
riesgo: alto
requiere_confirmacion_humana: true
tiempo_estimado: 15 min
requisitos: [01-conectar-al-servidor]
verificacion: "desde tu ordenador: ssh root@IP_DE_TU_SERVIDOR true; y scripts/check.sh --section puertos"
reversion: "#cómo-deshacerlo"
---

# El firewall de Hostinger: qué abrir y qué no

**En una frase:** vas a poner un portero en la entrada de tu servidor que solo deja pasar a quien va a una puerta concreta (SSH, tu web) y deja fuera todo lo demás.

Un [firewall](glosario.md#firewall) es el portero del edificio. Cada servicio de tu servidor escucha en una puerta numerada, un [puerto](glosario.md#puerto): SSH en la 22, la web en la 80 y la 443. El portero tiene una lista de puertas permitidas y no deja pasar a nadie más.

**Por qué el de Hostinger y no uno dentro del servidor:** Ubuntu trae su propio firewall (`ufw`), pero [Docker](glosario.md#docker) abre puertos saltándose sus reglas. Puedes tener `ufw` "bloqueando" un puerto y que ese puerto siga abierto a Internet. El firewall de Hostinger está fuera del servidor, antes de llegar a él, y Docker no puede saltárselo. Esta parte es específica de Hostinger; si usas otro proveedor, busca su "firewall de red" o "grupo de seguridad".

**Lo más importante de esta guía:** cuando el firewall de Hostinger está activo, **bloquea todo lo que no esté permitido**. Si lo activas con una regla equivocada, te quedas fuera. Ya ha pasado: un firewall activado con una única regla para otro puerto dejó el servidor sin SSH ni web.

## Antes de empezar

- Entras al servidor por SSH desde tu ordenador ([guía 01](01-conectar-al-servidor.md)).
- Tienes acceso a hPanel. Desde hPanel siempre podrás desactivar el firewall, aunque no puedas entrar al servidor.

## Pasos

### 1. Mira qué puertos escucha tu servidor

Dentro del servidor:

```bash
cd ~/vps-starter-es && sudo scripts/check.sh --section docker,puertos
```

Deberías ver algo así:

```text
Puertos abiertos
[OK]     Solo escuchan hacia Internet los puertos esperados: 22, 80, 443.
```

Si ves avisos de otros puertos, apúntalos: la tabla del paso 2 te dice qué hacer con cada uno. Si `check.sh` dice `Coolify detectado`, también necesitarás los puertos de Coolify.

### 2. Decide qué puertas abrir

| Puerto | Para qué | ¿Abrir? |
| --- | --- | --- |
| 22 (TCP) | SSH, para entrar al servidor | **Sí, siempre.** Sin él te quedas fuera |
| 80 (TCP) | Web normal ([HTTP](glosario.md#http-y-https)) | Sí, si tienes una web o app |
| 443 (TCP) | Web segura ([HTTPS](glosario.md#http-y-https)) | Sí, si tienes una web o app |
| 8000 (TCP) | Panel de Coolify | Solo si usas Coolify |
| 6001 (TCP) | Tiempo real de Coolify | Solo si usas Coolify |
| 6002 (TCP) | Terminal de Coolify | Solo si usas Coolify |
| 8080 (TCP) | Panel interno del proxy de Coolify | **No.** Queda abierto por defecto y no hace falta |
| 3001 (TCP) | Uptime Kuma | Solo para tu IP ([guía 04](04-vigilar-tu-servidor.md)) |
| 5432, 3306, 6379, 27017 | Bases de datos | **No.** Tus apps llegan a ellas desde dentro |

Si usas una VPN o una red privada (por ejemplo Tailscale), puede que ya tengas una regla para su puerto. Consérvala.

### 3. Crea el grupo de reglas

En hPanel:

1. Entra en **VPS**, elige tu servidor y abre **Seguridad** → **Firewall**.
2. Pulsa **Añadir firewall**, ponle un nombre (por ejemplo `vps-starter`) y pulsa **Crear**.
3. Junto al grupo nuevo, pulsa los tres puntos (**⋯**) → **Editar**.
4. Añade una regla por cada puerto que decidiste abrir. Para cada una:
   - **Acción:** Aceptar.
   - **Protocolo:** SSH, HTTP o HTTPS para 22, 80 y 443. Para los demás, TCP y el número de puerto.
   - **Origen:** Cualquiera (*Anywhere*). Para el 3001, personalizado con tu IP.

Los nombres exactos de los botones pueden cambiar un poco; la idea es la misma.

### 4. Repasa la lista antes de activar

Mira la lista de reglas del grupo y comprueba, una por una:

- [ ] Hay una regla **Aceptar** para el **22**.
- [ ] Hay reglas **Aceptar** para el **80** y el **443** (si tienes web).
- [ ] Si usas Coolify: **8000**, **6001** y **6002**.
- [ ] **No** hay ninguna regla para el **8080**.

> **ALTO: necesita confirmación humana.** Se va a activar el firewall. Todo lo que no esté en la lista quedará bloqueado. Si falta la regla del 22, perderás el acceso por SSH hasta que lo desactives desde hPanel.

### 5. Activa el firewall

En la sección **Firewall** de tu servidor, activa el grupo que has creado. Si hPanel muestra un botón para sincronizar, púlsalo.

Los cambios tardan hasta dos minutos. Las conexiones que ya tienes abiertas no se cortan, así que **la prueba hay que hacerla con una conexión nueva**.

### 6. Prueba desde fuera

Espera dos minutos y, desde **tu ordenador**, abre una conexión nueva:

```bash
ssh root@IP_DE_TU_SERVIDOR true && echo "SSH sigue abierto"
```

Deberías ver `SSH sigue abierto`.

Abre tu web en el navegador y comprueba que carga. Si usas Coolify, abre su panel.

Comprueba que el 8080 está cerrado. En Windows (PowerShell):

```powershell
Test-NetConnection IP_DE_TU_SERVIDOR -Port 8080
```

Deberías ver `TcpTestSucceeded : False`.

En macOS o Linux:

```bash
nc -zv -w 5 IP_DE_TU_SERVIDOR 8080
```

Deberías ver que falla (`timed out` o `Connection refused`).

## Cómo saber que ha ido bien

- Entras por SSH con una conexión nueva.
- Tu web carga.
- El 8080 (y cualquier puerto que no abriste) no responde desde fuera.

`check.sh` seguirá mostrando un `[AVISO]` sobre el firewall de Hostinger: desde dentro del servidor no se puede ver si está activo. Es normal.

## Si algo falla

| Lo que ves | Qué significa | Qué hacer |
| --- | --- | --- |
| `Connection timed out` al entrar por SSH | Falta la regla del 22 o está mal | Desactiva el firewall en hPanel, espera dos minutos, corrige la regla y vuelve a activarlo |
| Tu web no carga | Faltan las reglas del 80 o del 443 | Añádelas al grupo; no hace falta desactivar el firewall |
| El panel de Coolify no carga | Faltan 8000, 6001 o 6002, o Coolify está parado | Revisa las reglas y después [problemas comunes](99-problemas-comunes.md#el-panel-de-coolify-no-carga) |
| El 8080 sigue respondiendo | Hay una regla que lo permite, o el firewall no está activo | Revisa la lista de reglas y que el grupo esté activado en tu servidor |

## Cómo deshacerlo

En hPanel, en la sección **Firewall** de tu servidor, desactiva el grupo. En unos dos minutos todo vuelve a estar abierto como antes. Puedes hacerlo aunque no puedas entrar al servidor.

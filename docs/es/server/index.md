# Tu propio servidor: resumen

Cada familia tiene **su propio servidor**. La app solo se comunica con él. No alojamos las citas, tareas ni compras de otras familias.

Estas páginas son para quien instala el servidor. Supabase se configura en el navegador. Un servidor alquilado requiere un dominio y una conexión SSH para leer el resultado. En casa hace falta manejar SSH y Docker.

::: warning Estado en octubre de 2026
La instalación, la elección de servidor, las invitaciones y la demostración sin servidor están desarrolladas. La publicación en tiendas, las notificaciones push y las validaciones de lanzamiento siguen siendo pasos separados. Hasta llegar al App Store y Google Play, usa la app web.
:::

## Un servidor, una familia {#one-server-one-family}

Un servidor pertenece a **un solo hogar**. Una vez creado, no admite una segunda familia. Para amigos hace falta otro servidor o proyecto de Supabase.

## Tres opciones {#two-ways}

| | [En Supabase](/es/server/supabase-cloud) | [Alquilado](/es/server/rented-server) | [En casa](/es/server/home-server) |
|---|---|---|---|
| Requisitos | Cuentas de Supabase y GitHub, sin máquina | Cuenta en un proveedor europeo como Hetzner y dominio | NAS o miniPC con Docker y dominio |
| Instalación | Navegador | Un archivo pegado al crear el servidor y dos registros DNS | Herramienta de terminal, DNS y red |
| Datos | Centro de datos elegido en Supabase Inc. (EE. UU.) | Proveedor europeo de tu elección, en tu propio servidor | Máquina bajo tu control |
| Costes | Según la oferta vigente de Supabase | Unos 6–25 € al mes, más el dominio | Equipo, electricidad y dominio |
| Mantenimiento | Supabase mantiene su plataforma; tú actualizas WuselWall | Tú, un comando SSH por actualización; el sistema se actualiza solo | Tú gestionas actualizaciones y copias |

Los precios son cifras orientativas a octubre de 2026, no ofertas; cuenta la lista de precios vigente del proveedor. WuselWall es independiente y no está vinculado a Supabase, GitHub, Hetzner ni a los demás proveedores citados en estas páginas.

Un NAS con Docker puede servir. Para datos en Europa bajo tu control sin máquina en casa, alquila un servidor en Hetzner o un proveedor comparable. Si no, Supabase evita mantener una máquina. Revisa condiciones y precios antes de elegir. Es posible [trasladarse después](/es/server/restore).

## Lo necesario {#what-you-need-and-what-you-dont}

- **Supabase**, alojado o en Docker: base de datos, acceso, cambios en directo y funciones.
- **HTTPS**, integrado en Supabase o gestionado por Caddy en casa.
- **Tareas programadas**: preparar los próximos 14 días de tareas, cerrar el día anterior, actualizar festivos y calendarios externos y realizar la purga. La instalación las programa.
- **Copias de seguridad**: la base contiene tus datos irreemplazables.

Opcional: el **correo**. Sin él, todos inician sesión con dirección y contraseña; con él (basta una cuenta de Gmail), los códigos llegan por correo ([Correo](/es/server/email)).

## Lo opcional

La app web viene con el servidor en casa o se publica mediante el workflow de GitHub. Los festivos requieren que el servidor alcance OpenHolidays. Los calendarios externos solo se consultan si te suscribes. Compartir el calendario con Outlook o iPhone requiere acceso desde Internet.

Las claves de acceso no están disponibles para todas las instalaciones; siguen el código por correo y la contraseña. Consulta [Opciones](/es/server/extras) para copias externas y vigilancia. WuselWall no necesita cuentas de Google, Apple, Firebase, analítica ni captcha para funcionar.

## Después {#what-comes-next}

Abre la app, introduce la dirección o el identificador del proyecto y crea la familia con el código de configuración. La [guía de conexión](/es/guide/setup) explica invitaciones y otros dispositivos; sus QR también incluyen el servidor.

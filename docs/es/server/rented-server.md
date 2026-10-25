# Servidor alquilado (Hetzner y otros)

El camino intermedio entre Supabase y la máquina en casa: alquilas un pequeño servidor Linux a un proveedor europeo y WuselWall se instala solo en el primer arranque. No necesitas una máquina encendida en casa, ni abrir puertos en el router, ni cuentas en GitHub o Supabase. Los datos están en el proveedor europeo que elijas, en un servidor que es solo tuyo.

Técnicamente es la misma pila Docker que [en casa](/es/server/home-server). Todo lo de esa página (conectar la app, copias, actualizaciones, idioma de los correos, comandos) vale también aquí. Esta página solo describe la puesta en marcha.

## Preparativos {#what-you-need}

- Una cuenta en un proveedor con **cloud-init** (selección abajo); unos **4–8 € al mes**.
- Un **dominio** con dos nombres, `api.` y `web.`, unos 1–2 € al mes.
- Una **clave SSH** en tu ordenador (`ssh-keygen` si aún no tienes).
- Un **proveedor de correo** para los códigos de acceso, como en todo servidor WuselWall ([Opciones](/es/server/extras#email)).

## Proveedores {#providers}

Todos son empresas europeas con centros de datos en Europa y un acuerdo de tratamiento RGPD en su documentación contractual. Precios y disponibilidad cambian; compruébalos en el proveedor. WuselWall necesita **2 vCPU y 4 GB de memoria**, 8 GB con [reconocimiento de texto](/es/server/extras#text-recognition).

| Proveedor | Sede, centros de datos | Tamaño adecuado | Nota |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Alemania; Falkenstein, Núremberg, Helsinki | 2 vCPU, 4 GB, desde unos 4–6 €, más 0,50 € por una dirección IPv4 | La guía de abajo. Los tamaños baratos se agotan a veces |
| [netcup](https://www.netcup.com/) | Alemania; Núremberg, Viena | VPS de 4 GB, unos 4–6 € | Barato; atención a la permanencia |
| [IONOS](https://www.ionos.es/) | Alemania | VPS de 4 GB, unos 5–8 € | |
| [Scaleway](https://www.scaleway.com/) | Francia; París, Ámsterdam, Varsovia | DEV1-M o similar, unos 8 € | Práctico si tu correo ya va por Scaleway |
| [OVHcloud](https://www.ovhcloud.com/) | Francia; Gravelines, Estrasburgo y otros | VPS de 4 GB, unos 5–7 € | |
| [Infomaniak](https://www.infomaniak.com/) | Suiza; Ginebra | VPS o Public Cloud de 4 GB, unos 6–10 € | Ley suiza de protección de datos |

**¿Dónde están los datos?** En tu propio servidor en el proveedor. Él aporta hardware, electricidad y red y ve la conexión cifrada, no su contenido; solo WuselWall lee tu base de datos. A diferencia de Supabase, el proveedor es europeo y solo rige el derecho europeo.

## En Hetzner, paso a paso {#hetzner-step-by-step}

1. **Preparar el archivo.** Abre [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) en GitHub, copia su contenido en un editor de texto y cambia la única línea marcada `CHANGE`: la versión de [Releases](https://github.com/wuselwall/wuselwall-app/releases), tus dos direcciones y el idioma de los correos (`de`, `en`, `fr` o `es`).
2. **Proyecto y clave.** En la [consola de Hetzner Cloud](https://console.hetzner.cloud/), crea un proyecto, por ejemplo «WuselWall», y añade tu clave SSH pública en **Security → SSH keys**.
3. **Crear el servidor.** **Add server**: ubicación Falkenstein, Núremberg o Helsinki; imagen **Ubuntu 24.04**; tipo compartido con **4 GB**; red IPv4 e IPv6; tu clave SSH; el cortafuegos de Hetzner es opcional, el archivo configura uno en el servidor; abajo, pega el contenido preparado en **Cloud config**. Llámalo `wuselwall` y pulsa **Create & Buy now**.
4. **DNS.** La consola muestra enseguida la dirección IPv4. En tu registrador, crea dos registros A, `api` y `web`, hacia esa dirección (y AAAA con la IPv6 si quieres). Caddy reintenta hasta que los nombres respondan.
5. **Leer el resultado.** Tras 5–10 minutos:

   ```bash
   ssh root@<ip> cat /srv/wuselwall/install.log
   ```

   Ahí están la dirección del servidor, el enlace de configuración con su QR y el código de un solo uso. Guarda enseguida `/srv/wuselwall/stack/.env` en tu gestor de contraseñas ([por qué](/es/server/home-server#_1-installing)).
6. **Seguir como en casa:** [conectar la app](/es/server/home-server#_2-connecting-the-app), configurar la [copia de seguridad](/es/server/home-server#_3-backups) y, desde el principio, una [copia fuera de casa](/es/server/extras#off-site-backup), porque un servidor alquilado tiene un solo disco. Las copias de Hetzner (un 20 % más) guardan todo el disco: buen complemento, no un sustituto.

En otros proveedores el campo se llama **User data**, **Cloud-init** o **Script de inicio**; los pasos son los mismos.

## En el día a día {#day-to-day}

Los comandos se ejecutan por SSH en `/srv/wuselwall`, como [en casa](/es/server/home-server#useful-commands):

| | Comando |
|---|---|
| Actualizar | `./wuselwall update 1.1.0` |
| Copia ahora | `./wuselwall backup` |
| ¿Funciona todo? | `./wuselwall status` |

Ubuntu instala solo las actualizaciones de seguridad. Tras una actualización del núcleo, reinicia una vez (`reboot`); la pila vuelve por sí sola.

## Traslado {#moving}

Del servidor alquilado a casa o al revés: copia de seguridad, instalación en el nuevo sitio con el antiguo `stack/.env` y restauración ([Restaurar una copia](/es/server/restore)). Si las direcciones no cambian, los dispositivos siguen conectados.

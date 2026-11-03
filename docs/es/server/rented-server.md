# Servidor alquilado (Hetzner y otros)

El camino intermedio entre Supabase y la máquina en casa: alquilas un pequeño servidor Linux a un proveedor europeo y WuselWall se instala solo en el primer arranque. No necesitas una máquina encendida en casa, ni abrir puertos en el router, ni cuentas en GitHub o Supabase. Los datos están en el proveedor europeo que elijas, en un servidor que es solo tuyo.

Técnicamente es la misma pila Docker que [en casa](/es/server/home-server). Todo lo de esa página (conectar la app, copias, actualizaciones, idioma de los correos, comandos) vale también aquí. Esta página solo describe la puesta en marcha.

## Preparativos {#what-you-need}

- Una cuenta en un proveedor con **cloud-init** (selección abajo); unos **6–25 € al mes** (a octubre de 2026).
- Un **dominio** con dos nombres, `api.` y `web.`, unos 1–2 € al mes.
- Una **clave SSH** en tu ordenador (`ssh-keygen` si aún no tienes).
- Opcional: una **cuenta de correo** para los códigos de acceso; basta una de Gmail ([Correo](/es/server/email)). Sin ella, todos inician sesión con contraseña.

## Proveedores {#providers}

Los tres de la tabla son empresas europeas con centros de datos en Europa; cada una ofrece un acuerdo de tratamiento RGPD y, al crear un servidor, un campo para el archivo cloud-init. WuselWall necesita **2 vCPU y 4 GB de memoria**, 8 GB con [reconocimiento de texto](/es/server/extras#text-recognition).

::: info Independiente, precios orientativos
WuselWall no está vinculado a ninguna de las empresas citadas en esta página, no recibe patrocinio ni aval de ellas y no obtiene nada por nombrarlas; los enlaces son enlaces normales, no de afiliados. La lista es una selección sin orden particular: no es un ranking ni está completa. El rango de precios es una cifra aproximada y orientativa, a octubre de 2026, y no una oferta; los precios cambian y, según el proveedor, se muestran con o sin IVA. Solo cuentan la lista de precios y las condiciones del proveedor. Los nombres de productos y empresas son marcas de sus titulares.
:::

| Proveedor | Sede, centros de datos | Tamaño adecuado | Campo para el archivo |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Alemania; Falkenstein, Núremberg, Helsinki | CX23 (2 vCPU, 4 GB); si está agotado, CPX22 | **Cloud config**; la guía de abajo |
| [Scaleway](https://www.scaleway.com/) | Francia; París, Ámsterdam, Varsovia | DEV1-M (3 vCPU, 4 GB), IPv4 pública aparte | **Cloud-init**; práctico si tu correo ya va por Scaleway |
| [IONOS](https://www.ionos.es/) | Alemania; elige un centro de datos en la UE | Cloud Server de 4 GB | **Cloud-Init User Data** en las opciones avanzadas; documentado para el Cloud Server, no para el VPS |

**Coste:** unos **6–25 € al mes** por un servidor adecuado, según proveedor, tamaño e IVA, más el dominio (a octubre de 2026). Los tamaños más baratos se agotan a veces (en Hetzner, toda la gama más barata el 25 de octubre de 2026); el siguiente tamaño cuesta unas tres veces más. Cuenta la lista de precios del proveedor.

**Sin campo cloud-init:** [netcup](https://www.netcup.com/), [OVHcloud](https://www.ovhcloud.com/) e [Infomaniak](https://www.infomaniak.com/) (Suiza, Ginebra; ley suiza de protección de datos) también alquilan servidores adecuados en Europa, pero no documentan ese campo. Allí creas un servidor con Ubuntu e instalas por SSH igual que [en casa](/es/server/home-server), tras comprobar la descarga como en [Comprobar una descarga](#checking-a-download).

**¿Dónde están los datos?** En tu propio servidor en el proveedor. Él aporta hardware, electricidad y red; como cualquier proveedor, técnicamente podría acceder a la máquina, y su acuerdo de tratamiento le prohíbe usar tus datos. Las conexiones con tus dispositivos van cifradas, y solo WuselWall lee tu base de datos. A diferencia de Supabase Inc. (EE. UU.), el proveedor es una empresa europea sujeta al derecho europeo; Infomaniak, al suizo.

## En Hetzner, paso a paso {#hetzner-step-by-step}

La guía usa Hetzner porque su consola tiene un campo sencillo para cloud-config; no es una recomendación frente a los demás. Pantallas y nombres de botones: a octubre de 2026, pueden cambiar.

1. **Preparar el archivo.** Abre [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) en GitHub, copia su contenido en un editor de texto y cambia la única línea marcada `CHANGE`: la versión de [Releases](https://github.com/wuselwall/wuselwall-app/releases), tus dos direcciones y el idioma de los correos (`de`, `en`, `fr` o `es`).
2. **Proyecto y clave.** En la [consola de Hetzner Cloud](https://console.hetzner.cloud/), crea un proyecto, por ejemplo «WuselWall», y añade tu clave SSH pública en **Security → SSH keys**.
3. **Crear el servidor.** **Add server**: ubicación Falkenstein, Núremberg o Helsinki; imagen **Ubuntu 24.04**; tipo **CX23** (2 vCPU, 4 GB) en Cost-Optimized, o **CPX22** en Regular Performance si está agotado; red IPv4 e IPv6; tu clave SSH; el cortafuegos de Hetzner es opcional, el archivo configura uno en el servidor; abajo, pega el contenido preparado en **Cloud config**. Llámalo `wuselwall` y pulsa **Create & Buy now**.
4. **DNS.** La consola muestra enseguida la dirección IPv4. En tu registrador, crea dos registros A, `api` y `web`, hacia esa dirección (y AAAA con la IPv6 si quieres). Caddy reintenta hasta que los nombres respondan.
5. **Leer el resultado.** Tras 5–10 minutos:

   ```bash
   ssh root@<ip> cat /srv/wuselwall/install.log
   ```

   Ahí están la dirección del servidor, el enlace de configuración con su QR y la clave de configuración de un solo uso. Guarda enseguida `/srv/wuselwall/stack/.env` en tu gestor de contraseñas ([por qué](/es/server/home-server#_1-installing)). La primera línea indica si la firma y la suma de comprobación de la versión coincidían. Si el archivo no existe, el servidor no pudo descargar la versión o la rechazó por alterada; `ssh root@<ip> tail -n 30 /var/log/cloud-init-output.log` muestra el motivo.
6. **Seguir como en casa:** [conectar la app](/es/server/home-server#_2-connecting-the-app), configurar la [copia de seguridad](/es/server/home-server#_3-backups) y, desde el principio, una [copia fuera de casa](/es/server/extras#off-site-backup), porque un servidor alquilado tiene un solo disco. Las copias de Hetzner (un 20 % más) guardan todo el disco: buen complemento, no un sustituto.

En otros proveedores el campo se llama **User data**, **Cloud-init** o **Script de inicio**; los pasos son los mismos.

## En el día a día {#day-to-day}

Los comandos se ejecutan por SSH en `/srv/wuselwall`, como [en casa](/es/server/home-server#useful-commands):

| | Comando |
|---|---|
| Actualizar | `./wuselwall update 1.1.0` |
| Copia ahora | `./wuselwall backup` |
| ¿Funciona todo? | `./wuselwall status` |

Antes de actualizar, `wuselwall` comprueba la firma y la suma de comprobación de la nueva versión y solo después ejecuta algo de ella. Para comprobar sin instalar: `./wuselwall verify 1.1.0`.

Ubuntu instala solo las actualizaciones de seguridad. Tras una actualización del núcleo, reinicia una vez (`reboot`); la pila vuelve por sí sola.

## Comprobar una descarga {#checking-a-download}

Cada versión del servidor está firmada. Junto al archivo están `SHA256SUMS`, la suma de comprobación del archivo, y `SHA256SUMS.minisig`, la firma de esa lista con la clave de WuselWall. El archivo cloud-init y `./wuselwall update` comprueban ambos por sí mismos. Si descargas una versión a mano, para un servidor sin campo cloud-init o en casa, compruébala antes de descomprimirla (ajusta la versión):

```bash
v=1.0.0
for f in wuselwall-server-$v.tar.gz SHA256SUMS SHA256SUMS.minisig; do
  curl -fsSLO "https://github.com/wuselwall/wuselwall-app/releases/download/server-v$v/$f"
done
minisign -Vm SHA256SUMS -P RWQkSenBTFOIn4wZCJQTUyXTgTwX8mO+WCK3WOn9W52Yer+3h7Bpmyp/
sha256sum -c --ignore-missing SHA256SUMS
tar xzf wuselwall-server-$v.tar.gz
```

`minisign` debe indicar «Signature and comment signature verified» y, como «Trusted comment», exactamente `wuselwall-server 1.0.0 SHA256SUMS` con tu versión; `sha256sum` indica `OK` para el archivo. Si no, no descomprimas nada y avísalo en [GitHub](https://github.com/wuselwall/wuselwall-app/issues). `minisign` se instala con `apt install minisign` (Debian, Ubuntu), `apk add minisign` (Alpine) o `brew install minisign` (Mac). La clave tras `-P` es la misma que está en `server/wuselwall` y `server/cloud-init.yaml`.

Con la CLI de GitHub también puedes comprobar que GitHub construyó el archivo desde este repositorio: `gh attestation verify wuselwall-server-$v.tar.gz --repo wuselwall/wuselwall-app`.

## Traslado {#moving}

Del servidor alquilado a casa o al revés: copia de seguridad, instalación en el nuevo sitio con el antiguo `stack/.env` y restauración ([Restaurar una copia](/es/server/restore)). Si las direcciones no cambian, los dispositivos siguen conectados.

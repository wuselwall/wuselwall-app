# Instalar un servidor en casa

Una **versión de servidor** incluye la pila Docker de Supabase, WuselWall, la app web y la herramienta `wuselwall` para instalar, actualizar y hacer copias.

Los ejemplos usan `api.example.org` para la API y `web.example.org` para la app. Sustitúyelos por tus direcciones.

## Preparativos {#what-you-need}

- Una máquina Linux siempre encendida con **Docker y Docker Compose v2**, acceso SSH y permiso para ejecutar Docker.
- **4 GB de memoria** para WuselWall y **10 GB libres**. x86-64 está probado; ARM, incluido Raspberry Pi 5, aún no.
- Un dominio con nombres `api.` y `web.` hacia tu IP pública. Si cambia, usa DNS dinámico.
- Redirección de **TCP 80 y 443** hacia el servidor.

Sin puertos abiertos puedes usar un túnel Cloudflare, pero Cloudflare descifra el tráfico y puede verlo. Instala sin `--caddy` y usa los destinos del proxy descritos abajo. Un VPN como WireGuard o Tailscale mantiene privado el servidor, pero cada dispositivo debe usarlo y las suscripciones de calendario externas pueden no funcionar.

## 1. Instalar {#_1-installing}

Elige una versión en [Releases](https://github.com/wuselwall/wuselwall-app/releases). `1.0.0` es un ejemplo de número, no una versión garantizada. En el servidor:

```bash
v=1.0.0
for f in wuselwall-server-$v.tar.gz SHA256SUMS SHA256SUMS.minisig; do
  curl -fsSLO "https://github.com/wuselwall/wuselwall-app/releases/download/server-v$v/$f"
done
minisign -Vm SHA256SUMS -P RWQkSenBTFOIn4wZCJQTUyXTgTwX8mO+WCK3WOn9W52Yer+3h7Bpmyp/
sha256sum -c --ignore-missing SHA256SUMS
tar xzf wuselwall-server-$v.tar.gz
cd wuselwall
./wuselwall install --api https://api.example.org --web https://web.example.org --language es --caddy
```

Las dos comprobaciones (firma y suma de verificación) deben pasar antes de desempaquetar; qué deben mostrar y de dónde sale `minisign` está en [Comprobar una descarga](/es/server/rented-server#checking-a-download).

`--language` elige el idioma de los **correos** (`de`, `en`, `fr`, `es`, alemán por defecto), no el de la app. Docker descarga varios gigabytes. La herramienta genera las claves en `stack/.env`, arranca Caddy con certificados Let’s Encrypt, prepara base y tareas programadas y muestra un **enlace de configuración con QR**, con una clave de configuración de un solo uso. No hace falta Node.js ni otro servidor web.

El servidor arranca **sin correo**: todos inician sesión con dirección y contraseña. `./wuselwall mail smtp` añade los códigos por correo cuando quieras ([Correo](/es/server/email)).

::: danger Conserva stack/.env enseguida
Guárdalo en el gestor de contraseñas. Contiene las claves para mantener conectados los dispositivos tras restaurar. **Nunca lo regeneres en un servidor existente.**
:::

Si aún no hay publicación, constrúyela en un ordenador con Git, rsync y Flutter:

```bash
git clone https://github.com/wuselwall/wuselwall-app.git && cd wuselwall-app
scripts/build-server-release.sh 0.1.0
scp dist/wuselwall-server-0.1.0.tar.gz server:
```

Descomprime después en el servidor. `--skip-web` construye sin Flutter y sin incluir app web.

## Servidor alquilado {#vps}

Si alquilas el servidor a un proveedor como Hetzner, un archivo **cloud-init** lo instala en el primer arranque, sin SSH para la instalación. Lo explica la página [Servidor alquilado](/es/server/rented-server). Todo lo demás de esta página vale también allí.

## 2. Conectar la app {#_2-connecting-the-app}

La app web lee la configuración de la instalación al cargar, aunque el navegador recuerde otra dirección. Sin conexión usa la última. Si cambia la dirección, inicia sesión otra vez.

Abre el enlace de configuración o escanea su QR. Incluye el servidor y la clave de configuración y abre **Configurar tu servidor**: allí introduces la dirección de correo de la primera cuenta, y el servidor solo deja iniciar sesión a esa dirección ([La clave de configuración](/es/guide/setup#setup-key)). **Nueva familia** ya no pide ninguna clave.

También puedes escribir `api.example.org`: la pantalla de inicio dice que el servidor aún no tiene familia; toca **Tengo la clave de configuración** e introduce la clave junto a tu dirección. Un QR antiguo con solo la dirección tampoco lleva la clave. `./wuselwall setup-token` genera otra mientras no exista familia. No publiques ni la clave ni el enlace: hasta que exista la familia, solo quien la tiene puede crear una cuenta en el servidor.

## 3. Copias de seguridad {#_3-backups}

Añade al crontab o planificador del NAS:

```txt
30 3 * * * BACKUP_DIR=/srv/backups/wuselwall /path/to/wuselwall/wuselwall backup nightly
```

La herramienta comprueba las copias y conserva 14 días. Sin `BACKUP_DIR` van a `backups/` junto a ella. Usa preferentemente otro disco y una [copia externa](/es/server/extras#off-site-backup). Prueba la [restauración](/es/server/restore).

## Idioma de los correos {#email-language}

```bash
./wuselwall language es
```

Se admiten los cuatro idiomas. Cambia `MAIL_LANGUAGE`, asuntos y plantillas, y reinicia solo autenticación y funciones. Conserva claves y preferencia en futuras actualizaciones. Las instalaciones antiguas sin valor usan alemán. Desde una copia del repositorio, utiliza `scripts/remote-stack.sh language es` tras desplegar.

## Actualizar {#updates}

```bash
./wuselwall update 1.1.0
```

Se hace una copia antes de descargar y aplicar la versión, con base, app web y tareas programadas. Si usabas acceso Apple o Google, consulta antes la [migración](/es/server/extras#retiring-social-sign-in). Un servidor instalado sin proveedor de correo antes de que el correo fuera opcional aún no puede registrar a nadie: la actualización lo indica; ejecuta entonces una vez `./wuselwall mail off`.

### Qué app va con qué servidor {#compatibilidad}

La app comprueba por sí misma, al conectarse, si va con tu servidor, y te avisa cuando la app o el servidor necesitan una actualización. Cada app entiende la API de su servidor y la anterior; el servidor indica además la app más antigua con la que todavía funciona. Lo que está en marcha se ve en la app en **Ajustes → Versiones**, por ejemplo «App 1.1.0 · Servidor 0.3.0 · API 1». A partir del servidor 0.3.0, el servidor indica ahí su versión; la app solo ofrece el reconocimiento de texto si el servidor lo tiene instalado.

<CompatTable />

::: warning Actualizaciones coordinadas
No uses Watchtower ni actualizaciones automáticas de contenedores del NAS para esta pila. Usa `wuselwall update` para mantener versiones compatibles.
:::

## Comandos útiles {#useful-commands}

| Comando | Función |
|---|---|
| `./wuselwall status` | Estado de servicios |
| `./wuselwall logs auth` | Registros de `auth`; también `db`, `rest`, `realtime`, `functions`, `caddy` |
| `./wuselwall backup` | Copia inmediata |
| `./wuselwall setup-token` | Nueva clave de configuración antes de crear el hogar |
| `./wuselwall mail` | Correo activado (`mail smtp`), desactivado (`mail off`) o probado (`mail test`) ([Correo](/es/server/email)) |
| `./wuselwall password <dirección>` | Código de un solo uso para elegir una contraseña nueva ([Correo](/es/server/email#forgotten-password)) |
| `./wuselwall compose …` | Comando Docker Compose de la pila |

Studio está desactivado. Con `--studio`, accede por túnel SSH: `ssh -L 54421:172.17.0.1:54421 server`, después `http://127.0.0.1:54421`. Los datos están en `DASHBOARD_USERNAME` y `DASHBOARD_PASSWORD` de `stack/.env`.

## Tu proxy en lugar de Caddy {#your-own-web-server-instead-of-caddy}

Instala sin `--caddy` si ya tienes nginx, Traefik u otro proxy. La pila escucha entonces solo en `172.17.0.1:54421`, la dirección de Docker, a la que solo llega el propio servidor.

- Para la API, reenvía `/auth/v1/`, `/rest/v1/`, `/realtime/v1/` con WebSockets y `/functions/v1/` a `http://172.17.0.1:54421`. Reenvía `/.well-known/wuselwall.json` a `/functions/v1/server-info` de ese destino. Los demás caminos, incluido `/rest/v1/` sin continuación, devuelven 404.
- Para web, sirve `stack/volumes/web`, usa `index.html` para caminos desconocidos y reenvía el mismo archivo de descubrimiento.
- **`X-Forwarded-For` con la dirección que tu proxy vio por sí mismo** — en nginx `proxy_set_header X-Forwarded-For $remote_addr;`. El servidor cuenta con ella los intentos fallidos por dirección (clave de configuración, códigos, invitaciones). Si tu proxy pasa la cabecera sin cambios, un atacante elige su propia dirección. Detrás de un túnel Cloudflare usa `$http_cf_connecting_ip`.

`stack/volumes/caddy/Caddyfile` sirve de modelo. Para nginx, lo esencial es así, con un freno en los caminos que cualquiera puede llamar sin iniciar sesión (la imagen estándar de Caddy no tiene; el servidor también frena por dirección):

```nginx
# One bucket per address for the paths anyone may call without signing in: the pairing,
# invitation, password-reset and setup-key endpoints. 30 requests a minute is far more
# than a family needs and far less than a guesser wants.
limit_req_zone $binary_remote_addr zone=wuselwall_anon:1m rate=30r/m;
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

server {
    server_name api.example.org;
    # TLS as usual (certbot, acme.sh, ...)

    location ~ ^/rest/v1/rpc/(pairing_start|pairing_poll|invitation_preview|password_reset_redeem|setup_claim|enrol_device)$ {
        limit_req zone=wuselwall_anon burst=20 nodelay;
        proxy_pass http://172.17.0.1:54421;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location ~ ^/(auth|rest|realtime|functions)/v1/ {
        proxy_pass http://172.17.0.1:54421;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;        # Realtime (WebSockets)
        proxy_set_header Connection $connection_upgrade;
    }
    location = /rest/v1/ { return 404; }
    location = /.well-known/wuselwall.json {
        proxy_pass http://172.17.0.1:54421/functions/v1/server-info;
    }
    location / { return 404; }
}
```

Si el proxy está en otra máquina, deja la pila igualmente en `172.17.0.1`. Lo más sencillo: instala al final con `--caddy` y reenvía 80 y 443 del router al servidor; Caddy cifra, y tu otro proxy ya no hace falta para WuselWall. O abre un túnel SSH desde la máquina del proxy al servidor (`ssh -N -L 54421:172.17.0.1:54421 server`) y reenvía allí a `http://127.0.0.1:54421`. Poner `GATEWAY_BIND` en `stack/.env` en una dirección de la red doméstica también funciona, pero entonces **toda la pasarela queda sin cifrar en la red doméstica**: inicio de sesión, API de la base de datos, Realtime y funciones, y con `--studio` también Studio y `/pg/`. Hazlo solo con una regla de cortafuegos en el servidor que abra ese puerto únicamente a la dirección de tu proxy, y reinicia después con `./wuselwall compose up -d`.

# Opciones del servidor

Todo aquí es opcional, **excepto el envío de correo**, necesario por ahora. Ejecuta los comandos junto a `wuselwall` y añade solo los servicios que necesites.

## Correo electrónico {#email}

El primer acceso verifica la dirección con un **código de seis cifras**. Sin SMTP nadie puede crear ni unirse al hogar. El modo sin correo está previsto, aún no disponible.

La instalación elige un idioma único para **todos los asuntos y cuerpos**: `de`, `en`, `fr` o `es`, alemán por defecto. No depende del destinatario ni de su dispositivo. Cambia con `./wuselwall language es` ([Instalación](/es/server/home-server#email-language)).

Elige un servicio de correo transaccional y configura sus registros SPF, DKIM y DMARC. El proveedor recibe direcciones y códigos; revisa condiciones y precios.

**En casa**, define `SMTP_HOST`, `SMTP_PORT` (normalmente `587`), `SMTP_USER`, `SMTP_PASS` y `SMTP_ADMIN_EMAIL` en `stack/.env`, con comillas simples como los otros valores. Un servidor con correo usa `ENABLE_EMAIL_AUTOCONFIRM=false`.

```bash
./wuselwall compose up -d auth
```

**En Supabase**, introduce los mismos datos en **Authentication → Emails → SMTP Settings**. El correo integrado está pensado para pruebas y tiene límites.

La versión de servidor y el workflow configuran confirmación inicial y accesos posteriores con código, sin necesitar un hook de Scaleway. Si solo llega un enlace, actualiza servidor o workflow y pide un código nuevo. El mensaje antiguo no cambia.

## Antiguo acceso Apple y Google {#retiring-social-sign-in}

Esas cuentas pasan a código por correo en su dirección, sin cambiar cuenta ni familia.

**Comprueba antes de actualizar**: con «Ocultar mi correo» de Apple, la dirección termina en `privaterelay.appleid.com`. El remitente debe estar registrado para el reenvío. Si no llega el código, aplaza la actualización para no bloquear el próximo acceso.

En casa, `wuselwall update` retira valores Apple/Google, la antigua dirección de retorno y `apple-token`, mostrando solo los nombres. En Supabase, el workflow desactiva proveedores y vinculación, conserva las otras direcciones, retira función y secretos `APPLE_…` y comprueba el resultado. Se detiene si falla.

**Después**, prueba una cuenta antigua en un **segundo dispositivo** mediante correo, sin cerrar la primera sesión. Solo entonces:

- borra clientes OAuth de Google usados únicamente por WuselWall, nunca el proyecto Cloud, Play Console ni recursos de otras apps;
- elimina identificadores y claves de acceso Apple ya innecesarios, pero conserva remitentes de reenvío mientras existan cuentas con correo relay.

## Festivos y vacaciones {#holidays}

El servidor consulta [OpenHolidays](https://www.openholidaysapi.org/) cada semana para los países elegidos. Envía códigos de país, no miembros ni colegios; la app no lo contacta. Sin Internet pueden faltar estos datos, pero lo demás sigue funcionando.

## Copia fuera de casa {#off-site-backup}

Otro disco local no protege del robo o incendio. La herramienta puede enviar copias **cifradas** con [restic](https://restic.net/) a Backblaze B2 o S3. El proveedor solo ve datos cifrados.

Crea `backup.env` junto a la herramienta con `chmod 600 backup.env`:

```bash
RESTIC_REPOSITORY=b2:<bucket>:wuselwall
RESTIC_PASSWORD=<contraseña larga que también guardas en el gestor>
B2_ACCOUNT_ID=<identificador de clave>
B2_ACCOUNT_KEY=<clave de aplicación>
```

Inicializa una vez:

```bash
docker run --rm --env-file backup.env restic/restic:0.18.0 init
```

Las siguientes ejecuciones de `wuselwall backup`, incluidas las nocturnas, enviarán una copia. Guarda **RESTIC_PASSWORD** junto a `stack/.env` en el gestor: sin ella, las copias no sirven.

## Vigilancia {#monitoring}

Una alerta evita descubrir demasiado tarde que las copias dejaron de hacerse. Un control en [healthchecks.io](https://healthchecks.io/) recibe la confirmación de cada copia mediante `HEALTHCHECK_URL=https://hc-ping.com/…` en `backup.env` y avisa si falta.

Un monitor independiente puede consultar `https://api.example.org/.well-known/wuselwall.json`. Una respuesta comprueba pasarela, base y autenticación.

# Instalar un servidor en Supabase

El proyecto de [Supabase](https://supabase.com/) es **tuyo**: tu cuenta y datos, sin acceso nuestro. No necesitas máquina ni dominio. Supabase Inc. es una empresa estadounidense; elige la región de alojamiento al crear el proyecto, por ejemplo en Europa.

::: warning Validación incompleta
La instalación alojada aún no está completamente validada para WuselWall. Informa de errores en [GitHub](https://github.com/wuselwall/wuselwall-app/issues), sin incluir datos de la familia.
:::

## ¿Gratis o de pago? {#free-or-pro}

La oferta gratuita sirve para probar, pero puede pausar proyectos inactivos y no ofrece las mismas copias que un plan de pago. Comprueba límites, conservación y [precios vigentes](https://supabase.com/pricing) antes del uso diario; solo cuentan las condiciones de Supabase. WuselWall es independiente y no está vinculado a Supabase ni a GitHub. Un servidor pausado deja de servir a la pantalla de cocina.

## 1. Crear el proyecto {#_1-creating-the-project}

En el [panel](https://supabase.com/dashboard), crea un proyecto, elige región y guarda la contraseña de la base de datos en el gestor. El **identificador del proyecto**, visible en `https://<project-id>.supabase.co`, basta después para la app.

## 2. Instalar WuselWall {#_2-putting-wuselwall-onto-the-project}

1. Crea una cuenta GitHub y un **fork** de [wuselwall-app](https://github.com/wuselwall/wuselwall-app).
2. En las preferencias de Supabase, crea un **Access Token**.
3. En tu repositorio GitHub, **Settings → Secrets and variables → Actions**, añade:

   | Secreto | Valor |
   |---|---|
   | `SUPABASE_ACCESS_TOKEN` | Token de la cuenta Supabase |
   | `SUPABASE_PROJECT_ID` | Identificador del proyecto |
   | `SUPABASE_DB_PASSWORD` | Contraseña de la base |
   | `WUSELWALL_SETUP_TOKEN` | Frase de letras y cifras elegida para crear la familia una vez |
   | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SENDER` | Acceso SMTP de tu proveedor de correo (cinco secretos; `SMTP_SENDER` es la dirección remitente). Alternativa: Scaleway con `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `MAIL_FROM`. Ver [Correo](#mail) |

4. Activa los workflows en **Actions** y ejecuta **deploy-supabase → Run workflow**. Elige `es` en **language** para correos y marca **web** si quieres publicar la app web. La casilla **without mail** solo sirve para probar sin proveedor de correo.

El resumen da la dirección. Configura base, acceso, autenticación, funciones, plantillas de correo y tareas programadas, y después comprueba el servidor: respuesta a la app, acceso de las cuatro tareas a sus funciones, registro y correo configurados; si algo falla, se detiene e indica la causa. GitHub oculta los secretos en los registros; no los muestres tú. El token de Supabase es potente: puedes revocarlo después y crear otro para actualizar. El servidor solo guarda una huella del código de creación del hogar.

## Correo {#mail}

Cada inicio de sesión envía un código por correo, también el tuyo la primera vez. El envío integrado de Supabase solo entrega a las direcciones de tu propia cuenta de Supabase, unos pocos mensajes por hora. Por eso el servidor necesita un proveedor antes de que entre la familia:

- **SMTP:** un servicio de correo transaccional, preferiblemente europeo; sus accesos en los cinco secretos `SMTP_`. Consejos y registros DNS: [Opciones del servidor](/es/server/extras#email).
- **Scaleway:** como en casa, la función de WuselWall envía entonces mediante Scaleway Transactional Email. Secretos: `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `MAIL_FROM` (opcionales: `SCW_REGION`, `MAIL_FROM_NAME`).

Sin uno de los dos, el workflow se detiene. Solo para probar, marca **without mail**: los códigos llegan entonces solo a las direcciones de tu cuenta de Supabase. Añade los secretos y vuelve a ejecutar antes de que entren los demás.

## 3. Conectar la app {#_3-connecting-the-app}

En **¿Qué servidor?**, introduce el identificador y crea la familia con la frase `WUSELWALL_SETUP_TOKEN` ([Conexión](/es/guide/setup)).

<Shot name="setup-server" alt="La elección de servidor en la app" />

## 4. La app web {#_4-the-web-app}

Con **web** marcado, el workflow publica en `https://<your-github-name>.github.io/wuselwall-app/`. Configura una vez **Settings → Pages → Source → GitHub Actions**. En el primer inicio, elige el servidor.

GitHub recibe las visitas a la web; los datos familiares van directamente del navegador a Supabase. También puedes alojar la app web de una versión de servidor en tu propio espacio.

## Actualizaciones {#updates}

Haz **Sync fork → Update branch** y vuelve a ejecutar el workflow. **Haz una copia antes de migrar la base**. Supabase mantiene Postgres, HTTPS y su plataforma. Para antiguos accesos Apple o Google, consulta la [migración](/es/server/extras#retiring-social-sign-in).

## Copias de seguridad {#backups}

Usa **Database → Backups** según tu plan y comprueba la conservación. Mantén además una copia cifrada independiente; consulta [Restauración](/es/server/restore#at-supabase).

Para terminal, `.github/workflows/deploy-supabase.yml` detalla `supabase link`, `supabase db push`, las llamadas administrativas, secretos, funciones e `infra/jobs/schedule.sql`.

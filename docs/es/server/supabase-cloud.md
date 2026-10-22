# Instalar un servidor en Supabase

El proyecto de [Supabase](https://supabase.com/) es **tuyo**: tu cuenta y datos, sin acceso nuestro. No necesitas máquina ni dominio. Supabase Inc. es una empresa estadounidense; elige la región de alojamiento al crear el proyecto, por ejemplo en Europa.

::: warning Validación incompleta
La instalación alojada aún no está completamente validada para WuselWall. Informa de errores en [GitHub](https://github.com/wuselwall/wuselwall-app/issues), sin incluir datos de la familia.
:::

Este workflow necesita un runner Linux autohospedado accesible desde tu repositorio GitHub, con las etiquetas `self-hosted`, `Linux` y `build`. Crear un fork no da acceso a los runners del proyecto original.

## ¿Gratis o de pago? {#free-or-pro}

La oferta gratuita sirve para probar, pero puede pausar proyectos inactivos y no ofrece las mismas copias que un plan de pago. Comprueba límites, conservación y [precios vigentes](https://supabase.com/pricing) antes del uso diario. Un servidor pausado deja de servir a la pantalla de cocina.

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

4. Activa los workflows en **Actions** y ejecuta **deploy-supabase → Run workflow**. Elige `es` en **language** para correos y marca **web** si quieres publicar la app web.

El resumen da la dirección. Configura base, acceso, autenticación, funciones, plantillas de correo y tareas programadas. GitHub oculta los secretos en los registros; no los muestres tú. El token de Supabase es potente: puedes revocarlo después y crear otro para actualizar. El servidor solo guarda una huella del código de creación del hogar.

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

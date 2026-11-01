# Correo (opcional)

Un servidor WuselWall funciona **con o sin correo**. Sin él, cada persona crea su cuenta e inicia sesión con su dirección de correo y una contraseña. Con él, el servidor envía un **código de acceso de seis cifras** y nadie tiene que recordar una contraseña.

| | Sin correo | Con correo |
|---|---|---|
| **Crear cuenta** | Dirección y contraseña. La app se abre en **Cuenta nueva** | Un código por correo; la contraseña es opcional |
| **Contraseña olvidada** | Un responsable te da un código de un solo uso ([abajo](#forgotten-password)) | Un código por correo |
| **Invitaciones** | Por enlace, QR o código de invitación | Igual, y una invitación con tu dirección te encuentra sola |
| **Quién ve algo** | Nadie más | El proveedor ve direcciones y códigos |

Sin correo nadie comprueba la dirección. No es un problema: una cuenta sola no ve nada; solo una invitación o la clave de configuración la lleva a una familia, y antes de que exista la familia el servidor solo crea una cuenta para la dirección anunciada con la clave. Por lo mismo, un servidor sin correo nunca asigna una invitación a una cuenta porque coincidan las direcciones.

Puedes activar o desactivar el correo cuando quieras; las cuentas conservan su contraseña. La app nota el cambio en su próximo arranque.

## Configurar {#setup}

### Servidor en casa o alquilado

En la carpeta de la herramienta `wuselwall`:

```bash
./wuselwall mail smtp --gmail --user familia.garcia@gmail.com
```

La herramienta pide la contraseña, que no aparece en el comando ni en el historial. Para otro proveedor: `--host smtp.example.org --port 587` en lugar de `--gmail`. `--sender` fija otra dirección remitente y `--name` su nombre (por defecto WuselWall). La herramienta escribe `stack/.env` y solo reinicia el acceso.

| Comando | Qué hace |
|---|---|
| `./wuselwall mail test tu@example.org` | Envía un mensaje de prueba por el servidor indicado |
| `./wuselwall mail` | Muestra si el servidor envía correo y cómo |
| `./wuselwall mail off` | Sin correo: acceso solo con contraseña |

El idioma de los correos se elige aparte ([Instalación](/es/server/home-server#email-language)).

### En Supabase

Crea cinco secretos más en tu copia de GitHub y vuelve a ejecutar **deploy-supabase** ([Supabase](/es/server/supabase-cloud#mail)):

| Secreto | Gmail |
|---|---|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | tu dirección de Gmail |
| `SMTP_PASS` | la contraseña de aplicación (abajo) |
| `SMTP_SENDER` | tu dirección de Gmail |

Sin estos secretos, el servidor se configura sin correo.

## Con Gmail {#gmail}

Basta una cuenta de Gmail: sin dominio, sin registros DNS, gratis. Google exige una **contraseña de aplicación** de 16 letras, solo para WuselWall.

1. **Una cuenta propia.** Usa una dirección de Gmail solo para el servidor familiar. Una contraseña de aplicación abre todo el buzón: quien lea `stack/.env` podría leer y enviar sus correos.
2. **Verificación en dos pasos.** En [myaccount.google.com](https://myaccount.google.com/) → **Seguridad** → **Verificación en dos pasos**. Sin ella no hay contraseñas de aplicación.
3. **Crear la contraseña.** Abre [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords), ponle el nombre `WuselWall` y pulsa **Crear**. Copia las 16 letras: Google solo las muestra una vez.
4. **Introducirla en el servidor**: `./wuselwall mail smtp --gmail --user …` y luego `./wuselwall mail test tu@example.org`. Los espacios dan igual. En Supabase va en `SMTP_PASS`.

Conviene saber: los códigos salen siempre de la dirección de Gmail; Gmail envía unos 500 mensajes al día ([Google](https://support.google.com/mail/answer/22839?hl=es)); cambiar la contraseña de Google revoca las contraseñas de aplicación (crea otra y repite `mail smtp`); no está disponible con solo llaves de seguridad, con la Protección Avanzada ni en la mayoría de cuentas de trabajo o centro educativo ([Google](https://support.google.com/mail/answer/185833?hl=es)); Google ve direcciones y códigos.

## Otros proveedores {#providers}

| Proveedor | ¿Funciona? |
|---|---|
| **Tu buzón** en un proveedor como Posteo, mailbox.org, Infomaniak… | Normalmente sí: servidor, puerto `587` y usuario en la ayuda del proveedor; algunos piden activar antes el acceso de programas de correo |
| **Outlook.com, Hotmail** | No: Microsoft solo acepta su propio acceso (OAuth) para enviar |
| **Servicio de correo transaccional** (Scaleway, Brevo, Mailjet…) | Sí, con dominio propio y los registros SPF, DKIM y DMARC que pida |

Son ejemplos, no recomendaciones; WuselWall no está vinculado a ninguno. En lugar de SMTP, la función de WuselWall también puede enviar mediante Scaleway (`SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `MAIL_FROM`).

## Contraseña olvidada sin correo {#forgotten-password}

1. Un **responsable**, en su propio teléfono: **Ajustes → Familia → Miembros**, **Restablecer contraseña** junto al nombre y luego **Crear código**.
2. La app muestra un **código de 8 caracteres**, válido **una vez** durante **10 minutos**. Entrégalo en persona.
3. En el dispositivo de quien la olvidó: **Continuar con correo electrónico** → **Iniciar sesión** → **¿Olvidaste tu contraseña?**, y luego la dirección, el código y una contraseña nueva de al menos 10 caracteres.

La verificación en dos pasos sigue pidiéndose si está activa. **¿Lo olvidó el único responsable?** Quien administra el servidor crea el mismo código: `./wuselwall password direccion@example.org`, o en Supabase en **SQL Editor**: `select app.password_reset_issue_for_email('direccion@example.org') ->> 'code';`

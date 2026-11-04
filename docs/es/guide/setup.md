# Iniciar sesión y conectar

En el primer inicio elige el servidor ([Instalar la app](/es/guide/install)). Después, la pantalla inicial permite iniciar sesión, aceptar una invitación o conectar un dispositivo compartido.

## ¿Qué camino necesitas?

| Quieres… | Empieza aquí |
|---|---|
| Crear la primera familia en un servidor nuevo | Usa primero la [clave de configuración](#setup-key), inicia sesión y crea la familia |
| Aceptar una invitación | [Únete a la familia](#_3-joining-a-family), sin crear otra |
| Usar tu cuenta en otro móvil personal | [Inicia sesión](#_1-signing-in) con la misma cuenta |
| Conectar una tableta compartida o la pantalla de la cocina | [Conecta un dispositivo compartido](#_4-connecting-a-family-tablet-or-wall-display); un responsable lo aprueba desde su móvil |

La clave de configuración, el código de acceso por correo y el código de invitación sirven para cosas distintas. Usa el que te pida la página actual.

Si no tienes conexión, la pantalla inicial explica que necesitas Internet para iniciar
sesión, aceptar invitaciones o conectar dispositivos compartidos. Estas opciones vuelven
a estar disponibles cuando te conectas de nuevo.

<Shot name="setup-start" alt="La pantalla inicial de WuselWall" />

Abajo, **Política de privacidad** abre la página en el navegador. Sin conexión, el enlace está desactivado; la política no se almacena en la app.

## La clave de configuración: un servidor sin familia {#setup-key}

Un servidor recién instalado no tiene familia. Quien lo instaló tiene la **clave de
configuración**: la instalación la muestra, y el enlace o el código QR de configuración la
incluye. La pantalla de inicio de ese servidor lo dice y ofrece **Tengo la clave de
configuración**; el enlace de configuración abre directamente **Configurar tu servidor**. El
botón de abajo dice entonces solo **Iniciar sesión**, para las cuentas que ya existen.

Allí introduces tu dirección de correo junto a la clave. WuselWall comprueba la clave con el
servidor y anuncia con ella tu dirección: hasta que exista la familia, el servidor solo crea una
cuenta para esa dirección, y cualquier otra persona ve que el servidor aún no tiene familia.
Después llega el código de tu correo, o una contraseña en un servidor sin correo, y **Nueva
familia** ya no pide ninguna clave. Nadie teclea la clave una segunda vez; quien administra el
servidor genera otra con `./wuselwall setup-token` mientras no exista familia.

<Shot name="setup-claim" alt="Configurar el servidor con la clave de configuración y el correo" />

## 1. Iniciar sesión {#_1-signing-in}

### Con correo del servidor

En tu móvil personal, toca **Iniciar sesión o crear una cuenta**, introduce una dirección válida y toca **Enviar código**. **No necesitas una cuenta antes:** los pasos son los mismos en ambos casos. Si la dirección es nueva, el código crea tu cuenta; si ya tiene una, el código inicia tu sesión. La app comprueba el campo antes de enviar nada. Recibirás un **código de seis cifras**, válido durante **10 minutos**. Mantén abierto el campo y escribe allí el código del mensaje. Revisa el correo no deseado si no llega; puedes solicitar otro tras un minuto como mínimo.

El código verifica tu dirección. No es la **clave de configuración del servidor** y no requiere un enlace ni otro inicio de sesión.

<Shot name="setup-sign-in" alt="El inicio de sesión por correo electrónico" />

Si prefieres contraseña, toca **Iniciar sesión con contraseña**. Es para una cuenta que ya la tiene; si la tuya aún no tiene o la olvidaste, usa el código. Introduce tu dirección de correo y la contraseña y toca **Iniciar sesión**. La app comprueba ambos campos antes de iniciar sesión. Puedes definirla en **Ajustes → Cuenta y seguridad → Inicio de sesión**, con al menos **10 caracteres**. El código por correo sigue disponible mientras el servidor envíe correo. Al crear la cuenta, la app pregunta una vez qué método prefieres. Si activaste el segundo factor, después tendrás que introducir el código de tu app de autenticación ([Seguridad](/es/settings/security)).

### Sin correo del servidor

**Servidor sin correo** ([Correo](/es/server/email)): **Iniciar sesión o crear una cuenta** se abre en **Cuenta nueva**. Introduce tu dirección y una contraseña de al menos 10 caracteres y toca **Crear cuenta**; no hay código ni correo de confirmación. ¿Ya tienes cuenta? **Iniciar sesión**. ¿Olvidaste la contraseña? Toca **¿Olvidaste tu contraseña?** y pide un código a un responsable de tu familia ([Restablecer](/es/settings/members-devices#reset-password)).

## 2. Crear una familia {#_2-creating-a-new-family}

Si tu cuenta aún no pertenece a un hogar, aparece **Nueva familia**. Introduce desde tu móvil:

1. El **nombre de la familia**.
2. **Tu nombre** y **tu color**, que identifica tus acciones.
3. Si quieres, los **ejemplos** de tareas y recompensas, editables después.
4. La **clave de configuración**, si el servidor la pide y no la has introducido antes de iniciar sesión ([La clave de configuración](#setup-key)). La proporciona la instalación o la persona responsable del servidor, no el correo de inicio de sesión.

Si abriste el enlace o el QR de configuración, o introdujiste la clave en **Tengo la clave de configuración**, WuselWall ya anunció tu dirección con ella: no la pide otra vez. Guárdala como una llave y compártela solo con quien cree el hogar.

<Shot name="new-family" alt="El formulario de creación de una familia" />

Toca **Crear familia**. Si la confirmación tarda más de 15 segundos, aparece un aviso con opciones para indicar que recibiste una invitación o cerrar sesión. El botón de creación sigue bloqueado para evitar duplicados. Si llega la confirmación después, la app continúa sola.

A continuación, añade por nombre a los niños y otros adultos; podrás invitar a estos después. También puedes saltar este paso. El móvil se convierte en tu dispositivo personal, con un nombre automático editable en los ajustes. Se abre **Hoy**.

## 3. Unirse a una familia {#_3-joining-a-family}

La invitación puede ser un **enlace**, un **QR** o un **código**. El enlace y el QR incluyen también el servidor. Si la app está instalada, abren directamente la invitación. Si la app aún no está conectada a ningún servidor, muestra primero la dirección del servidor del enlace y pregunta si debe conectarse ([Primer inicio](/es/guide/install#at-first-start-which-server)). Si no, instala la app desde la página indicada y vuelve a abrir el enlace.

Con un código solo:

1. Toca **Tengo un código de invitación**. Si la app pregunta por el servidor, introduce ambos, como `K7QM3XRP@family.example.org`.
2. Pega el código o el enlace completo y comprueba la invitación.
3. La app muestra tu nombre y la familia. Ajusta el nombre y el color si hace falta y únete.

Si te invitaron con tu dirección y la verificaste con un código por correo, la invitación aparece al iniciar sesión. En un servidor sin correo, usa el enlace, el QR o el código de invitación. Dura **7 días** y se usa **una vez**. Consulta [Invitar a un adulto](/es/settings/members-devices#invite-an-adult).

Una cuenta pertenece a **una sola** familia. Si abres una invitación cuando ya estás en una familia, WuselWall muestra **Ya formas parte de ‹familia›** y quién te invita y a dónde. **Salir de la familia** te guía, con una confirmación; después la invitación sigue directamente. **Cancelar** lo deja todo como está. Si la invitación es para la familia en la que ya estás, WuselWall solo te lo dice.

## 4. Conectar una tableta familiar o pantalla de pared {#_4-connecting-a-family-tablet-or-wall-display}

Un adulto aprueba el nuevo dispositivo desde su móvil:

1. En el nuevo dispositivo, toca **Conectar una tableta familiar o pantalla de pared**. Aparecen un QR y un código.
2. En tu móvil, abre **Ajustes → Dispositivos → Conectar un dispositivo**. También puedes empezar desde **Primeros pasos**.
3. Escanea el QR o escribe el código y toca **Siguiente**. Las letras pasan a mayúsculas y el guion se inserta automáticamente.
4. Elige pantalla de pared, tableta infantil, tableta compartida o teléfono de un niño. Para este último, elige al niño. Pon un nombre y conecta.
5. La primera vez defines el **PIN de responsable** para acciones protegidas en dispositivos compartidos ([¿Quién eres?](/es/guide/who-are-you)).

<Shot name="pair-device" alt="El QR y el código del nuevo dispositivo" />

<Shot name="pair-approve" alt="La aprobación del dispositivo en el móvil de un adulto" />

El QR contiene el servidor: también puedes abrirlo con la cámara del móvil para llegar a la confirmación. El código dura **10 minutos** y se usa **una sola vez**. Si falla, empieza de nuevo en el dispositivo nuevo. La pantalla de pared muestra después una breve [lista de preparación](/es/guide/wall).

::: tip Versiones antiguas
**Ajustes → Avanzados → Dispositivos → Crear un código para un dispositivo antiguo** mantiene la conexión con una versión anterior. Esta opción desaparecerá en la próxima versión.
:::

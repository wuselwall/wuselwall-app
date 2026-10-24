# Iniciar sesión y conectar

En el primer inicio elige el servidor ([Instalar la app](/es/guide/install)). Después, la pantalla inicial permite iniciar sesión, aceptar una invitación o conectar un dispositivo compartido.

Si no tienes conexión, la pantalla inicial explica que necesitas Internet para iniciar
sesión, aceptar invitaciones o conectar dispositivos compartidos. Estas opciones vuelven
a estar disponibles cuando te conectas de nuevo.

<Shot name="setup-start" alt="La pantalla inicial de WuselWall" />

Abajo, **Política de privacidad** abre la página en el navegador. Sin conexión, el enlace está desactivado; la política no se almacena en la app.

## 1. Iniciar sesión {#_1-signing-in}

En tu móvil personal, toca **Continuar con correo electrónico** e introduce una dirección válida. La app comprueba el campo antes de enviar nada. Recibirás un **código de seis cifras**, válido durante **10 minutos**. Mantén abierto el campo y escribe allí el código del mensaje. Revisa el correo no deseado si no llega; puedes solicitar otro tras un minuto como mínimo.

El código verifica tu dirección. No es el **código de configuración del servidor** y no requiere un enlace ni otro inicio de sesión.

<Shot name="setup-sign-in" alt="El inicio de sesión por correo electrónico" />

Si prefieres contraseña, elige esa opción e introduce tu dirección de correo y la contraseña. La app comprueba ambos campos antes de iniciar sesión. Puedes definirla en **Ajustes → Avanzados → Inicio de sesión**, con al menos **10 caracteres**. El código por correo sigue disponible. Al crear la cuenta, la app pregunta una vez qué método prefieres. Si activaste el segundo factor, después tendrás que introducir el código de tu app de autenticación ([Seguridad](/es/settings/security)).

## 2. Crear una familia {#_2-creating-a-new-family}

Si tu cuenta aún no pertenece a un hogar, aparece **Nueva familia**. Introduce desde tu móvil:

1. El **nombre de la familia**.
2. **Tu nombre** y **tu color**, que identifica tus acciones.
3. Si quieres, los **ejemplos** de tareas y recompensas, editables después.
4. El **código de configuración**, si el servidor lo pide y no has abierto su enlace. Lo proporciona la instalación o la persona responsable del servidor, no el correo de inicio de sesión.

El enlace o QR de configuración incluye servidor y código. La app conserva el código durante el inicio de sesión y no lo pide otra vez. Guárdalo como una llave y compártelo solo con quien cree el hogar.

<Shot name="new-family" alt="El formulario de creación de una familia" />

Toca **Crear familia**. Si la confirmación tarda más de 15 segundos, aparece un aviso con opciones para indicar que recibiste una invitación o cerrar sesión. El botón de creación sigue bloqueado para evitar duplicados. Si llega la confirmación después, la app continúa sola.

A continuación, añade por nombre a los niños y otros adultos; podrás invitar a estos después. También puedes saltar este paso. El móvil se convierte en tu dispositivo personal, con un nombre automático editable en los ajustes. Se abre **Hoy**.

## 3. Unirse a una familia {#_3-joining-a-family}

La invitación puede ser un **enlace**, un **QR** o un **código**. El enlace y el QR incluyen también el servidor. Si la app está instalada, abren directamente la invitación. Si no, instala la app desde la página indicada y vuelve a abrir el enlace.

Con un código solo:

1. Toca **Tengo un código de invitación**. Si la app pregunta por el servidor, introduce ambos, como `K7QM3XRP@family.example.org`.
2. Pega el código o el enlace completo y comprueba la invitación.
3. La app muestra tu nombre y la familia. Ajusta el nombre y el color si hace falta y únete.

Si te invitaron con tu correo exacto, la invitación aparece al iniciar sesión con él. Dura **7 días** y se usa **una vez**. Consulta [Invitar a un adulto](/es/settings/members-devices#invite-an-adult).

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

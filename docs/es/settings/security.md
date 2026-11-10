# Seguridad

Los ajustes de acceso y seguridad están en **Ajustes → Cuenta y seguridad**, solo en el **móvil personal de una madre o un padre**.

## Inicio de sesión {#sign-in}

El código por correo está disponible si tu servidor envía correo. Puedes definir o cambiar una [contraseña](/es/settings/account#password).

<Shot name="settings-sign-in" alt="Los ajustes de inicio de sesión y contraseña" />

## Segundo factor {#two-factor-sign-in}

Además de la contraseña, se pide un **código de seis cifras** de una app de autenticación, como el gestor de contraseñas o Aegis.

1. Activa el segundo factor.
2. Escanea el QR con la app de autenticación.
3. Introduce el código que muestre.

Cada nueva sesión pedirá ese código antes de acceder a datos familiares. Puedes desactivarlo en el mismo lugar.

Si solo un padre o madre tiene una cuenta conectada, aparece una advertencia antes de activar esta opción: sin tu autenticador, nadie más puede restablecer tu segundo factor. Invita primero a otro padre o madre y pídele que inicie sesión, o guarda una copia de seguridad separada de tu autenticador. De lo contrario, necesitarás ayuda de quien administra vuestro servidor. Puedes cancelar o activar de todos modos.

<Shot name="totp-recovery-warning" alt="Advertencia antes de activar sin otro padre o madre con una cuenta conectada" />

## PIN de los padres {#guardian-pin}

El PIN de seis cifras protege acciones en [dispositivos compartidos](/es/guide/who-are-you). Tu móvil personal conectado permite poner uno nuevo, aunque el antiguo esté bloqueado.

## Clave de acceso {#passkey}

Las claves de acceso todavía no están disponibles en la aplicación habitual. Se ofrecerán después de verificarlas en dispositivos reales.

## Conviene recordar {#good-to-know}

La contraseña tiene al menos **10 caracteres**; una frase es mejor. Si pierdes el móvil, [bloquéalo](/es/settings/members-devices#blocking-a-device) desde otro dispositivo. Los datos permanecen en el servidor elegido por tu familia. Si usas Supabase u otro proveedor de alojamiento, ese proveedor los aloja; WuselWall no gestiona un servicio de datos para tu familia.

// Spanish wording of sign-in and account mails; MailMessages enforces parity.
import type { MailMessages } from "./mail_render.ts";

export const MAIL_ES: MailMessages = {
  subject: {
    magiclink: "Tu código de WuselWall",
    signup: "Tu código de WuselWall",
    email: "Tu código de WuselWall",
    recovery: "Tu código de WuselWall para restablecer tu contraseña",
    email_change: "Tu código de WuselWall para cambiar tu dirección de correo",
    reauthentication: "Tu código de confirmación de WuselWall",
    invite: "Invitación a WuselWall",
  },
  heading: {
    magiclink: "Tu código de acceso",
    signup: "Confirma tu dirección de correo",
    email: "Tu código de acceso",
    recovery: "Restablece tu contraseña",
    email_change: "Confirma tu nueva dirección de correo",
    reauthentication: "Confirma que eres tú",
    invite: "Tienes una invitación",
  },
  lead: {
    magiclink: "Este es tu código para iniciar sesión en WuselWall:",
    signup:
      "¡Te damos la bienvenida a WuselWall! Este es tu código para confirmar tu cuenta:",
    email: "Este es tu código de WuselWall:",
    recovery:
      "Inicia sesión con este código y después establece una nueva contraseña:",
    email_change:
      "Utiliza este código para confirmar el cambio de tu dirección de correo:",
    reauthentication: "Confirma con este código que eres tú:",
    invite:
      "Has recibido una invitación para unirte a una familia en WuselWall. Abre WuselWall e inicia sesión con esta dirección de correo.",
  },
  codeLabelOld: "Código para tu dirección anterior",
  codeLabelNew: "Código para tu nueva dirección",
  instruction: "Introduce el código en WuselWall.",
  validity: "El código es válido durante 10 minutos.",
  ignore: "Si no has solicitado este correo, puedes ignorarlo.",
  greeting: "Hola:",
  signoff: "Un saludo de WuselWall",
  footer: "Este correo procede del servidor de WuselWall donde está tu cuenta.",
};

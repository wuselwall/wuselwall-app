// French wording of sign-in and account mails; MailMessages enforces parity.
import type { MailMessages } from "./mail_render.ts";

export const MAIL_FR: MailMessages = {
  subject: {
    magiclink: "Votre code WuselWall",
    signup: "Votre code WuselWall",
    email: "Votre code WuselWall",
    recovery: "Votre code WuselWall pour réinitialiser votre mot de passe",
    email_change: "Votre code WuselWall pour changer d’adresse e-mail",
    reauthentication: "Votre code de confirmation WuselWall",
    invite: "Invitation à WuselWall",
  },
  heading: {
    magiclink: "Votre code de connexion",
    signup: "Confirmez votre adresse e-mail",
    email: "Votre code de connexion",
    recovery: "Réinitialisez votre mot de passe",
    email_change: "Confirmez votre nouvelle adresse e-mail",
    reauthentication: "Confirmez que c’est bien vous",
    invite: "Vous avez une invitation",
  },
  lead: {
    magiclink: "Voici votre code pour vous connecter à WuselWall :",
    signup:
      "Bienvenue sur WuselWall ! Voici votre code pour confirmer votre compte :",
    email: "Voici votre code pour WuselWall :",
    recovery:
      "Connectez-vous avec ce code, puis définissez un nouveau mot de passe :",
    email_change:
      "Utilisez ce code pour confirmer le changement de votre adresse e-mail :",
    reauthentication: "Confirmez que c’est bien vous avec ce code :",
    invite:
      "Vous avez reçu une invitation à rejoindre une famille sur WuselWall. Ouvrez WuselWall et connectez-vous avec cette adresse e-mail.",
  },
  codeLabelOld: "Code pour votre ancienne adresse",
  codeLabelNew: "Code pour votre nouvelle adresse",
  instruction: "Saisissez le code dans WuselWall.",
  validity: "Le code est valable pendant 10 minutes.",
  ignore:
    "Si vous n’êtes pas à l’origine de cette demande, vous pouvez ignorer cet e-mail.",
  greeting: "Bonjour,",
  signoff: "À bientôt sur WuselWall",
  footer: "Cet e-mail provient du serveur WuselWall qui héberge votre compte.",
};

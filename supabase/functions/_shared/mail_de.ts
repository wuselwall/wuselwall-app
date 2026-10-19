// German wording of the sign-in and account mails (mail_render.ts). Keys mirror mail_en.ts;
// the MailMessages type makes a missing or extra key a compile error.
import type { MailMessages } from "./mail_render.ts";

export const MAIL_DE: MailMessages = {
  subject: {
    magiclink: "Dein WuselWall-Code",
    signup: "Dein WuselWall-Code",
    email: "Dein WuselWall-Code",
    recovery: "Dein WuselWall-Code zum Zurücksetzen",
    email_change: "Dein WuselWall-Code zur Adressänderung",
    reauthentication: "Dein WuselWall-Code zur Bestätigung",
    invite: "Einladung zu WuselWall",
  },
  heading: {
    magiclink: "Dein Anmeldecode",
    signup: "Bestätige deine E-Mail-Adresse",
    email: "Dein Anmeldecode",
    recovery: "Passwort zurücksetzen",
    email_change: "Bestätige deine neue E-Mail-Adresse",
    reauthentication: "Bestätige, dass du es bist",
    invite: "Du bist eingeladen",
  },
  lead: {
    magiclink: "Hier ist dein Code für die Anmeldung bei WuselWall:",
    signup:
      "Willkommen bei WuselWall! Hier ist dein Code, um dein Konto zu bestätigen:",
    email: "Hier ist dein Code für WuselWall:",
    recovery:
      "Mit diesem Code meldest du dich an und kannst danach dein Passwort neu setzen:",
    email_change:
      "Mit diesem Code bestätigst du die Änderung deiner E-Mail-Adresse:",
    reauthentication: "Bitte bestätige mit diesem Code, dass du es bist:",
    invite:
      "Du wurdest zu einer Familie in WuselWall eingeladen. Öffne WuselWall und melde dich mit dieser E-Mail-Adresse an.",
  },
  codeLabelOld: "Code für deine bisherige Adresse",
  codeLabelNew: "Code für deine neue Adresse",
  instruction: "Gib den Code in WuselWall ein.",
  validity: "Der Code ist 10 Minuten gültig.",
  ignore: "Wenn du das nicht warst, kannst du diese E-Mail ignorieren.",
  greeting: "Hallo,",
  signoff: "Viele Grüße von WuselWall",
  footer: "Diese E-Mail kommt vom WuselWall-Server deines Kontos.",
};

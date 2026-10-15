// English wording of the sign-in and account mails (mail_render.ts). Keys mirror mail_de.ts;
// the MailMessages type makes a missing or extra key a compile error.
import type { MailMessages } from "./mail_render.ts";

export const MAIL_EN: MailMessages = {
  subject: {
    magiclink: "Your WuselWall code",
    signup: "Your WuselWall code",
    email: "Your WuselWall code",
    recovery: "Your WuselWall code to reset your password",
    email_change: "Your WuselWall code to change your email address",
    reauthentication: "Your WuselWall code to confirm",
    invite: "Invitation to WuselWall",
  },
  lead: {
    magiclink: "Here is your code to sign in to WuselWall:",
    signup: "Welcome to WuselWall! Here is your code to confirm your account:",
    email: "Here is your code for WuselWall:",
    recovery: "Use this code to sign in, then set a new password:",
    email_change: "Use this code to confirm the change of your email address:",
    reauthentication: "Please confirm with this code that it is you:",
    invite:
      "You have been invited to a family in WuselWall. Open WuselWall and sign in with this email address.",
  },
  codeLabelOld: "Code for your previous address",
  codeLabelNew: "Code for your new address",
  validity: "The code is valid for 10 minutes.",
  ignore: "If this wasn't you, you can ignore this email.",
  greeting: "Hi,",
  signoff: "Best regards from WuselWall",
};

// The notice mfa-reset sends to the person whose authenticator was removed (security review
// 2026-11-01, F3). Separate from index.ts so it can be tested without starting the server.
import { mailSettingsFromEnv } from "../_shared/send_email_hook.ts";
import { renderNotice } from "../_shared/mail_render.ts";
import { MailSendError, sendScalewayMail } from "../_shared/scaleway_mail.ts";

/**
 * Tells the person whose authenticator was removed. Never throws: a failed notice is logged
 * (the kind and the cause, never the address), and the reset stands. Returns whether a mail
 * was queued.
 */
export async function notifyTarget(
  email: string | null | undefined,
  get: (name: string) => string | undefined = (name) => Deno.env.get(name),
  fetchFn: typeof fetch = fetch,
): Promise<boolean> {
  if (!email) {
    console.log("mfa-reset: no notice, the account has no address");
    return false;
  }
  const loaded = mailSettingsFromEnv(get);
  if (!loaded.ok) {
    // Names only. A server that mails through GoTrue's SMTP has no sender for a function.
    console.log(`mfa-reset: no notice possible, missing ${loaded.missing.join(", ")}`);
    return false;
  }
  try {
    const mail = renderNotice({ locale: loaded.settings.locale, kind: "mfa_reset" });
    await sendScalewayMail(loaded.settings.scaleway, { to: email, ...mail }, { fetch: fetchFn });
    console.log(`mfa-reset: notice queued (${loaded.settings.locale})`);
    return true;
  } catch (err) {
    const cause = err instanceof MailSendError ? err.code : "error";
    console.error(`mfa-reset: notice not sent: ${cause}`);
    return false;
  }
}

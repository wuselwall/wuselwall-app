// The Send Email Hook (Supabase Auth, specs/10 §4 and specs/20 "Email"): GoTrue posts each
// mail it would send here instead of sending it, with the code and the recipient. This
// module verifies the Standard Webhooks signature, renders the mail in the operator's
// MAIL_LANGUAGE (German by default) and hands it to Scaleway Transactional Email.
//
// Authentication: the signature is the only gate. The function is called by GoTrue, which
// has no user JWT, so the router lists it in NO_USER_FUNCTIONS. Nothing here trusts the
// payload until its signature has been checked.
//
// Failures: GoTrue reports a non-2xx answer to the user as a failed sign-in, so a provider
// outage is a 5xx carrying `{error:{http_code, message}}`, and a bad signature is a 401.
// Logs carry the email action and the locale, never the address or the code.
//
// An email change (security review 2026-11-01, F1): with secure email change on, GoTrue
// makes ONE call carrying `token` (the code for the current address, `user.email`) and
// `token_new` (the code for the new one, `user.new_email`). Each address gets its own mail
// with only its own code; the current address never sees the code that proves the new one.
// With secure email change off GoTrue sends `token` alone, and it is the new address's code.
//
// The codes are GoTrue's one-time passwords: 6 to 10 digits (GOTRUE_MAILER_OTP_LENGTH; the
// stacks set 6). Anything else is refused before it is rendered, so whoever holds the hook
// secret cannot use the server's sender to mail arbitrary text (F27).
import {
  isMailKind,
  MAIL_LOCALES,
  type MailKind,
  type MailLocale,
  MailRenderError,
  type RenderedMail,
  renderMail,
} from "./mail_render.ts";
import {
  MailSendError,
  type ScalewayConfig,
  sendScalewayMail,
} from "./scaleway_mail.ts";
import { verifyWebhook } from "./webhook_signature.ts";

export interface HookSettings {
  /** `v1,whsec_<base64>`, the same value GoTrue has in GOTRUE_HOOK_SEND_EMAIL_SECRETS. */
  hookSecret: string;
  scaleway: ScalewayConfig;
  /** Operator-selected server language. Omitted by older callers: German. */
  locale?: MailLocale;
}

/** Required variables. Missing/invalid settings are reported by name, never by value. */
export const REQUIRED_ENV = [
  "SEND_EMAIL_HOOK_SECRET",
  "SCW_SECRET_KEY",
  "SCW_PROJECT_ID",
  "MAIL_FROM",
] as const;

/** The variables a function needs to send a mail of its own (no hook secret). */
export const MAIL_ENV = ["SCW_SECRET_KEY", "SCW_PROJECT_ID", "MAIL_FROM"] as const;

export interface MailSettings {
  scaleway: ScalewayConfig;
  locale: MailLocale;
}

/**
 * The sender settings alone, for a function that mails a notice itself (mfa-reset). A
 * server without the Scaleway values has no way to send from a function: SMTP belongs to
 * GoTrue, which mails only its own templates.
 */
export function mailSettingsFromEnv(
  get: (name: string) => string | undefined,
): { ok: true; settings: MailSettings } | { ok: false; missing: string[] } {
  const missing: string[] = MAIL_ENV.filter((name) => !get(name));
  const locale = get("MAIL_LANGUAGE") ?? "de";
  // Configuration is exact, unlike device locale tags: never silently change a bad setting.
  if (!(MAIL_LOCALES as readonly string[]).includes(locale)) {
    missing.push("MAIL_LANGUAGE");
  }
  if (missing.length > 0) return { ok: false, missing };
  return {
    ok: true,
    settings: {
      locale: locale as MailLocale,
      scaleway: {
        secretKey: get("SCW_SECRET_KEY")!,
        projectId: get("SCW_PROJECT_ID")!,
        region: get("SCW_REGION") || "fr-par",
        fromEmail: get("MAIL_FROM")!,
        fromName: get("MAIL_FROM_NAME") || "WuselWall",
      },
    },
  };
}

export function settingsFromEnv(
  get: (name: string) => string | undefined,
): { ok: true; settings: HookSettings } | { ok: false; missing: string[] } {
  const mail = mailSettingsFromEnv(get);
  const secret = get("SEND_EMAIL_HOOK_SECRET");
  if (!mail.ok || !secret) {
    const missing = [
      ...(secret ? [] : ["SEND_EMAIL_HOOK_SECRET"]),
      ...(mail.ok ? [] : mail.missing),
    ];
    // Reported in REQUIRED_ENV's order, MAIL_LANGUAGE last, as before.
    return {
      ok: false,
      missing: [
        ...REQUIRED_ENV.filter((name) => missing.includes(name)),
        ...missing.filter((name) => !(REQUIRED_ENV as readonly string[]).includes(name)),
      ],
    };
  }
  return {
    ok: true,
    settings: { hookSecret: secret, locale: mail.settings.locale, scaleway: mail.settings.scaleway },
  };
}

/** GoTrue's one-time passwords: 6 to 10 digits. Nothing else is a code this hook mails. */
export const OTP_SHAPE = /^[0-9]{6,10}$/;

function hookError(status: number, message: string): Response {
  return Response.json({ error: { http_code: status, message } }, { status });
}

type Payload = {
  userEmail: string;
  /** The address an email change goes to (`user.new_email`), when GoTrue sends one. */
  newEmail: string | undefined;
  kind: string;
  token: string | undefined;
  tokenNew: string | undefined;
};

/** Where one mail goes and which code it carries. */
export type Delivery = {
  to: string;
  token: string | undefined;
  codeLabel?: "old" | "new";
};

/**
 * The mails one hook call asks for. An email change is one mail per address, each with its
 * own code; every other kind is one mail to the account's address.
 */
export function deliveriesFor(payload: Payload): Delivery[] {
  if (payload.kind !== "email_change") {
    return [{ to: payload.userEmail, token: payload.token }];
  }
  if (payload.tokenNew) {
    // Secure email change: `token` proves the current address, `token_new` the new one.
    const mails: Delivery[] = [{ to: payload.userEmail, token: payload.token, codeLabel: "old" }];
    if (payload.newEmail) {
      mails.push({ to: payload.newEmail, token: payload.tokenNew, codeLabel: "new" });
    }
    return mails;
  }
  // One code only: it is the new address's, so it goes there and nowhere else.
  if (!payload.newEmail) return [];
  return [{ to: payload.newEmail, token: payload.token, codeLabel: "new" }];
}

/** The fields the hook reads from GoTrue's payload, or null when a required one is missing. */
function readPayload(value: unknown): Payload | null {
  if (typeof value !== "object" || value === null) return null;
  const { user, email_data: data } = value as Record<string, unknown>;
  if (
    typeof user !== "object" || user === null || typeof data !== "object" ||
    data === null
  ) {
    return null;
  }
  const email = (user as Record<string, unknown>).email;
  const kind = (data as Record<string, unknown>).email_action_type;
  if (typeof email !== "string" || !email || typeof kind !== "string") {
    return null;
  }
  const text = (
    v: unknown,
  ) => (typeof v === "string" && v !== "" ? v : undefined);
  return {
    userEmail: email,
    newEmail: text((user as Record<string, unknown>).new_email),
    kind,
    token: text((data as Record<string, unknown>).token),
    tokenNew: text((data as Record<string, unknown>).token_new),
  };
}

/** Handles one hook request. `fetch` is injectable for the tests. */
export async function sendEmailHook(
  req: Request,
  settings: HookSettings,
  fetchFn: typeof fetch = fetch,
): Promise<Response> {
  if (req.method !== "POST") return hookError(405, "use POST");

  const body = await req.text();
  let verdict;
  try {
    verdict = await verifyWebhook({
      secret: settings.hookSecret,
      id: req.headers.get("webhook-id"),
      timestamp: req.headers.get("webhook-timestamp"),
      signature: req.headers.get("webhook-signature"),
      body,
    });
  } catch {
    // The secret itself is malformed: an operator error, reported as one.
    console.error(
      "send-email: SEND_EMAIL_HOOK_SECRET is not in the v1,whsec_ form",
    );
    return hookError(500, "send-email is not configured correctly");
  }
  if (!verdict.ok) {
    console.warn(`send-email: signature refused (${verdict.reason})`);
    return hookError(401, "invalid webhook signature");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return hookError(400, "body is not JSON");
  }
  const payload = readPayload(parsed);
  if (!payload) {
    return hookError(400, "payload has no user email or email action");
  }

  // Notifications about changes that already happened (password changed, identity linked
  // and so on) are not sent: WuselWall sends no such mail. GoTrue treats the 200 as success.
  if (payload.kind.endsWith("_notification")) {
    console.log(`send-email: not sent (${payload.kind})`);
    return Response.json({});
  }
  if (!isMailKind(payload.kind)) {
    return hookError(400, "unsupported email action");
  }
  const kind: MailKind = payload.kind;
  // All mail from a server uses its operator-selected language, never recipient metadata.
  const locale = settings.locale ?? "de";

  // A code that is not a GoTrue one-time password is not rendered, let alone sent: the
  // log says only which field had the wrong shape.
  for (const [name, value] of [["token", payload.token], ["token_new", payload.tokenNew]] as const) {
    if (value !== undefined && !OTP_SHAPE.test(value)) {
      console.warn(`send-email: refused, ${name} is not a one-time code (${kind})`);
      return hookError(400, "the code has an unexpected form");
    }
  }

  const deliveries = deliveriesFor(payload);
  if (deliveries.length === 0) {
    // An email change without the new address: nothing may carry that address's code.
    return hookError(400, "payload has no new email");
  }
  const mails: Array<{ to: string } & RenderedMail> = [];
  try {
    for (const delivery of deliveries) {
      mails.push({
        to: delivery.to,
        ...renderMail({ locale, kind, token: delivery.token, codeLabel: delivery.codeLabel }),
      });
    }
  } catch (err) {
    if (err instanceof MailRenderError) return hookError(400, err.message);
    throw err;
  }

  for (const mail of mails) {
    try {
      await sendScalewayMail(settings.scaleway, mail, { fetch: fetchFn });
    } catch (err) {
      if (err instanceof MailSendError) {
        console.error(
          `send-email: ${kind} (${locale}) not sent: ${err.code}` +
            (err.providerStatus ? ` HTTP ${err.providerStatus}` : ""),
        );
        const message = err.code === "provider_timeout"
          ? "the mail provider did not answer in time"
          : "the mail provider could not send the mail";
        return hookError(err.status, message);
      }
      throw err;
    }
  }

  console.log(`send-email: ${kind} (${locale}) queued${mails.length > 1 ? ` x${mails.length}` : ""}`);
  return Response.json({});
}

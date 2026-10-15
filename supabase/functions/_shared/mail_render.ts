// Renders the mails Supabase Auth asks for (the Send Email Hook, specs/20 "Email"): a
// subject, a plain-text body and a minimal HTML body, in the recipient's language.
//
// Pure: no I/O, no clock. The wording lives in mail_de.ts and mail_en.ts, which must
// both satisfy MailMessages, so a key cannot exist in one language only. Every value that
// reaches the HTML is escaped; the code is digits, but it is escaped like any other value.
// No images, no remote CSS, no tracking: the mail is text with a few inline styles.
import { MAIL_DE } from "./mail_de.ts";
import { MAIL_EN } from "./mail_en.ts";

export type MailLocale = "de" | "en";

/** The GoTrue email actions this renderer knows (`email_data.email_action_type`). */
export type MailKind =
  | "magiclink"
  | "signup"
  | "email"
  | "recovery"
  | "email_change"
  | "reauthentication"
  | "invite";

export const MAIL_KINDS: readonly MailKind[] = [
  "magiclink",
  "signup",
  "email",
  "recovery",
  "email_change",
  "reauthentication",
  "invite",
];

/** The wording of one language. mail_de.ts and mail_en.ts both satisfy this type. */
export interface MailMessages {
  /** The subject before ": <code>". */
  subject: Record<MailKind, string>;
  /** The sentence above the code. */
  lead: Record<MailKind, string>;
  /** Labels for the two codes of an email change. */
  codeLabelOld: string;
  codeLabelNew: string;
  validity: string;
  ignore: string;
  greeting: string;
  signoff: string;
}

export interface RenderInput {
  locale: MailLocale;
  kind: MailKind;
  /** The code for this recipient. Required for every kind except an invitation. */
  token?: string;
  /** email_change only: the code for the new address, when GoTrue sends one. */
  tokenNew?: string;
}

export interface RenderedMail {
  subject: string;
  text: string;
  html: string;
}

/** A render refused its input. The message names the problem, never a value. */
export class MailRenderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "MailRenderError";
  }
}

const MESSAGES: Record<MailLocale, MailMessages> = { de: MAIL_DE, en: MAIL_EN };

export function isMailKind(value: unknown): value is MailKind {
  return typeof value === "string" &&
    (MAIL_KINDS as readonly string[]).includes(value);
}

/** `de` or `en` from a locale tag such as `en-GB`; anything else is German, the default. */
export function resolveLocale(value: unknown): MailLocale {
  if (typeof value !== "string") return "de";
  const primary = value.trim().toLowerCase().split(/[-_]/)[0];
  return primary === "en" ? "en" : "de";
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

type CodeLine = { label: string | null; code: string };

function codesFor(input: RenderInput, messages: MailMessages): CodeLine[] {
  const codes: CodeLine[] = [];
  if (input.token) {
    codes.push({
      label: input.kind === "email_change" && input.tokenNew
        ? messages.codeLabelOld
        : null,
      code: input.token,
    });
  }
  if (input.kind === "email_change" && input.tokenNew) {
    codes.push({ label: messages.codeLabelNew, code: input.tokenNew });
  }
  return codes;
}

/** Renders one mail. Throws MailRenderError when a code is missing for a kind that needs one. */
export function renderMail(input: RenderInput): RenderedMail {
  if (!isMailKind(input.kind)) {
    throw new MailRenderError("unknown email action");
  }
  const messages = MESSAGES[input.locale] ?? MAIL_DE;
  const codes = codesFor(input, messages);
  if (codes.length === 0 && input.kind !== "invite") {
    throw new MailRenderError("the email carries no code");
  }

  const firstCode = codes[0]?.code;
  const subject = firstCode
    ? `${messages.subject[input.kind]}: ${firstCode}`
    : messages.subject[input.kind];
  const lead = messages.lead[input.kind];

  const textParts: string[] = [messages.greeting, "", lead, ""];
  for (const line of codes) {
    textParts.push(line.label ? `${line.label}: ${line.code}` : line.code, "");
  }
  if (codes.length > 0) textParts.push(messages.validity, "");
  textParts.push(messages.ignore, "", messages.signoff);
  const text = textParts.join("\n");

  const codeBlocks = codes.map((line) => {
    const label = line.label
      ? `<p style="margin:0 0 4px;font-size:14px;color:#555555;">${
        escapeHtml(line.label)
      }</p>`
      : "";
    return `${label}<p style="margin:0 0 16px;font-family:'Courier New',Courier,monospace;font-size:32px;font-weight:bold;letter-spacing:6px;color:#222222;">${
      escapeHtml(line.code)
    }</p>`;
  }).join("");
  const validity = codes.length > 0
    ? `<p style="margin:0 0 16px;">${escapeHtml(messages.validity)}</p>`
    : "";

  const html = [
    "<!doctype html>",
    `<html lang="${input.locale}">`,
    '<head><meta charset="utf-8">',
    `<title>${escapeHtml(subject)}</title></head>`,
    '<body style="margin:0;padding:24px;background:#f6f3ec;font-family:Arial,Helvetica,sans-serif;color:#222222;">',
    '<div style="max-width:480px;margin:0 auto;background:#ffffff;padding:24px;border-radius:8px;">',
    `<p style="margin:0 0 16px;">${escapeHtml(messages.greeting)}</p>`,
    `<p style="margin:0 0 16px;">${escapeHtml(lead)}</p>`,
    codeBlocks,
    validity,
    `<p style="margin:0 0 16px;color:#555555;">${
      escapeHtml(messages.ignore)
    }</p>`,
    `<p style="margin:0;color:#555555;font-size:13px;">${
      escapeHtml(messages.signoff)
    }</p>`,
    "</div>",
    "</body>",
    "</html>",
  ].join("");

  return { subject, text, html };
}

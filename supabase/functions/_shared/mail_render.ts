// Renders the mails Supabase Auth asks for (the Send Email Hook, specs/20 "Email"): a
// subject, a plain-text body and an HTML body, in the recipient's language.
//
// Pure: no I/O, no clock. The wording lives in mail_de.ts and mail_en.ts, which must
// both satisfy MailMessages, so a key cannot exist in one language only. Every value that
// reaches the HTML is escaped; the code is digits, but it is escaped like any other value.
//
// The HTML is built for every mail client, Outlook's Word engine included: layout tables
// with `role="presentation"`, inline styles only (no <style> block a client might strip),
// bgcolor attributes beside background colours, a fixed-width ghost table for Outlook, web-
// safe fonts, and light colours declared so dark-mode clients do not invert them half-way.
// No images, no remote CSS, no tracking and no links: the code is the whole action
// (specs/20, "A code, not a magic link"). The text part carries everything the HTML does.
//
// The bilingual fallback templates in supabase/templates/ come from the same layout
// (renderFallbackTemplate); a test keeps the committed files in step with it.
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
  /** The headline at the top of the mail. */
  heading: Record<MailKind, string>;
  /** The sentence above the code. */
  lead: Record<MailKind, string>;
  /** Labels for the two codes of an email change. */
  codeLabelOld: string;
  codeLabelNew: string;
  /** Where the code goes, shown below it. */
  instruction: string;
  validity: string;
  ignore: string;
  greeting: string;
  signoff: string;
  /** The small print under the card: who sent this mail. */
  footer: string;
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

// The light palette of specs/17 ("Küchentisch", app/lib/app/theme/palette.dart); every
// text pair used here is checked for WCAG AA there.
const C = {
  bg: "#F7F4EE",
  surface: "#FFFFFF",
  line: "#DDD8CF",
  ink: "#1C1F23",
  ink2: "#4A5058",
  ink3: "#656B75",
  brand: "#2D6A4F",
  brandTint: "#DCEBE2",
  onBrandTint: "#133A2A",
} as const;

const FONT = "font-family:Arial,Helvetica,sans-serif;";
const MONO = "font-family:Menlo,Consolas,'Courier New',Courier,monospace;";
const TABLE = 'role="presentation" cellpadding="0" cellspacing="0" border="0"';

/** HTML-ready code: escaped by renderMail, or GoTrue's placeholder in a fallback template. */
type CodeHtml = { label: string | null; codeHtml: string };

/** One code in a tinted panel. Labels are escaped here. */
function codePanel({ label, codeHtml }: CodeHtml): string {
  const labelHtml = label
    ? `<p style="margin:0 0 6px;${FONT}font-size:13px;line-height:18px;color:${C.onBrandTint};">${
      escapeHtml(label)
    }</p>`
    : "";
  return `<table ${TABLE} width="100%" style="margin:0 0 12px;border-collapse:separate;">` +
    `<tr><td align="center" bgcolor="${C.brandTint}" style="background-color:${C.brandTint};border-radius:10px;padding:18px 12px;">` +
    labelHtml +
    `<p style="margin:0;${MONO}font-size:32px;line-height:40px;font-weight:bold;letter-spacing:6px;color:${C.onBrandTint};">${codeHtml}</p>` +
    `</td></tr></table>`;
}

/** The content of one card, in one language. */
function cardContent(
  messages: MailMessages,
  kind: MailKind,
  codes: CodeHtml[],
): string {
  const body = `font-size:16px;line-height:24px;color:${C.ink};`;
  const small = `${FONT}font-size:14px;line-height:20px;color:${C.ink2};`;
  const parts = [
    `<h1 style="margin:0 0 20px;${FONT}font-size:22px;line-height:28px;font-weight:bold;color:${C.ink};">${
      escapeHtml(messages.heading[kind])
    }</h1>`,
    `<p style="margin:0 0 16px;${FONT}${body}">${
      escapeHtml(messages.greeting)
    }</p>`,
    `<p style="margin:0 0 16px;${FONT}${body}">${
      escapeHtml(messages.lead[kind])
    }</p>`,
  ];
  if (codes.length > 0) {
    parts.push(...codes.map(codePanel));
    parts.push(
      `<p style="margin:4px 0 20px;${small}text-align:center;">${
        escapeHtml(messages.instruction)
      }<br>${escapeHtml(messages.validity)}</p>`,
    );
  }
  parts.push(
    `<table ${TABLE} width="100%"><tr><td style="border-top:1px solid ${C.line};font-size:1px;line-height:1px;height:1px;">&nbsp;</td></tr></table>`,
    `<p style="margin:16px 0 0;${small}">${escapeHtml(messages.ignore)}</p>`,
    `<p style="margin:16px 0 0;${small}">${escapeHtml(messages.signoff)}</p>`,
  );
  return parts.join("\n");
}

function card(content: string): string {
  return `<tr><td bgcolor="${C.surface}" style="background-color:${C.surface};border:1px solid ${C.line};border-radius:14px;padding:32px 28px;">\n${content}\n</td></tr>`;
}

/** The whole document around one or more cards. Every argument is HTML already. */
function documentShell(opts: {
  lang: string;
  titleHtml: string;
  preheaderHtml: string;
  cards: string[];
  footerHtml: string;
}): string {
  return [
    "<!doctype html>",
    `<html lang="${opts.lang}">`,
    "<head>",
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<meta name="x-apple-disable-message-reformatting">',
    '<meta name="format-detection" content="telephone=no, date=no, address=no, email=no">',
    '<meta name="color-scheme" content="light">',
    '<meta name="supported-color-schemes" content="light">',
    `<title>${opts.titleHtml}</title>`,
    "</head>",
    `<body style="margin:0;padding:0;width:100%;background-color:${C.bg};-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;">`,
    // The inbox preview line: hidden in the mail; the padding keeps body text out of it.
    `<div style="display:none;max-height:0;max-width:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;opacity:0;color:${C.bg};">${opts.preheaderHtml}${
      "&#847;&zwnj;&nbsp;".repeat(30)
    }</div>`,
    `<table ${TABLE} width="100%" bgcolor="${C.bg}" style="background-color:${C.bg};">`,
    '<tr><td align="center" style="padding:32px 12px;">',
    // Outlook for Windows ignores max-width: a fixed ghost table holds the column at 520 px.
    `<!--[if mso]><table ${TABLE} width="520" align="center"><tr><td><![endif]-->`,
    `<table ${TABLE} width="100%" style="max-width:520px;">`,
    `<tr><td style="padding:0 4px 16px;${FONT}font-size:20px;line-height:24px;font-weight:bold;color:${C.brand};">WuselWall</td></tr>`,
    opts.cards.join(
      '\n<tr><td style="height:16px;font-size:1px;line-height:1px;">&nbsp;</td></tr>\n',
    ),
    `<tr><td align="center" style="padding:20px 12px 0;${FONT}font-size:13px;line-height:19px;color:${C.ink3};">${opts.footerHtml}</td></tr>`,
    "</table>",
    "<!--[if mso]></td></tr></table><![endif]-->",
    "</td></tr>",
    "</table>",
    "</body>",
    "</html>",
  ].join("\n");
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

  const textParts: string[] = [
    messages.heading[input.kind],
    "",
    messages.greeting,
    "",
    lead,
    "",
  ];
  for (const line of codes) {
    textParts.push(line.label ? `${line.label}: ${line.code}` : line.code, "");
  }
  if (codes.length > 0) {
    textParts.push(messages.instruction, messages.validity, "");
  }
  textParts.push(
    messages.ignore,
    "",
    messages.signoff,
    "",
    "-- ",
    messages.footer,
  );
  const text = textParts.join("\n");

  const html = documentShell({
    lang: input.locale,
    titleHtml: escapeHtml(subject),
    preheaderHtml: escapeHtml(lead),
    cards: [
      card(cardContent(
        messages,
        input.kind,
        codes.map((c) => ({ label: c.label, codeHtml: escapeHtml(c.code) })),
      )),
    ],
    footerHtml: escapeHtml(messages.footer),
  });

  return { subject, text, html };
}

/** The GoTrue templates config.toml points at, by the mail kind they stand for. */
export const FALLBACK_TEMPLATES = {
  magiclink: "magic_link.html",
  signup: "confirmation.html",
} as const;

export type FallbackTemplateKind = keyof typeof FALLBACK_TEMPLATES;

/** The subject config.toml gives both fallback templates. */
export const FALLBACK_SUBJECT = "Dein WuselWall-Code / Your WuselWall code";

/**
 * A bilingual GoTrue template for stacks without the hook (specs/20 "Email"): German
 * first, English below, each in its own card, with GoTrue's `{{ .Token }}` as the code.
 */
export function renderFallbackTemplate(kind: FallbackTemplateKind): string {
  const code: CodeHtml[] = [{ label: null, codeHtml: "{{ .Token }}" }];
  return documentShell({
    lang: "de",
    titleHtml: escapeHtml(FALLBACK_SUBJECT),
    preheaderHtml: `${escapeHtml(MAIL_DE.lead[kind])} / ${
      escapeHtml(MAIL_EN.lead[kind])
    }`,
    cards: [
      card(cardContent(MAIL_DE, kind, code)),
      card(`<div lang="en">\n${cardContent(MAIL_EN, kind, code)}\n</div>`),
    ],
    footerHtml: `${escapeHtml(MAIL_DE.footer)}<br>${
      escapeHtml(MAIL_EN.footer)
    }`,
  }) + "\n";
}

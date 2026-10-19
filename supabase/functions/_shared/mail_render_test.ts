import {
  assert,
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "jsr:@std/assert@1.0.13";
import {
  escapeHtml,
  FALLBACK_SUBJECT,
  FALLBACK_TEMPLATES,
  fallbackSubject,
  type FallbackTemplateKind,
  isMailKind,
  MAIL_KINDS,
  MAIL_LOCALES,
  type MailKind,
  MailRenderError,
  renderFallbackTemplate,
  renderMail,
  resolveLocale,
} from "./mail_render.ts";
import { MAIL_DE } from "./mail_de.ts";
import { MAIL_EN } from "./mail_en.ts";
import { MAIL_FR } from "./mail_fr.ts";
import { MAIL_ES } from "./mail_es.ts";

const MESSAGES = { de: MAIL_DE, en: MAIL_EN, fr: MAIL_FR, es: MAIL_ES };

const CODE = "123456";

Deno.test("resolveLocale: supported language tags, German for anything else", () => {
  assertEquals(resolveLocale("en"), "en");
  assertEquals(resolveLocale("en-GB"), "en");
  assertEquals(resolveLocale("EN_us"), "en");
  assertEquals(resolveLocale("de"), "de");
  assertEquals(resolveLocale("de-CH"), "de");
  assertEquals(resolveLocale("fr"), "fr");
  assertEquals(resolveLocale("FR_ca"), "fr");
  assertEquals(resolveLocale("es-ES"), "es");
  assertEquals(resolveLocale("it"), "de");
  assertEquals(resolveLocale(undefined), "de");
  assertEquals(resolveLocale(42), "de");
});

Deno.test("French and Spanish sign-in mails use translated subjects and bodies", () => {
  for (
    const [tag, subject, instruction] of [
      ["fr", "Votre code WuselWall", "Saisissez le code dans WuselWall."],
      ["es", "Tu código de WuselWall", "Introduce el código en WuselWall."],
    ]
  ) {
    const mail = renderMail({
      locale: resolveLocale(tag),
      kind: "magiclink",
      token: CODE,
    });
    assertEquals(mail.subject, `${subject}: ${CODE}`);
    assertStringIncludes(mail.text, instruction);
    assertStringIncludes(mail.html, `<html lang="${tag}">`);
    assert(!mail.text.includes(MAIL_DE.instruction));
    assert(!mail.text.includes(MAIL_EN.instruction));
  }
});

Deno.test("all message files define every kind and key", () => {
  for (const messages of Object.values(MESSAGES)) {
    for (const kind of MAIL_KINDS) {
      assert(messages.subject[kind].length > 0, `subject ${kind}`);
      assert(messages.heading[kind].length > 0, `heading ${kind}`);
      assert(messages.lead[kind].length > 0, `lead ${kind}`);
    }
    assert(messages.instruction && messages.footer);
    assert(messages.codeLabelOld && messages.codeLabelNew && messages.validity);
    assert(messages.ignore && messages.greeting && messages.signoff);
    assertEquals(Object.keys(messages).sort(), Object.keys(MAIL_DE).sort());
    for (const field of ["subject", "heading", "lead"] as const) {
      assertEquals(Object.keys(messages[field]).sort(), [...MAIL_KINDS].sort());
    }
  }
  assertEquals(
    Object.keys(MAIL_DE.subject).sort(),
    Object.keys(MAIL_EN.subject).sort(),
  );
});

Deno.test("code mails: the subject carries the code, in both languages", () => {
  const de = renderMail({ locale: "de", kind: "magiclink", token: CODE });
  assertEquals(de.subject, "Dein WuselWall-Code: 123456");
  const en = renderMail({ locale: "en", kind: "magiclink", token: CODE });
  assertEquals(en.subject, "Your WuselWall code: 123456");
});

Deno.test("signup and email use the same code mail, in German", () => {
  for (const kind of ["signup", "email"] as const) {
    const mail = renderMail({ locale: "de", kind, token: CODE });
    assertEquals(mail.subject, "Dein WuselWall-Code: 123456");
    assertStringIncludes(mail.text, "123456");
    assertStringIncludes(mail.text, "10 Minuten gültig");
    assertStringIncludes(
      mail.text,
      "Wenn du das nicht warst, kannst du diese E-Mail ignorieren.",
    );
  }
});

Deno.test("German and English bodies carry the validity and the ignore line", () => {
  const de = renderMail({ locale: "de", kind: "magiclink", token: CODE });
  assertStringIncludes(de.text, MAIL_DE.validity);
  assertStringIncludes(de.text, MAIL_DE.ignore);
  assertStringIncludes(de.html, MAIL_DE.ignore);
  const en = renderMail({ locale: "en", kind: "magiclink", token: CODE });
  assertStringIncludes(en.text, MAIL_EN.validity);
  assertStringIncludes(en.text, MAIL_EN.ignore);
  assertStringIncludes(en.html, escapeHtml(MAIL_EN.ignore));
  assert(!en.text.includes("Wenn du das nicht warst"));
});

Deno.test("HTML shows the code in large type and is a complete document", () => {
  const mail = renderMail({ locale: "en", kind: "signup", token: CODE });
  assertStringIncludes(mail.html, "<!doctype html>");
  assertStringIncludes(mail.html, '<html lang="en">');
  assertStringIncludes(mail.html, "font-size:32px");
  assertStringIncludes(mail.html, ">123456</p>");
  assert(!mail.html.includes("<img"), "no images");
  assert(!mail.html.includes("<link"), "no external CSS");
  assert(!/src=|href=/.test(mail.html), "no remote resources or links");
});

Deno.test("HTML is built for every mail client: tables, inline styles, light colours", () => {
  const mail = renderMail({ locale: "de", kind: "signup", token: CODE });
  assertStringIncludes(mail.html, 'role="presentation"');
  assertStringIncludes(mail.html, "<!--[if mso]>");
  assertStringIncludes(mail.html, 'name="color-scheme" content="light"');
  assertStringIncludes(mail.html, 'name="viewport"');
  assert(!mail.html.includes("<style"), "inline styles only");
  assert(!mail.html.includes("<script"), "no scripts");
  // The heading names the action; the preview line is the lead, hidden in the body.
  assertStringIncludes(mail.html, `>${MAIL_DE.heading.signup}</h1>`);
  assertStringIncludes(mail.html, "display:none");
  assertStringIncludes(mail.html, MAIL_DE.instruction);
  assertStringIncludes(mail.html, MAIL_DE.footer);
});

Deno.test("text part: heading, code on its own line, instruction and footer", () => {
  const mail = renderMail({ locale: "en", kind: "signup", token: CODE });
  assert(mail.text.startsWith(`${MAIL_EN.heading.signup}\n`));
  assertStringIncludes(mail.text, `\n${CODE}\n`);
  assertStringIncludes(mail.text, MAIL_EN.instruction);
  assertStringIncludes(mail.text, `\n-- \n${MAIL_EN.footer}`);
});

Deno.test("every language and mail kind uses only its own wording", () => {
  for (const locale of MAIL_LOCALES) {
    const messages = MESSAGES[locale];
    for (const kind of MAIL_KINDS) {
      const mail = renderMail({ locale, kind, token: CODE });
      assertEquals(mail.subject, `${messages.subject[kind]}: ${CODE}`);
      assertStringIncludes(mail.text, messages.heading[kind]);
      assertStringIncludes(mail.text, messages.lead[kind]);
      assertStringIncludes(mail.text, messages.validity);
      assertStringIncludes(mail.text, messages.ignore);
      assertStringIncludes(mail.html, escapeHtml(messages.heading[kind]));
      assertStringIncludes(mail.html, escapeHtml(messages.ignore));
      assertStringIncludes(mail.html, `<html lang="${locale}">`);
      assert(!/src=|href=/.test(mail.html));
      for (const other of MAIL_LOCALES.filter((l) => l !== locale)) {
        assert(!mail.text.includes(MESSAGES[other].instruction));
        assert(!mail.html.includes(escapeHtml(MESSAGES[other].instruction)));
      }
    }
  }
});

Deno.test("fallback templates cover every GoTrue SMTP template action", () => {
  assertEquals<Record<string, string>>(FALLBACK_TEMPLATES, {
    magiclink: "magic_link.html",
    signup: "confirmation.html",
    recovery: "recovery.html",
    email_change: "email_change.html",
    reauthentication: "reauthentication.html",
    invite: "invite.html",
  });
});

Deno.test("fallback templates: committed files match the renderer", async () => {
  for (const [kind, file] of Object.entries(FALLBACK_TEMPLATES)) {
    const committed = await Deno.readTextFile(
      new URL(`../../templates/${file}`, import.meta.url),
    );
    assertEquals(
      committed,
      renderFallbackTemplate(kind as FallbackTemplateKind),
      `supabase/templates/${file} is stale: run deno run --allow-write ` +
        "supabase/functions/_shared/mail_templates_write.ts",
    );
    for (const locale of MAIL_LOCALES) {
      const localized = await Deno.readTextFile(
        new URL(`../../templates/${locale}/${file}`, import.meta.url),
      );
      assertEquals(
        localized,
        renderFallbackTemplate(kind as FallbackTemplateKind, locale),
      );
      if (locale === "de") assertEquals(localized, committed);
    }
  }
});

Deno.test("fallback subjects and bodies are monolingual for every locale and kind", () => {
  assertEquals(fallbackSubject(), FALLBACK_SUBJECT);
  assertEquals(MAIL_LOCALES.map(fallbackSubject), [
    "Dein WuselWall-Code",
    "Your WuselWall code",
    "Votre code WuselWall",
    "Tu código de WuselWall",
  ]);
  for (const locale of MAIL_LOCALES) {
    const messages = MESSAGES[locale];
    for (
      const kind of Object.keys(FALLBACK_TEMPLATES) as FallbackTemplateKind[]
    ) {
      const html = renderFallbackTemplate(kind, locale);
      assertStringIncludes(html, `<html lang="${locale}">`);
      assertStringIncludes(
        html,
        `<title>${escapeHtml(fallbackSubject(locale))}</title>`,
      );
      assertStringIncludes(html, escapeHtml(messages.heading[kind]));
      assertStringIncludes(html, escapeHtml(messages.lead[kind]));
      assertStringIncludes(html, escapeHtml(messages.footer));
      assertEquals(html.split("{{ .Token }}").length - 1, 1);
      assertEquals(html.match(/\{\{.*?\}\}/g), ["{{ .Token }}"]);
      assertEquals(html.split("<h1 ").length - 1, 1);
      assert(!/src=|href=/.test(html));
      for (const other of MAIL_LOCALES.filter((l) => l !== locale)) {
        assert(!html.includes(escapeHtml(MESSAGES[other].instruction)));
        assert(!html.includes(escapeHtml(MESSAGES[other].footer)));
      }
    }
  }
});

Deno.test("fallback templates: German only by default, GoTrue's code once", () => {
  const html = renderFallbackTemplate("signup");
  assertStringIncludes(html, MAIL_DE.heading.signup);
  assert(!html.includes(MAIL_EN.heading.signup), "no English card");
  assertEquals(html.split("{{ .Token }}").length - 1, 1);
  assertEquals(FALLBACK_SUBJECT, "Dein WuselWall-Code");
  assertStringIncludes(html, `<title>${FALLBACK_SUBJECT}</title>`);
  assert(!/src=|href=/.test(html), "no remote resources or links");
});

Deno.test("recovery, reauthentication: a code, the right subject and wording", () => {
  const recovery = renderMail({ locale: "de", kind: "recovery", token: CODE });
  assertEquals(
    recovery.subject,
    "Dein WuselWall-Code zum Zurücksetzen: 123456",
  );
  assertStringIncludes(recovery.text, MAIL_DE.lead.recovery);

  const reauth = renderMail({
    locale: "en",
    kind: "reauthentication",
    token: CODE,
  });
  assertEquals(reauth.subject, "Your WuselWall code to confirm: 123456");
  assertStringIncludes(reauth.text, MAIL_EN.lead.reauthentication);
});

Deno.test("email_change with both codes: each labelled, the new one too", () => {
  for (const locale of MAIL_LOCALES) {
    const messages = MESSAGES[locale];
    const mail = renderMail({
      locale,
      kind: "email_change",
      token: "111111",
      tokenNew: "222222",
    });
    assertEquals(mail.subject, `${messages.subject.email_change}: 111111`);
    assertStringIncludes(mail.text, `${messages.codeLabelOld}: 111111`);
    assertStringIncludes(mail.text, `${messages.codeLabelNew}: 222222`);
    assertStringIncludes(mail.html, "222222");
    assertStringIncludes(mail.html, escapeHtml(messages.codeLabelNew));
  }
});

Deno.test("email_change with one code: no labels", () => {
  const mail = renderMail({ locale: "en", kind: "email_change", token: CODE });
  assert(!mail.text.includes(MAIL_EN.codeLabelOld));
  assert(!mail.text.includes(MAIL_EN.codeLabelNew));
  assertStringIncludes(mail.text, `\n${CODE}\n`);
});

Deno.test("invite: with a code it shows the code, without one it still renders", () => {
  for (const locale of MAIL_LOCALES) {
    const messages = MESSAGES[locale];
    const withCode = renderMail({ locale, kind: "invite", token: CODE });
    assertEquals(withCode.subject, `${messages.subject.invite}: ${CODE}`);
    assertStringIncludes(withCode.text, CODE);

    const without = renderMail({ locale, kind: "invite" });
    assertEquals(without.subject, messages.subject.invite);
    assertStringIncludes(without.text, messages.lead.invite);
    assert(!without.text.includes(messages.validity));
  }
});

Deno.test("a code kind without a code is refused", () => {
  for (const kind of MAIL_KINDS.filter((k) => k !== "invite")) {
    assertThrows(
      () => renderMail({ locale: "de", kind: kind as MailKind }),
      MailRenderError,
      "no code",
    );
  }
});

Deno.test("an unknown action is refused", () => {
  assert(!isMailKind("password_changed_notification"));
  assertThrows(
    () =>
      renderMail({ locale: "de", kind: "nonsense" as MailKind, token: CODE }),
    MailRenderError,
    "unknown",
  );
});

Deno.test("user-provided values are HTML-escaped", () => {
  assertEquals(
    escapeHtml(`<a href="x">'&'</a>`),
    "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;",
  );
  // A hostile code is escaped in the HTML; the text body carries it verbatim, as text does.
  const hostile = `<script>alert(1)</script>`;
  const mail = renderMail({
    locale: "en",
    kind: "magiclink",
    token: hostile,
    tokenNew: undefined,
  });
  assert(!mail.html.includes("<script>"));
  assertStringIncludes(mail.html, "&lt;script&gt;alert(1)&lt;/script&gt;");
  assertStringIncludes(mail.html, "<title>Your WuselWall code: &lt;script&gt;");
});

Deno.test("every language and kind renders the code in all three parts", () => {
  for (const locale of MAIL_LOCALES) {
    for (const kind of MAIL_KINDS.filter((k) => k !== "invite")) {
      const mail = renderMail({ locale, kind, token: "654321" });
      assertStringIncludes(mail.subject, "654321");
      assertStringIncludes(mail.text, "654321");
      assertStringIncludes(mail.html, "654321");
    }
  }
});

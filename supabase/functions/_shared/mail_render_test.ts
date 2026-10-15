import {
  assert,
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "jsr:@std/assert@1.0.13";
import {
  escapeHtml,
  isMailKind,
  MAIL_KINDS,
  type MailKind,
  MailRenderError,
  renderMail,
  resolveLocale,
} from "./mail_render.ts";
import { MAIL_DE } from "./mail_de.ts";
import { MAIL_EN } from "./mail_en.ts";

const CODE = "123456";

Deno.test("resolveLocale: de and en, German for anything else", () => {
  assertEquals(resolveLocale("en"), "en");
  assertEquals(resolveLocale("en-GB"), "en");
  assertEquals(resolveLocale("EN_us"), "en");
  assertEquals(resolveLocale("de"), "de");
  assertEquals(resolveLocale("de-CH"), "de");
  assertEquals(resolveLocale("fr"), "de");
  assertEquals(resolveLocale(undefined), "de");
  assertEquals(resolveLocale(42), "de");
});

Deno.test("both message files define every kind and key", () => {
  for (const messages of [MAIL_DE, MAIL_EN]) {
    for (const kind of MAIL_KINDS) {
      assert(messages.subject[kind].length > 0, `subject ${kind}`);
      assert(messages.lead[kind].length > 0, `lead ${kind}`);
    }
    assert(messages.codeLabelOld && messages.codeLabelNew && messages.validity);
    assert(messages.ignore && messages.greeting && messages.signoff);
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
  const mail = renderMail({
    locale: "de",
    kind: "email_change",
    token: "111111",
    tokenNew: "222222",
  });
  assertEquals(mail.subject, "Dein WuselWall-Code zur Adressänderung: 111111");
  assertStringIncludes(mail.text, `${MAIL_DE.codeLabelOld}: 111111`);
  assertStringIncludes(mail.text, `${MAIL_DE.codeLabelNew}: 222222`);
  assertStringIncludes(mail.html, "222222");
  assertStringIncludes(mail.html, MAIL_DE.codeLabelNew);
});

Deno.test("email_change with one code: no labels", () => {
  const mail = renderMail({ locale: "en", kind: "email_change", token: CODE });
  assert(!mail.text.includes(MAIL_EN.codeLabelOld));
  assert(!mail.text.includes(MAIL_EN.codeLabelNew));
  assertStringIncludes(mail.text, `\n${CODE}\n`);
});

Deno.test("invite: with a code it shows the code, without one it still renders", () => {
  const withCode = renderMail({ locale: "de", kind: "invite", token: CODE });
  assertEquals(withCode.subject, "Einladung zu WuselWall: 123456");
  assertStringIncludes(withCode.text, CODE);

  const without = renderMail({ locale: "de", kind: "invite" });
  assertEquals(without.subject, "Einladung zu WuselWall");
  assertStringIncludes(without.text, MAIL_DE.lead.invite);
  assert(!without.text.includes(MAIL_DE.validity));
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
  for (const locale of ["de", "en"] as const) {
    for (const kind of MAIL_KINDS.filter((k) => k !== "invite")) {
      const mail = renderMail({ locale, kind, token: "654321" });
      assertStringIncludes(mail.subject, "654321");
      assertStringIncludes(mail.text, "654321");
      assertStringIncludes(mail.html, "654321");
    }
  }
});

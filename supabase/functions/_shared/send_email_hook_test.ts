import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "jsr:@std/assert@1.0.13";
import {
  type HookSettings,
  REQUIRED_ENV,
  sendEmailHook,
  settingsFromEnv,
} from "./send_email_hook.ts";
import { decodeSecret, sign } from "./webhook_signature.ts";
import { MAIL_KINDS, MAIL_LOCALES, renderMail } from "./mail_render.ts";

const SECRET = "v1,whsec_d3VzZWx3YWxsLWhvb2stdGVzdC1rZXktMDEyMzQ1Njc4OQ==";
const settings: HookSettings = {
  hookSecret: SECRET,
  scaleway: {
    secretKey: "scw-secret-test",
    projectId: "11111111-2222-3333-4444-555555555555",
    region: "fr-par",
    fromEmail: "codes@example.org",
    fromName: "WuselWall",
  },
};

/** A GoTrue-shaped payload with the fields the hook reads. */
function payload(opts: {
  email?: string;
  locale?: string | null;
  kind?: string;
  token?: string;
  tokenNew?: string;
} = {}) {
  const meta: Record<string, unknown> = {};
  if (opts.locale !== null) meta.locale = opts.locale ?? "en";
  return {
    user: {
      id: "5f1c0e8a-0000-4000-8000-000000000001",
      email: opts.email ?? "anna@example.com",
      user_metadata: meta,
    },
    email_data: {
      token: opts.token ?? "123456",
      token_hash: "a".repeat(32),
      redirect_to: "https://web.wuselwall.app/",
      email_action_type: opts.kind ?? "magiclink",
      site_url: "https://web.wuselwall.app/",
      token_new: opts.tokenNew ?? "",
      token_hash_new: "",
    },
  };
}

/** A request signed the way GoTrue signs it, with the current time. */
async function signed(
  body: string,
  opts: { secret?: string; ts?: number; id?: string } = {},
) {
  const id = opts.id ?? "msg_test_1";
  const ts = String(opts.ts ?? Math.floor(Date.now() / 1000));
  const sig = await sign(decodeSecret(opts.secret ?? SECRET), id, ts, body);
  return new Request("https://functions.test/send-email", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "webhook-id": id,
      "webhook-timestamp": ts,
      "webhook-signature": `v1,${sig}`,
    },
    body,
  });
}

/** A fetch fake that answers the provider with `status` and records what it was sent. */
function provider(status = 201, body = "{}") {
  const sent: Array<
    {
      url: string;
      headers: Headers;
      json: {
        to: unknown;
        from: unknown;
        project_id: unknown;
        subject: unknown;
        text: string;
        html: string;
      };
    }
  > = [];
  const fn = ((input: string | URL | Request, init?: RequestInit) => {
    sent.push({
      url: String(input),
      headers: new Headers(init?.headers),
      json: JSON.parse(String(init?.body)) as {
        to: unknown;
        from: unknown;
        project_id: unknown;
        subject: unknown;
        text: string;
        html: string;
      },
    });
    return Promise.resolve(new Response(body, { status }));
  }) as typeof fetch;
  return { fn, sent };
}

async function errorOf(res: Response) {
  const json = await res.json();
  return json.error as { http_code: number; message: string };
}

Deno.test("a signed magic-link mail uses the English server setting and is sent through Scaleway", async () => {
  const { fn, sent } = provider();
  const res = await sendEmailHook(
    await signed(JSON.stringify(payload({ locale: "de" }))),
    { ...settings, locale: "en" },
    fn,
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {});
  assertEquals(sent.length, 1);
  assertEquals(
    sent[0].url,
    "https://api.scaleway.com/transactional-email/v1alpha1/regions/fr-par/emails",
  );
  assertEquals(sent[0].headers.get("X-Auth-Token"), "scw-secret-test");
  assertEquals(sent[0].json.to, [{ email: "anna@example.com" }]);
  assertEquals(sent[0].json.from, {
    email: "codes@example.org",
    name: "WuselWall",
  });
  assertEquals(sent[0].json.project_id, "11111111-2222-3333-4444-555555555555");
  assertEquals(sent[0].json.subject, "Your WuselWall code: 123456");
  assertStringIncludes(sent[0].json.text, "123456");
  assertStringIncludes(sent[0].json.html, "123456");
});

Deno.test("German is the default server language even when the recipient asks for English", async () => {
  const { fn, sent } = provider();
  const body = payload({ locale: "en" });
  await sendEmailHook(await signed(JSON.stringify(body)), settings, fn);
  assertEquals(sent[0].json.subject, "Dein WuselWall-Code: 123456");
});

Deno.test("the German server setting overrides English user_metadata", async () => {
  const { fn, sent } = provider();
  await sendEmailHook(
    await signed(JSON.stringify(payload({ locale: "en" }))),
    { ...settings, locale: "de" },
    fn,
  );
  assertEquals(sent[0].json.subject, "Dein WuselWall-Code: 123456");
  assertStringIncludes(sent[0].json.text, "10 Minuten gültig");
});

Deno.test("every configured server language overrides contrary recipient metadata for every mail kind", async () => {
  const env: Record<string, string> = {
    SEND_EMAIL_HOOK_SECRET: SECRET,
    SCW_SECRET_KEY: "k",
    SCW_PROJECT_ID: "p",
    MAIL_FROM: "codes@example.org",
  };
  for (const locale of MAIL_LOCALES) {
    const loaded = settingsFromEnv((name) =>
      name === "MAIL_LANGUAGE" ? locale : env[name]
    );
    assert(loaded.ok);
    for (const kind of MAIL_KINDS) {
      const { fn, sent } = provider();
      const recipientLocale = locale === "en" ? "de" : "en";
      const res = await sendEmailHook(
        await signed(
          JSON.stringify(payload({ kind, locale: recipientLocale })),
        ),
        loaded.settings,
        fn,
      );
      assertEquals(res.status, 200);
      assertEquals(await res.json(), {});
      assertEquals(sent.length, 1);
      const expected = renderMail({ locale, kind, token: "123456" });
      assertEquals(sent[0].json.subject, expected.subject);
      assertEquals(sent[0].json.text, expected.text);
      assertEquals(sent[0].json.html, expected.html);
    }
  }
});

Deno.test("an email change with both codes sends both", async () => {
  const { fn, sent } = provider();
  const body = payload({
    kind: "email_change",
    token: "111111",
    tokenNew: "222222",
    locale: "de",
  });
  await sendEmailHook(await signed(JSON.stringify(body)), settings, fn);
  assertStringIncludes(sent[0].json.text, "111111");
  assertStringIncludes(sent[0].json.text, "222222");
});

Deno.test("a bad signature is a 401 and nothing is sent", async () => {
  const { fn, sent } = provider();
  const other = "v1,whsec_" + btoa("a-different-key-entirely-here!!");
  const req = await signed(JSON.stringify(payload()), { secret: other });
  const res = await sendEmailHook(req, settings, fn);
  assertEquals(res.status, 401);
  assertEquals((await errorOf(res)).http_code, 401);
  assertEquals(sent.length, 0);
});

Deno.test("a request older than five minutes is refused", async () => {
  const { fn, sent } = provider();
  const old = Math.floor(Date.now() / 1000) - 600;
  const res = await sendEmailHook(
    await signed(JSON.stringify(payload()), { ts: old }),
    settings,
    fn,
  );
  assertEquals(res.status, 401);
  assertEquals(sent.length, 0);
});

Deno.test("a request without the signature headers is refused", async () => {
  const { fn, sent } = provider();
  const req = new Request("https://functions.test/send-email", {
    method: "POST",
    body: JSON.stringify(payload()),
  });
  const res = await sendEmailHook(req, settings, fn);
  assertEquals(res.status, 401);
  assertEquals(sent.length, 0);
});

Deno.test("GET is a 405", async () => {
  const { fn } = provider();
  const res = await sendEmailHook(
    new Request("https://functions.test/send-email"),
    settings,
    fn,
  );
  assertEquals(res.status, 405);
});

Deno.test("a signed body that is not JSON is a 400", async () => {
  const { fn, sent } = provider();
  const res = await sendEmailHook(await signed("not json"), settings, fn);
  assertEquals(res.status, 400);
  assertEquals(sent.length, 0);
});

Deno.test("a signed payload without a user email is a 400", async () => {
  const { fn, sent } = provider();
  const body = payload();
  (body.user as Record<string, unknown>).email = "";
  const res = await sendEmailHook(
    await signed(JSON.stringify(body)),
    settings,
    fn,
  );
  assertEquals(res.status, 400);
  assertEquals(sent.length, 0);
});

Deno.test("an unknown email action is a 400", async () => {
  const { fn, sent } = provider();
  const res = await sendEmailHook(
    await signed(JSON.stringify(payload({ kind: "something_new" }))),
    settings,
    fn,
  );
  assertEquals(res.status, 400);
  assertEquals(sent.length, 0);
});

Deno.test("a notification about a past change is accepted and not sent", async () => {
  const { fn, sent } = provider();
  const res = await sendEmailHook(
    await signed(
      JSON.stringify(
        payload({ kind: "password_changed_notification", token: "" }),
      ),
    ),
    settings,
    fn,
  );
  assertEquals(res.status, 200);
  assertEquals(sent.length, 0);
});

Deno.test("a code mail without a code is a 400", async () => {
  const { fn, sent } = provider();
  const res = await sendEmailHook(
    await signed(JSON.stringify(payload({ token: "" }))),
    settings,
    fn,
  );
  assertEquals(res.status, 400);
  assertEquals(sent.length, 0);
});

Deno.test("a provider refusal is a 502 with the error shape, and no code or address in the answer", async () => {
  const { fn } = provider(403, "forbidden for anna@example.com code 123456");
  const res = await sendEmailHook(
    await signed(JSON.stringify(payload())),
    settings,
    fn,
  );
  assertEquals(res.status, 502);
  const text = JSON.stringify(await res.clone().json());
  const error = await errorOf(res);
  assertEquals(error.http_code, 502);
  assert(error.message.length > 0);
  assert(!text.includes("anna@example.com"));
  assert(!text.includes("123456"));
});

Deno.test("a malformed secret in the environment is a 500, reported as configuration", async () => {
  const { fn, sent } = provider();
  const bad = { ...settings, hookSecret: "whsec_not-the-right-form" };
  const res = await sendEmailHook(
    await signed(JSON.stringify(payload())),
    bad,
    fn,
  );
  assertEquals(res.status, 500);
  assertEquals(sent.length, 0);
});

Deno.test("settingsFromEnv names the missing variables and never their values", () => {
  const full: Record<string, string> = {
    SEND_EMAIL_HOOK_SECRET: SECRET,
    SCW_SECRET_KEY: "k",
    SCW_PROJECT_ID: "p",
    MAIL_FROM: "codes@example.org",
  };
  const ok = settingsFromEnv((name) => full[name]);
  assert(ok.ok);
  assertEquals(ok.settings.scaleway.region, "fr-par");
  assertEquals(ok.settings.scaleway.fromName, "WuselWall");
  assertEquals(ok.settings.locale, "de");

  const missing = settingsFromEnv((
    name,
  ) => (name === "SCW_PROJECT_ID" ? undefined : full[name]));
  assertEquals(missing, { ok: false, missing: ["SCW_PROJECT_ID"] });

  const none = settingsFromEnv(() => undefined);
  assertEquals(none, { ok: false, missing: [...REQUIRED_ENV] });
});

Deno.test("settingsFromEnv accepts exactly the four MAIL_LANGUAGE values", () => {
  const env: Record<string, string> = {
    SEND_EMAIL_HOOK_SECRET: SECRET,
    SCW_SECRET_KEY: "k",
    SCW_PROJECT_ID: "p",
    MAIL_FROM: "codes@example.org",
  };
  for (const locale of ["de", "en", "fr", "es"]) {
    const loaded = settingsFromEnv((name) =>
      name === "MAIL_LANGUAGE" ? locale : env[name]
    );
    assert(loaded.ok);
    assertEquals(loaded.settings.locale, locale);
  }
});

Deno.test("settingsFromEnv refuses invalid MAIL_LANGUAGE without echoing its value or secrets", () => {
  const env: Record<string, string> = {
    SEND_EMAIL_HOOK_SECRET: SECRET,
    SCW_SECRET_KEY: "secret-that-must-not-leak",
    SCW_PROJECT_ID: "p",
    MAIL_FROM: "codes@example.org",
  };
  for (
    const language of [
      "it",
      "EN",
      "en-GB",
      " de ",
      "",
      "secret-that-must-not-leak",
    ]
  ) {
    const loaded = settingsFromEnv((name) =>
      name === "MAIL_LANGUAGE" ? language : env[name]
    );
    assertEquals(loaded, { ok: false, missing: ["MAIL_LANGUAGE"] });
  }
  const missingAndInvalid = settingsFromEnv((name) =>
    name === "MAIL_LANGUAGE" ? "it" : undefined
  );
  assertEquals(missingAndInvalid, {
    ok: false,
    missing: [...REQUIRED_ENV, "MAIL_LANGUAGE"],
  });
});

Deno.test("settingsFromEnv takes region and sender name from the environment when set", () => {
  const env: Record<string, string> = {
    SEND_EMAIL_HOOK_SECRET: SECRET,
    SCW_SECRET_KEY: "k",
    SCW_PROJECT_ID: "p",
    MAIL_FROM: "x@example.org",
    SCW_REGION: "nl-ams",
    MAIL_FROM_NAME: "Familie Test",
  };
  const loaded = settingsFromEnv((name) => env[name]);
  assert(loaded.ok);
  assertEquals(loaded.settings.scaleway.region, "nl-ams");
  assertEquals(loaded.settings.scaleway.fromName, "Familie Test");
});

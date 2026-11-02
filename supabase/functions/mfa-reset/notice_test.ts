import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.13";
import { notifyTarget } from "./notice.ts";
import { MAIL_FR } from "../_shared/mail_fr.ts";

const ENV: Record<string, string> = {
  SCW_SECRET_KEY: "scw-secret-test",
  SCW_PROJECT_ID: "11111111-2222-3333-4444-555555555555",
  MAIL_FROM: "codes@example.org",
  MAIL_LANGUAGE: "fr",
};

/** A fetch fake that answers the provider with `status` and records what it was sent. */
function provider(status = 201) {
  const sent: Array<{ json: { to: unknown; subject: string; text: string; html: string } }> = [];
  const fn = ((_input: string | URL | Request, init?: RequestInit) => {
    sent.push({ json: JSON.parse(String(init?.body)) });
    return Promise.resolve(new Response("{}", { status }));
  }) as typeof fetch;
  return { fn, sent };
}

Deno.test("the notice goes to the target in the server's language, without a code or a link", async () => {
  const { fn, sent } = provider();
  assert(await notifyTarget("ida@example.org", (name) => ENV[name], fn));
  assertEquals(sent.length, 1);
  assertEquals(sent[0].json.to, [{ email: "ida@example.org" }]);
  assertEquals(sent[0].json.subject, MAIL_FR.notice.mfa_reset.subject);
  assertStringIncludes(sent[0].json.text, MAIL_FR.notice.mfa_reset.advice);
  assert(!/href=/.test(sent[0].json.html));
});

Deno.test("without the sender settings, or an address, nothing is sent and nothing throws", async () => {
  const { fn, sent } = provider();
  assertEquals(await notifyTarget("ida@example.org", () => undefined, fn), false);
  assertEquals(await notifyTarget(null, (name) => ENV[name], fn), false);
  assertEquals(await notifyTarget(undefined, (name) => ENV[name], fn), false);
  assertEquals(sent.length, 0);
});

Deno.test("a provider failure is reported as false, never thrown", async () => {
  const { fn, sent } = provider(503);
  assertEquals(await notifyTarget("ida@example.org", (name) => ENV[name], fn), false);
  assertEquals(sent.length, 1);
});

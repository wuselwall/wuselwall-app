import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import {
  emailBody,
  emailsUrl,
  MailSendError,
  type ScalewayConfig,
  sendScalewayMail,
} from "./scaleway_mail.ts";

const config: ScalewayConfig = {
  secretKey: "scw-secret-test",
  projectId: "11111111-2222-3333-4444-555555555555",
  region: "fr-par",
  fromEmail: "codes@example.org",
  fromName: "WuselWall",
};
const mail = {
  to: "anna@example.com",
  subject: "Your WuselWall code: 123456",
  text: "t",
  html: "<p>h</p>",
};

type Call = { url: string; init: RequestInit };

/** A fetch fake that answers with the given status and records the call. */
function fakeFetch(status: number, body = "") {
  const calls: Call[] = [];
  const fn = ((input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(new Response(body, { status }));
  }) as typeof fetch;
  return { fn, calls };
}

Deno.test("emailsUrl: the regional endpoint, and only well-formed regions", () => {
  assertEquals(
    emailsUrl("fr-par"),
    "https://api.scaleway.com/transactional-email/v1alpha1/regions/fr-par/emails",
  );
  for (const bad of ["", "fr", "fr-par/../x", "FR-PAR", "fr-par?x=1"]) {
    let threw = false;
    try {
      emailsUrl(bad);
    } catch {
      threw = true;
    }
    assert(threw, `region ${JSON.stringify(bad)} must be refused`);
  }
});

Deno.test("emailBody: from, to, subject, text, html and project_id in Scaleway's shape", () => {
  const body = emailBody(config, mail) as Record<string, unknown>;
  assertEquals(body, {
    from: { email: "codes@example.org", name: "WuselWall" },
    to: [{ email: "anna@example.com" }],
    subject: "Your WuselWall code: 123456",
    text: "t",
    html: "<p>h</p>",
    project_id: "11111111-2222-3333-4444-555555555555",
  });
});

Deno.test("sends a POST with the secret key in X-Auth-Token and the JSON body", async () => {
  const { fn, calls } = fakeFetch(200, '{"emails":[]}');
  await sendScalewayMail(config, mail, { fetch: fn });
  assertEquals(calls.length, 1);
  assertEquals(
    calls[0].url,
    "https://api.scaleway.com/transactional-email/v1alpha1/regions/fr-par/emails",
  );
  const init = calls[0].init;
  assertEquals(init.method, "POST");
  const headers = new Headers(init.headers);
  assertEquals(headers.get("X-Auth-Token"), "scw-secret-test");
  assertEquals(headers.get("Content-Type"), "application/json");
  assertEquals(JSON.parse(String(init.body)).to, [{
    email: "anna@example.com",
  }]);
  assert(init.signal, "a timeout signal is attached");
});

Deno.test("201 Created counts as sent", async () => {
  const { fn } = fakeFetch(201, "{}");
  await sendScalewayMail(config, mail, { fetch: fn });
});

Deno.test("a 4xx answer is provider_rejected, without the provider's body", async () => {
  const { fn } = fakeFetch(403, "denied for anna@example.com");
  const err = await assertRejects(
    () => sendScalewayMail(config, mail, { fetch: fn }),
    MailSendError,
  );
  assertEquals(err.code, "provider_rejected");
  assertEquals(err.status, 502);
  assertEquals(err.providerStatus, 403);
  assert(
    !err.message.includes("anna"),
    "the address never reaches the error message",
  );
});

Deno.test("a 5xx answer is provider_rejected as well", async () => {
  const { fn } = fakeFetch(500);
  const err = await assertRejects(
    () => sendScalewayMail(config, mail, { fetch: fn }),
    MailSendError,
  );
  assertEquals(err.code, "provider_rejected");
  assertEquals(err.providerStatus, 500);
});

Deno.test("a network failure is provider_unreachable", async () => {
  const fn =
    (() => Promise.reject(new TypeError("connection refused"))) as typeof fetch;
  const err = await assertRejects(
    () => sendScalewayMail(config, mail, { fetch: fn }),
    MailSendError,
  );
  assertEquals(err.code, "provider_unreachable");
  assertEquals(err.status, 502);
});

Deno.test("a request that does not answer in time is provider_timeout (504)", async () => {
  // The fake waits for the abort signal, as fetch does when a timeout fires.
  const fn =
    ((_input: string | URL | Request, init?: RequestInit) =>
      new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () => {
          reject(new DOMException("The operation timed out.", "TimeoutError"));
        });
      })) as typeof fetch;
  const err = await assertRejects(
    () => sendScalewayMail(config, mail, { fetch: fn, timeoutMs: 5 }),
    MailSendError,
  );
  assertEquals(err.code, "provider_timeout");
  assertEquals(err.status, 504);
});

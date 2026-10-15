import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.13";
import {
  assertPublicHost,
  fetchFeed,
  FetchError,
  isForbiddenAddress,
  isForbiddenHostname,
  isForbiddenIPv4,
  isForbiddenIPv6,
  normaliseFeedUrl,
  type Resolver,
} from "./safe_fetch.ts";

/** A resolver that answers the given addresses for every host. */
const answers = (...ips: string[]): Resolver => () => Promise.resolve(ips);

/** A fetch fake that replays the responses in order and records each request. */
function scripted(responses: Array<Response | (() => Response)>) {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  let i = 0;
  const fake = (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    const next = responses[i++];
    if (next === undefined) throw new Error("no more scripted responses");
    return Promise.resolve(typeof next === "function" ? next() : next.clone());
  };
  return { fetch: fake as typeof fetch, calls };
}

const ICS = "BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n";
const ok = (body = ICS, headers: Record<string, string> = {}) =>
  new Response(body, { status: 200, headers: { "content-type": "text/calendar", ...headers } });
const redirect = (location: string, status = 301) =>
  new Response(null, { status, headers: { location } });

async function codeOf(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (err) {
    if (err instanceof FetchError) return err.code;
    throw err;
  }
  throw new Error("expected a FetchError");
}

// ---------------------------------------------------------------- IPv4

Deno.test("IPv4: the private, loopback, link-local and CGNAT ranges are refused", () => {
  for (
    const ip of [
      "0.0.0.0",
      "0.1.2.3",
      "10.0.0.1",
      "10.255.255.255",
      "127.0.0.1",
      "127.255.0.9",
      "100.64.0.1",
      "100.127.255.254",
      "169.254.169.254",
      "172.16.0.1",
      "172.31.255.255",
      "192.168.1.1",
      "192.0.0.8",
      "198.18.0.1",
      "224.0.0.1",
      "239.255.255.250",
      "240.0.0.1",
      "255.255.255.255",
    ]
  ) {
    assert(isForbiddenIPv4(ip), `${ip} should be refused`);
  }
});

Deno.test("IPv4: public addresses and the edges of the private ranges are allowed", () => {
  for (
    const ip of [
      "1.1.1.1",
      "8.8.8.8",
      "93.184.216.34",
      "100.63.255.255", // just below CGNAT
      "100.128.0.1", // just above CGNAT
      "172.15.255.255", // just below 172.16/12
      "172.32.0.1", // just above 172.16/12
      "192.167.0.1",
      "192.169.0.1",
      "169.253.0.1",
      "11.0.0.1",
    ]
  ) {
    assertEquals(isForbiddenIPv4(ip), false, `${ip} should be allowed`);
  }
});

Deno.test("IPv4: text that is not an IPv4 address is refused, not guessed", () => {
  assert(isForbiddenIPv4("256.1.1.1"));
  assert(isForbiddenIPv4("1.2.3"));
  assert(isForbiddenIPv4("a.b.c.d"));
});

// ---------------------------------------------------------------- IPv6

Deno.test("IPv6: loopback, unspecified, unique-local, link-local and multicast are refused", () => {
  for (
    const ip of [
      "::",
      "::1",
      "0:0:0:0:0:0:0:1",
      "fc00::1",
      "fd12:3456:789a::1",
      "fe80::1",
      "fe80::1%eth0",
      "febf::1",
      "ff02::1",
      "2001:db8::1",
    ]
  ) {
    assert(isForbiddenIPv6(ip), `${ip} should be refused`);
  }
});

Deno.test("IPv6: IPv4-mapped, compatible and NAT64 addresses are judged by the IPv4 inside", () => {
  assert(isForbiddenIPv6("::ffff:127.0.0.1"));
  assert(isForbiddenIPv6("::ffff:10.1.2.3"));
  assert(isForbiddenIPv6("::ffff:7f00:1"));
  assert(isForbiddenIPv6("::10.0.0.1"));
  assert(isForbiddenIPv6("64:ff9b::a9fe:a9fe"));
  assertEquals(isForbiddenIPv6("::ffff:8.8.8.8"), false);
  assertEquals(isForbiddenIPv6("64:ff9b::808:808"), false);
});

Deno.test("IPv6: public unicast addresses are allowed", () => {
  for (const ip of ["2606:4700:4700::1111", "2a00:1450:4001::200e", "2001:4860:4860::8888"]) {
    assertEquals(isForbiddenIPv6(ip), false, `${ip} should be allowed`);
  }
});

Deno.test("IPv6: malformed text is refused", () => {
  assert(isForbiddenIPv6("1::2::3"));
  assert(isForbiddenIPv6("12345::1"));
  assert(isForbiddenIPv6("1:2:3"));
  assert(isForbiddenIPv6("gggg::1"));
});

Deno.test("isForbiddenAddress picks the family by the separator", () => {
  assert(isForbiddenAddress("127.0.0.1"));
  assert(isForbiddenAddress("::1"));
  assertEquals(isForbiddenAddress("1.1.1.1"), false);
});

// ---------------------------------------------------------------- names and URLs

Deno.test("host names: localhost, the local and internal suffixes and single labels are refused", () => {
  for (
    const h of [
      "localhost",
      "LOCALHOST",
      "localhost.",
      "api.localhost",
      "printer.local",
      "nas.home.internal",
      "box.localdomain",
      "intranet",
      "",
    ]
  ) {
    assert(isForbiddenHostname(h), `${h} should be refused`);
  }
  assertEquals(isForbiddenHostname("club.example.org"), false);
  assertEquals(isForbiddenHostname("abfall.stadt-zuerich.ch"), false);
});

Deno.test("URLs: https only, webcal normalised, userinfo refused", () => {
  assertEquals(normaliseFeedUrl("webcal://a.example.org/x.ics")?.href, "https://a.example.org/x.ics");
  assertEquals(normaliseFeedUrl("WEBCAL://a.example.org/x.ics")?.href, "https://a.example.org/x.ics");
  assertEquals(normaliseFeedUrl("  https://a.example.org/x.ics  ")?.href, "https://a.example.org/x.ics");
  assertEquals(normaliseFeedUrl("http://a.example.org/x.ics"), null);
  assertEquals(normaliseFeedUrl("ftp://a.example.org/x.ics"), null);
  assertEquals(normaliseFeedUrl("file:///etc/passwd"), null);
  assertEquals(normaliseFeedUrl("https://user:pw@a.example.org/x.ics"), null);
  assertEquals(normaliseFeedUrl("not a url"), null);
});

// ---------------------------------------------------------------- the host check

Deno.test("assertPublicHost: a name resolving to a private address is refused", async () => {
  const url = new URL("https://club.example.org/a.ics");
  assertEquals(await codeOf(assertPublicHost(url, answers("93.184.216.34", "10.0.0.5"))), "forbidden_host");
  assertEquals(await codeOf(assertPublicHost(url, answers("169.254.169.254"))), "forbidden_host");
  assertEquals(await codeOf(assertPublicHost(url, answers("::1"))), "forbidden_host");
});

Deno.test("assertPublicHost: a name without an address is unreachable", async () => {
  const url = new URL("https://club.example.org/a.ics");
  assertEquals(await codeOf(assertPublicHost(url, answers())), "unreachable");
  const failing: Resolver = () => Promise.reject(new Error("NXDOMAIN"));
  assertEquals(await codeOf(assertPublicHost(url, failing)), "unreachable");
});

Deno.test("assertPublicHost: an IP literal is checked without a lookup", async () => {
  let looked = false;
  const resolve: Resolver = () => {
    looked = true;
    return Promise.resolve(["1.1.1.1"]);
  };
  assertEquals(await codeOf(assertPublicHost(new URL("https://127.0.0.1/a.ics"), resolve)), "forbidden_host");
  assertEquals(await codeOf(assertPublicHost(new URL("https://[::1]/a.ics"), resolve)), "forbidden_host");
  assertEquals(looked, false);
  await assertPublicHost(new URL("https://[2606:4700:4700::1111]/a.ics"), resolve);
  assertEquals(looked, false);
});

Deno.test("assertPublicHost: a public name passes", async () => {
  await assertPublicHost(new URL("https://club.example.org/a.ics"), answers("93.184.216.34"));
});

// ---------------------------------------------------------------- the fetch

Deno.test("fetchFeed: a plain http URL is refused before any request", async () => {
  const s = scripted([]);
  assertEquals(
    await codeOf(fetchFeed("http://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "forbidden_host",
  );
  assertEquals(s.calls.length, 0);
});

Deno.test("fetchFeed: a private host is refused before any request", async () => {
  const s = scripted([]);
  assertEquals(
    await codeOf(fetchFeed("https://192.168.1.10/a.ics", { fetch: s.fetch, resolve: answers() })),
    "forbidden_host",
  );
  assertEquals(
    await codeOf(fetchFeed("https://nas.local/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "forbidden_host",
  );
  assertEquals(s.calls.length, 0);
});

Deno.test("fetchFeed: sends the user agent, no credentials and If-None-Match, and returns the body and etag", async () => {
  const s = scripted([ok(ICS, { etag: '"v2"' })]);
  const result = await fetchFeed("webcal://club.example.org/a.ics", {
    fetch: s.fetch,
    resolve: answers("93.184.216.34"),
    etag: '"v1"',
  });
  assertEquals(result, { kind: "ok", body: ICS, etag: '"v2"' });
  assertEquals(s.calls[0].url, "https://club.example.org/a.ics");
  const headers = s.calls[0].init.headers as Record<string, string>;
  assertEquals(headers["User-Agent"], "WuselWall calendar-import (+https://wuselwall.app)");
  assertEquals(headers["If-None-Match"], '"v1"');
  assertEquals(s.calls[0].init.redirect, "manual");
  assertEquals(s.calls[0].init.credentials, "omit");
});

Deno.test("fetchFeed: a 304 with the stored etag is not modified", async () => {
  const s = scripted([new Response(null, { status: 304 })]);
  assertEquals(
    await fetchFeed("https://club.example.org/a.ics", {
      fetch: s.fetch,
      resolve: answers("93.184.216.34"),
      etag: '"v1"',
    }),
    { kind: "not_modified", etag: '"v1"' },
  );
});

Deno.test("fetchFeed: a 304 that was not asked for is an error", async () => {
  const s = scripted([new Response(null, { status: 304 })]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "http_304",
  );
});

Deno.test("fetchFeed: error statuses become http_<status>", async () => {
  for (const status of [404, 410, 500, 503]) {
    const s = scripted([new Response("nope", { status })]);
    assertEquals(
      await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
      `http_${status}`,
    );
  }
});

Deno.test("fetchFeed: a redirect to a private host is refused and the private host is never requested", async () => {
  const s = scripted([redirect("https://intranet.example.org/a.ics")]);
  const resolve: Resolver = (host) =>
    Promise.resolve(host === "club.example.org" ? ["93.184.216.34"] : ["192.168.0.20"]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve })),
    "forbidden_host",
  );
  assertEquals(s.calls.map((c) => c.url), ["https://club.example.org/a.ics"]);
});

Deno.test("fetchFeed: a redirect to a literal private address is refused without a lookup", async () => {
  const s = scripted([redirect("https://169.254.169.254/latest/meta-data/")]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "forbidden_host",
  );
  assertEquals(s.calls.length, 1);
});

Deno.test("fetchFeed: a redirect to http is refused", async () => {
  const s = scripted([redirect("http://club.example.org/a.ics")]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "forbidden_host",
  );
});

Deno.test("fetchFeed: a relative redirect stays on the same host and is followed", async () => {
  const s = scripted([redirect("/feeds/current.ics", 302), ok()]);
  const result = await fetchFeed("https://club.example.org/a.ics", {
    fetch: s.fetch,
    resolve: answers("93.184.216.34"),
  });
  assertEquals(result.kind, "ok");
  assertEquals(s.calls[1].url, "https://club.example.org/feeds/current.ics");
});

Deno.test("fetchFeed: three redirects are followed, a fourth is too many", async () => {
  const followed = scripted([
    redirect("https://a.example.org/1"),
    redirect("https://a.example.org/2"),
    redirect("https://a.example.org/3"),
    ok(),
  ]);
  const result = await fetchFeed("https://a.example.org/0", {
    fetch: followed.fetch,
    resolve: answers("93.184.216.34"),
  });
  assertEquals(result.kind, "ok");
  assertEquals(followed.calls.length, 4);

  const endless = scripted([
    redirect("https://a.example.org/1"),
    redirect("https://a.example.org/2"),
    redirect("https://a.example.org/3"),
    redirect("https://a.example.org/4"),
    ok(),
  ]);
  assertEquals(
    await codeOf(fetchFeed("https://a.example.org/0", { fetch: endless.fetch, resolve: answers("93.184.216.34") })),
    "too_many_redirects",
  );
  assertEquals(endless.calls.length, 4);
});

Deno.test("fetchFeed: a redirect without a location is an error", async () => {
  const s = scripted([new Response(null, { status: 302 })]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "http_302",
  );
});

Deno.test("fetchFeed: a location that is not a URL is refused", async () => {
  const s = scripted([redirect("https://[broken")]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers("93.184.216.34") })),
    "forbidden_host",
  );
});

Deno.test("fetchFeed: a declared body over the cap is refused before it is read", async () => {
  const s = scripted([new Response("x", { status: 200, headers: { "content-length": "3000000" } })]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", {
      fetch: s.fetch,
      resolve: answers("93.184.216.34"),
      maxBytes: 2 * 1024 * 1024,
    })),
    "too_large",
  );
});

Deno.test("fetchFeed: a streamed body over the cap is cut off", async () => {
  const chunk = new Uint8Array(1024).fill(65);
  let pulls = 0;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      pulls++;
      if (pulls > 100) {
        controller.close();
        return;
      }
      controller.enqueue(chunk);
    },
  });
  const s = scripted([() => new Response(stream, { status: 200 })]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", {
      fetch: s.fetch,
      resolve: answers("93.184.216.34"),
      maxBytes: 4096,
    })),
    "too_large",
  );
  assert(pulls < 100, "the stream is cancelled at the cap, not read to the end");
});

Deno.test("fetchFeed: a body exactly at the cap is accepted", async () => {
  const body = "x".repeat(4096);
  const s = scripted([ok(body)]);
  const result = await fetchFeed("https://club.example.org/a.ics", {
    fetch: s.fetch,
    resolve: answers("93.184.216.34"),
    maxBytes: 4096,
  });
  assertEquals(result.kind === "ok" && result.body.length, 4096);
});

Deno.test("fetchFeed: a fetch that never answers times out", async () => {
  const fake = (_input: string | URL | Request, init?: RequestInit) =>
    new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => {
        const err = new Error("aborted");
        err.name = "AbortError";
        reject(err);
      });
    });
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", {
      fetch: fake as typeof fetch,
      resolve: answers("93.184.216.34"),
      timeoutMs: 20,
    })),
    "timeout",
  );
});

Deno.test("fetchFeed: a network error is unreachable", async () => {
  const fake = () => Promise.reject(new TypeError("connection refused"));
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", {
      fetch: fake as typeof fetch,
      resolve: answers("93.184.216.34"),
    })),
    "unreachable",
  );
});

Deno.test("fetchFeed: a DNS failure is unreachable and no request is made", async () => {
  const s = scripted([]);
  assertEquals(
    await codeOf(fetchFeed("https://club.example.org/a.ics", { fetch: s.fetch, resolve: answers() })),
    "unreachable",
  );
  assertEquals(s.calls.length, 0);
});

Deno.test("fetchFeed: rejects with a FetchError, never a raw error", async () => {
  await assertRejects(
    () => fetchFeed("ftp://club.example.org/a.ics", { resolve: answers("93.184.216.34") }),
    FetchError,
  );
});

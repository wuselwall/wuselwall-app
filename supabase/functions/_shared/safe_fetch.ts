// Fetching a calendar feed whose URL a household typed (FR-1.9). The server fetches it, so
// this module is the SSRF guard: only https, only public addresses, every redirect hop checked
// again, a timeout, a size cap and no cookies or credentials.
//
// Pure except for the injected `resolve` and `fetch`: the tests pass fakes, the function passes
// Deno.resolveDns and the global fetch. Errors are FetchError with a short code that is stored
// in app.external_calendar.last_error (see the contract in the calendars migration).
//
// Known limit: the address is checked before the connection, not pinned to it, so a host whose
// DNS answer changes between the check and the connection (DNS rebinding) is not caught here.
// The redirect re-check and the public-only answer make that hard to abuse; the family's
// network is the second line (the stack has no route to the home LAN from the public side).

export const FETCH_TIMEOUT_MS = 15_000;
export const MAX_BODY_BYTES = 2 * 1024 * 1024;
export const MAX_REDIRECTS = 3;
export const USER_AGENT = "WuselWall calendar-import (+https://wuselwall.app)";

/** The short code stored in last_error: forbidden_host, unreachable, timeout, too_large, http_<n>, … */
export class FetchError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "FetchError";
  }
}

export type Resolver = (hostname: string) => Promise<string[]>;

export type FetchResult =
  | { kind: "ok"; body: string; etag: string | null }
  | { kind: "not_modified"; etag: string | null };

export type FetchOptions = {
  /** The etag stored from the last successful fetch; sent as If-None-Match. */
  etag?: string | null;
  resolve?: Resolver;
  fetch?: typeof fetch;
  timeoutMs?: number;
  maxBytes?: number;
  maxRedirects?: number;
  userAgent?: string;
};

// ---------------------------------------------------------------- URLs

/**
 * An absolute https URL from what a household typed (webcal:// and https:// both accepted),
 * or null when it is not one. Userinfo is refused: a feed URL carries no credentials.
 */
export function normaliseFeedUrl(input: string): URL | null {
  const trimmed = input.trim();
  let text = trimmed;
  if (/^webcal:\/\//i.test(trimmed)) {
    text = "https://" + trimmed.slice("webcal://".length);
  }
  let url: URL;
  try {
    url = new URL(text);
  } catch {
    return null;
  }
  if (url.protocol !== "https:") return null;
  if (url.username !== "" || url.password !== "") return null;
  return url;
}

// ---------------------------------------------------------------- addresses

/** The four octets of a dotted IPv4 address, or null. */
function ipv4Octets(ip: string): number[] | null {
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(ip);
  if (!m) return null;
  const octets = m.slice(1).map(Number);
  return octets.every((o) => o >= 0 && o <= 255) ? octets : null;
}

/** True for every IPv4 address that is not a public unicast address. */
export function isForbiddenIPv4(ip: string): boolean {
  const o = ipv4Octets(ip);
  if (!o) return true; // not an IPv4 address: refuse rather than guess
  const [a, b, c] = o;
  if (a === 0) return true; // 0.0.0.0/8 "this network"
  if (a === 10) return true; // 10.0.0.0/8 private
  if (a === 127) return true; // loopback
  if (a === 100 && b >= 64 && b <= 127) return true; // 100.64.0.0/10 carrier-grade NAT
  if (a === 169 && b === 254) return true; // link-local
  if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12 private
  if (a === 192 && b === 0 && c === 0) return true; // 192.0.0.0/24 IETF protocol assignments
  if (a === 192 && b === 0 && c === 2) return true; // documentation
  if (a === 192 && b === 168) return true; // 192.168.0.0/16 private
  if (a === 198 && (b === 18 || b === 19)) return true; // benchmarking
  if (a === 198 && b === 51 && c === 100) return true; // documentation
  if (a === 203 && b === 0 && c === 113) return true; // documentation
  if (a >= 224) return true; // multicast 224/4, reserved 240/4, broadcast
  return false;
}

/** The sixteen bytes of an IPv6 address (zone id dropped), or null. */
function ipv6Bytes(ip: string): number[] | null {
  let text = ip.split("%")[0].toLowerCase();
  if (!/^[0-9a-f:.]+$/.test(text) || !text.includes(":")) return null;

  // A trailing dotted IPv4 becomes two hex groups.
  const dot = text.lastIndexOf(".");
  if (dot !== -1) {
    const colon = text.lastIndexOf(":");
    const v4 = ipv4Octets(text.slice(colon + 1));
    if (!v4) return null;
    const hi = ((v4[0] << 8) | v4[1]).toString(16);
    const lo = ((v4[2] << 8) | v4[3]).toString(16);
    text = `${text.slice(0, colon + 1)}${hi}:${lo}`;
  }

  const halves = text.split("::");
  if (halves.length > 2) return null;
  const parse = (part: string): number[] | null => {
    if (part === "") return [];
    const groups = part.split(":");
    const out: number[] = [];
    for (const g of groups) {
      if (!/^[0-9a-f]{1,4}$/.test(g)) return null;
      const n = parseInt(g, 16);
      out.push(n >> 8, n & 0xff);
    }
    return out;
  };
  const head = parse(halves[0]);
  if (!head) return null;
  if (halves.length === 1) return head.length === 16 ? head : null;
  const tail = parse(halves[1]);
  if (!tail) return null;
  const missing = 16 - head.length - tail.length;
  if (missing < 1) return null;
  return [...head, ...new Array<number>(missing).fill(0), ...tail];
}

/** True for every IPv6 address that is not a public unicast address (embedded IPv4 included). */
export function isForbiddenIPv6(ip: string): boolean {
  const b = ipv6Bytes(ip);
  if (!b) return true;
  const allZero = (from: number, to: number) => b.slice(from, to).every((x) => x === 0);

  if (allZero(0, 15) && b[15] === 0) return true; // :: unspecified
  if (allZero(0, 15) && b[15] === 1) return true; // ::1 loopback
  if (allZero(0, 10) && b[10] === 0xff && b[11] === 0xff) {
    return isForbiddenIPv4(b.slice(12).join(".")); // ::ffff:a.b.c.d mapped
  }
  if (allZero(0, 12)) return isForbiddenIPv4(b.slice(12).join(".")); // ::a.b.c.d compatible
  if (b[0] === 0x00 && b[1] === 0x64 && b[2] === 0xff && b[3] === 0x9b && allZero(4, 12)) {
    return isForbiddenIPv4(b.slice(12).join(".")); // 64:ff9b::/96 NAT64
  }
  if ((b[0] & 0xfe) === 0xfc) return true; // fc00::/7 unique local
  if (b[0] === 0xfe && (b[1] & 0xc0) === 0x80) return true; // fe80::/10 link-local
  if (b[0] === 0xff) return true; // ff00::/8 multicast
  if (b[0] === 0x20 && b[1] === 0x01 && b[2] === 0x0d && b[3] === 0xb8) return true; // 2001:db8::/32 docs
  if (b[0] === 0x01 && b[1] === 0x00 && allZero(2, 8)) return true; // 100::/64 discard
  return false;
}

/** True for any address a feed may not be fetched from. */
export function isForbiddenAddress(ip: string): boolean {
  return ip.includes(":") ? isForbiddenIPv6(ip) : isForbiddenIPv4(ip);
}

/** Host names that name this machine or its network, whatever they resolve to. */
export function isForbiddenHostname(hostname: string): boolean {
  const h = hostname.toLowerCase().replace(/\.$/, "");
  if (h === "" || h === "localhost") return true;
  return h.endsWith(".localhost") || h.endsWith(".local") || h.endsWith(".internal") ||
    h.endsWith(".localdomain") || !h.includes(".");
}

/** The address of an IP literal host ("[::1]" → "::1"), or null for a name. */
function literalOf(hostname: string): string | null {
  const bare = hostname.startsWith("[") && hostname.endsWith("]")
    ? hostname.slice(1, -1)
    : hostname;
  if (ipv4Octets(bare) || bare.includes(":")) return bare;
  return null;
}

/** Resolves A and AAAA records through the Deno runtime. Empty when neither answers. */
export const denoResolver: Resolver = async (hostname) => {
  const out: string[] = [];
  for (const type of ["A", "AAAA"] as const) {
    try {
      out.push(...await Deno.resolveDns(hostname, type));
    } catch {
      // No record of this type is not an error; the caller decides on the total.
    }
  }
  return out;
};

/**
 * Throws forbidden_host unless every address of the URL's host is public, and unreachable
 * when the host resolves to nothing. IP literals are checked without a lookup.
 */
export async function assertPublicHost(url: URL, resolve: Resolver = denoResolver): Promise<void> {
  const literal = literalOf(url.hostname);
  if (literal !== null) {
    if (isForbiddenAddress(literal)) throw new FetchError("forbidden_host");
    return;
  }
  if (isForbiddenHostname(url.hostname)) throw new FetchError("forbidden_host");

  let addresses: string[];
  try {
    addresses = await resolve(url.hostname);
  } catch {
    throw new FetchError("unreachable");
  }
  if (addresses.length === 0) throw new FetchError("unreachable");
  // One private answer among the public ones is enough to refuse: the client may pick it.
  if (addresses.some(isForbiddenAddress)) throw new FetchError("forbidden_host");
}

// ---------------------------------------------------------------- the fetch

const REDIRECT_STATUS = new Set([301, 302, 303, 307, 308]);

/** Reads the body as text, refusing more than maxBytes (the stream is cancelled at the cap). */
async function readCapped(res: Response, maxBytes: number): Promise<string> {
  const declared = res.headers.get("content-length");
  if (declared !== null && Number(declared) > maxBytes) {
    await res.body?.cancel();
    throw new FetchError("too_large");
  }
  if (res.body === null) return "";
  const reader = res.body.getReader();
  const parts: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new FetchError("too_large");
    }
    parts.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

/**
 * Fetches a feed URL the way the import needs it. Every hop (the first URL and each redirect)
 * is https, has a public address and is refused on a private one. Redirects are followed by
 * hand (redirect: "manual") so each hop is checked; more than maxRedirects is an error.
 * Throws FetchError; never returns a body that was not read within the caps.
 */
export async function fetchFeed(input: string, opts: FetchOptions = {}): Promise<FetchResult> {
  const resolve = opts.resolve ?? denoResolver;
  const doFetch = opts.fetch ?? fetch;
  const timeoutMs = opts.timeoutMs ?? FETCH_TIMEOUT_MS;
  const maxBytes = opts.maxBytes ?? MAX_BODY_BYTES;
  const maxRedirects = opts.maxRedirects ?? MAX_REDIRECTS;

  const first = normaliseFeedUrl(input);
  if (first === null) throw new FetchError("forbidden_host");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    let url = first;
    for (let hop = 0;; hop++) {
      await assertPublicHost(url, resolve);

      const headers: Record<string, string> = {
        "User-Agent": opts.userAgent ?? USER_AGENT,
        "Accept": "text/calendar, text/plain;q=0.5, */*;q=0.1",
      };
      if (opts.etag) headers["If-None-Match"] = opts.etag;

      let res: Response;
      try {
        res = await doFetch(url.href, {
          redirect: "manual",
          headers,
          credentials: "omit",
          signal: controller.signal,
        });
      } catch (err) {
        if (isAbort(err)) throw new FetchError("timeout");
        throw new FetchError("unreachable");
      }

      if (REDIRECT_STATUS.has(res.status)) {
        await res.body?.cancel();
        const location = res.headers.get("location");
        if (!location) throw new FetchError(`http_${res.status}`);
        if (hop >= maxRedirects) throw new FetchError("too_many_redirects");
        let next: URL | null = null;
        try {
          next = normaliseFeedUrl(new URL(location, url).href);
        } catch {
          next = null; // a Location that is not a URL is not a feed we may fetch
        }
        if (next === null) throw new FetchError("forbidden_host");
        url = next;
        continue;
      }

      const etag = res.headers.get("etag");
      if (res.status === 304) {
        await res.body?.cancel();
        if (!opts.etag) throw new FetchError("http_304");
        return { kind: "not_modified", etag: opts.etag };
      }
      if (res.status < 200 || res.status > 299) {
        await res.body?.cancel();
        throw new FetchError(`http_${res.status}`);
      }

      try {
        const body = await readCapped(res, maxBytes);
        return { kind: "ok", body, etag: etag ? etag.slice(0, 300) : null };
      } catch (err) {
        if (err instanceof FetchError) throw err;
        if (isAbort(err)) throw new FetchError("timeout");
        throw new FetchError("unreachable");
      }
    }
  } finally {
    clearTimeout(timer);
  }
}

function isAbort(err: unknown): boolean {
  return err instanceof Error && (err.name === "AbortError" || err.name === "TimeoutError");
}

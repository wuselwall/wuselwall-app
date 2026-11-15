// The one way a provider plug-in reaches the network (ADR-022): a fetch that only talks https
// to the hosts the plug-in declared, never follows a redirect, reads at most a capped body and
// carries no cookies. The runner wraps the real fetch in this before a plug-in sees it.
//
// A failure leaves here as a ProviderError with a short code and nothing else: the original
// error is dropped on purpose, because a provider that takes its key in the URL (OpenWeather,
// Google) would put the key into the message of a failed fetch.
import { type Provider, ProviderError, type ProviderContext } from "./types.ts";

/** Names this module to the provider's operator; MET Norway and Nominatim require one. */
export const USER_AGENT = "WuselWall services (+https://wuselwall.app)";

/** The most a plug-in is given to read; map pictures get more. */
export const MAX_BODY_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 6 * 1024 * 1024;

/** How long one provider call may take before the runner gives up. */
export const CALL_TIMEOUT_MS = 12_000;

function isAbort(err: unknown): boolean {
  return err instanceof Error && (err.name === "AbortError" || err.name === "TimeoutError");
}

/** The body, refusing more than maxBytes (the stream is cancelled at the cap). */
async function readBytes(res: Response, maxBytes: number): Promise<Uint8Array<ArrayBuffer>> {
  const declared = res.headers.get("content-length");
  if (declared !== null && Number(declared) > maxBytes) {
    await res.body?.cancel().catch(() => {});
    throw new ProviderError("too_large");
  }
  if (res.body === null) return new Uint8Array(0);
  const reader = res.body.getReader();
  const parts: Uint8Array[] = [];
  let total = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel().catch(() => {});
        throw new ProviderError("too_large");
      }
      parts.push(value);
    }
  } catch (err) {
    if (err instanceof ProviderError) throw err;
    throw new ProviderError(isAbort(err) ? "timeout" : "unreachable");
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.byteLength;
  }
  return bytes;
}

/**
 * The fetch a plug-in gets. `base` is the real fetch (or a fake in the tests). Only the hosts of
 * `provider.hosts` are reachable, https only, no credentials in the URL, the default port, no
 * redirects (a redirect is an error, never followed), no cookies, a capped body that is read
 * completely before the plug-in sees the response.
 */
export function guardedFetch(
  provider: Pick<Provider, "hosts">,
  base: typeof fetch,
  maxBytes: number = MAX_BODY_BYTES,
): typeof fetch {
  const hosts = new Set(provider.hosts.map((h) => h.toLowerCase()));
  return (async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    let url: URL;
    try {
      url = new URL(input instanceof Request ? input.url : String(input));
    } catch {
      throw new ProviderError("forbidden_host");
    }
    if (
      url.protocol !== "https:" || !hosts.has(url.hostname.toLowerCase()) ||
      url.username !== "" || url.password !== "" || url.port !== ""
    ) {
      throw new ProviderError("forbidden_host");
    }

    const headers = new Headers(init?.headers);
    if (!headers.has("User-Agent")) headers.set("User-Agent", USER_AGENT);
    headers.delete("Cookie");

    let res: Response;
    try {
      res = await base(url.href, {
        method: init?.method ?? "GET",
        body: init?.body,
        headers,
        redirect: "error",
        credentials: "omit",
        signal: init?.signal,
      });
    } catch (err) {
      throw new ProviderError(isAbort(err) ? "timeout" : "unreachable");
    }
    const bytes = await readBytes(res, maxBytes);
    const nullBody = res.status === 204 || res.status === 205 || res.status === 304;
    return new Response(nullBody ? null : bytes, {
      status: res.status,
      headers: res.headers,
    });
  }) as typeof fetch;
}

export type JsonOptions = {
  /** The provider takes the household's key: 401 and 403 then mean the key was refused. */
  keyed?: boolean;
  /** HTTP statuses that mean "nothing for this point" (default none). */
  noData?: number[];
};

/** The code for a response that is not a success, or null for a 2xx. */
export function statusCode(status: number, opts: JsonOptions = {}): string | null {
  if (status >= 200 && status < 300) return null;
  if (opts.noData?.includes(status)) return "no_data";
  if (opts.keyed && (status === 401 || status === 403)) return "unauthorized";
  if (status === 429) return "quota";
  return `http_${status}`;
}

/** GET (or the given init) and parse JSON; any failure is a ProviderError with a short code. */
export async function fetchJson(
  ctx: ProviderContext,
  url: string,
  init: RequestInit = {},
  opts: JsonOptions = {},
): Promise<unknown> {
  const res = await ctx.fetch(url, { ...init, signal: init.signal ?? ctx.signal });
  const code = statusCode(res.status, opts);
  if (code !== null) {
    await res.body?.cancel().catch(() => {});
    throw new ProviderError(code);
  }
  try {
    return await res.json();
  } catch {
    throw new ProviderError("bad_answer");
  }
}

/** The bytes of an answer that is a picture. */
export async function fetchBytes(
  ctx: ProviderContext,
  url: string,
  opts: JsonOptions = {},
): Promise<{ bytes: Uint8Array; contentType: string }> {
  const res = await ctx.fetch(url, { signal: ctx.signal });
  const code = statusCode(res.status, opts);
  if (code !== null) {
    await res.body?.cancel().catch(() => {});
    throw new ProviderError(code);
  }
  return {
    bytes: new Uint8Array(await res.arrayBuffer()),
    contentType: res.headers.get("content-type") ?? "",
  };
}

/** Base64 of bytes, in chunks so a large picture does not overflow the argument list. */
export function toBase64(bytes: Uint8Array): string {
  let out = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    out += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(out);
}

/** A query value in a URL; the URLSearchParams way, so nothing needs escaping by hand. */
export function query(params: Record<string, string | number>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) sp.set(k, String(v));
  return sp.toString();
}

/** A coordinate as a decimal string of at most four places (the most MET Norway accepts). */
export function coord(n: number): string {
  return String(Math.round(n * 10_000) / 10_000);
}

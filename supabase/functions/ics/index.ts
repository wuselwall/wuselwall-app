// GET /functions/v1/ics/<token>.ics → one subscriber's calendar feed (specs/05 "The ICS feed").
//
// No user is signed in here: a calendar app subscribes with the token alone, so this
// function uses the service-role client. That is safe because api.ics_feed returns only
// the data of the token it is given, and nothing for an unknown or revoked one.
// The token is the last path segment, so it is found whether the gateway passes
// /ics/<token>.ics or the full /functions/v1/ics/<token>.ics. It is never logged.
import { serviceClient } from "../_shared/client.ts";
import { type IcsFeed, renderIcs } from "../_shared/ics.ts";

const TOKEN_SEGMENT = /^([A-Za-z0-9_-]{20,200})\.ics$/;

function tokenFromPath(pathname: string): string | null {
  const last = pathname.split("/").pop() ?? "";
  const match = TOKEN_SEGMENT.exec(last);
  return match ? match[1] : null;
}

async function shortHash(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return [...new Uint8Array(digest)]
    .slice(0, 8)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function matchesEtag(ifNoneMatch: string | null, etag: string): boolean {
  if (ifNoneMatch === null) return false;
  if (ifNoneMatch.trim() === "*") return true;
  return ifNoneMatch
    .split(",")
    .map((tag) => tag.trim().replace(/^W\//, ""))
    .includes(etag);
}

function empty(status: number, headers: Record<string, string> = {}): Response {
  return new Response(null, { status, headers });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "GET") {
    return empty(405, { Allow: "GET" });
  }
  const url = new URL(req.url);
  const token = tokenFromPath(url.pathname);
  if (token === null) return empty(404);

  let feed: IcsFeed | null;
  try {
    const { data, error } = await serviceClient().rpc("ics_feed", {
      p_token: token,
    });
    if (error) {
      console.error("ics_feed failed with", error.code ?? "no code");
      return empty(500);
    }
    feed = data as IcsFeed | null;
  } catch {
    console.error("ics_feed unavailable");
    return empty(500);
  }
  // Unknown or revoked token: the same answer for both, so tokens cannot be probed.
  if (feed === null) return empty(404);

  // The school rows are hashed too: a holiday has no updated_at, so the revision cannot see it.
  const shape = JSON.stringify(feed.filter ?? {}) +
    (feed.school ? JSON.stringify([feed.school, feed.members ?? null]) : "");
  const etag = `"${feed.revision}-${await shortHash(shape)}"`;
  const cacheHeaders = {
    ETag: etag,
    "Cache-Control": "private, max-age=900",
  };
  if (matchesEtag(req.headers.get("If-None-Match"), etag)) {
    return empty(304, cacheHeaders);
  }

  const body = renderIcs(feed, { now: new Date(), host: url.hostname });
  return new Response(body, {
    status: 200,
    headers: {
      ...cacheHeaders,
      "Content-Type": "text/calendar; charset=utf-8",
    },
  });
});

// POST /functions/v1/mcp → the family's MCP server, family:read (specs/12 "Part 2", FR-6.1),
// plus the one write of specs/24: a proposal (api.mcp_propose), reviewed by a guardian in the app.
//
// Streamable HTTP, stateless: every JSON-RPC message is its own POST and is answered with one
// JSON object (_shared/mcp.ts); the tools are _shared/mcp_family.ts. GET and DELETE are 405: no
// SSE stream, no sessions. A request with an Origin header is refused (403), as the transport
// requires against DNS rebinding: the clients are assistants and their servers, not web pages.
//
// Authorisation is an assistant key ("Authorization: Bearer wwa_…", Settings → Siri und
// Kurzbefehle), the interim of Q15 until OAuth 2.1 comes with the write scopes. No user is
// signed in, so this function uses the service-role client; that is safe because
// api.mcp_context starts from the key, reads as its holder only and returns only the key's
// household (migrations/20261016120000_assistant_keys.sql). The key is never logged.
import { serviceClient } from "../_shared/client.ts";
import {
  handle,
  INTERNAL_ERROR,
  PARSE_ERROR,
  UNAUTHORIZED,
} from "../_shared/mcp.ts";
import { familyServer, type McpContext } from "../_shared/mcp_family.ts";
import { pickLang } from "../_shared/shortcuts.ts";

const VERSION = "1.0.0";
const KEY = /^wwa_[A-Za-z0-9_-]{20,200}$/;

function reply(
  status: number,
  body: unknown | null,
  headers: Record<string, string> = {},
): Response {
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: {
      ...(body === null ? {} : { "Content-Type": "application/json" }),
      "Cache-Control": "no-store",
      ...headers,
    },
  });
}

function rpcError(code: number, message: string) {
  return { jsonrpc: "2.0", id: null, error: { code, message } };
}

/** A 401 the client can read: the key is missing, malformed, revoked or unknown — one answer. */
function unauthorized(): Response {
  return reply(
    401,
    rpcError(
      UNAUTHORIZED,
      "A valid WuselWall assistant key is required (Authorization: Bearer wwa_…).",
    ),
    {
      "WWW-Authenticate": 'Bearer realm="WuselWall", error="invalid_token"',
    },
  );
}

class KeyRefused extends Error {}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return reply(405, null, { Allow: "POST" });
  if (req.headers.get("Origin") !== null) {
    return reply(403, rpcError(-32000, "Browser origins are not accepted."));
  }
  const match = /^Bearer\s+(\S+)$/i.exec(
    req.headers.get("Authorization") ?? "",
  );
  const key = match && KEY.test(match[1]) ? match[1] : null;
  if (key === null) return unauthorized();

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, rpcError(PARSE_ERROR, "Parse error"));
  }

  const acceptLanguage = req.headers.get("Accept-Language");
  const read = async (
    parts: string[],
    from: string | null,
    days: number,
  ): Promise<McpContext> => {
    const { data, error } = await serviceClient().rpc("mcp_context", {
      p_token: key,
      p_parts: parts,
      p_from: from,
      p_days: days,
    });
    if (error) {
      if (error.hint === "shortcut_token_invalid") throw new KeyRefused();
      throw error;
    }
    return data as McpContext;
  };

  const propose = async (
    kind: string,
    payload: unknown,
    summary: string | null,
    clientKey: string | null,
  ) => {
    const { data, error } = await serviceClient().rpc("mcp_propose", {
      p_token: key,
      p_kind: kind,
      p_payload: payload,
      p_summary: summary,
      p_client_key: clientKey,
    });
    if (error) {
      if (error.hint === "shortcut_token_invalid") throw new KeyRefused();
      throw error;
    }
    return data as { id: string; created: boolean };
  };

  try {
    // Every message proves its key first, tools/list and initialize included. The light context
    // it reads is reused by whatever needs nothing more (the members, this week's Monday).
    const base = await read([], null, 1);
    const server = familyServer(
      (
        parts,
        from,
        days,
      ) => (parts.length === 0 && from === null && days === 1
        ? Promise.resolve(base)
        : read(parts, from, days)),
      (locale) =>
        pickLang(undefined, acceptLanguage, locale ?? base.household.locale),
      VERSION,
      propose,
    );
    const out = await handle(body, (name) => req.headers.get(name), server);
    return reply(out.status, out.body, out.headers);
  } catch (err) {
    if (err instanceof KeyRefused) return unauthorized();
    console.error(
      "mcp failed with",
      (err as { code?: unknown } | null)?.code ?? "no code",
    );
    const id = (body as { id?: unknown } | null)?.id ?? null;
    return reply(500, {
      jsonrpc: "2.0",
      id,
      error: { code: INTERNAL_ERROR, message: "Internal error" },
    });
  }
});

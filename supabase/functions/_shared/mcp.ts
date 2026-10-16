// The MCP protocol layer of the `mcp` function (specs/12 "Part 2"): JSON-RPC over Streamable HTTP,
// stateless, one POST per message, always answered with a single JSON object.
//
// Dual-era (MCP 2026-07-28, "Versioning and Compatibility"): a request that carries
// `_meta["io.modelcontextprotocol/protocolVersion"]` is served as revision 2026-07-28 (headers
// validated against the body, `resultType` on every result, cache hints on lists,
// `server/discover`); an `initialize` and everything without that `_meta` is served as the
// legacy revisions 2025-03-26 to 2025-11-25, without sessions (a legacy server MAY omit
// Mcp-Session-Id). Roots, Sampling, Logging, subscriptions and SSE are not offered.
//
// Pure: no I/O. The tools and resources are handlers the caller passes in (mcp_family.ts).

export const MODERN = "2026-07-28";
export const LEGACY = ["2025-11-25", "2025-06-18", "2025-03-26"];
export const SUPPORTED = [MODERN, ...LEGACY];

const META_VERSION = "io.modelcontextprotocol/protocolVersion";
const META_SERVER = "io.modelcontextprotocol/serverInfo";

// JSON-RPC and MCP error codes (the spec's allocation: -32020… are MCP's own).
export const PARSE_ERROR = -32700;
export const INVALID_REQUEST = -32600;
export const METHOD_NOT_FOUND = -32601;
export const INVALID_PARAMS = -32602;
export const INTERNAL_ERROR = -32603;
export const UNAUTHORIZED = -32001; // implementation-defined range
export const HEADER_MISMATCH = -32020;
export const UNSUPPORTED_VERSION = -32022;

export type ToolDef = {
  name: string;
  title: string;
  description: string;
  inputSchema: Record<string, unknown>;
  annotations: Record<string, unknown>;
};

export type ResourceDef = { uri: string; name: string; title: string; description: string; mimeType: string };

/** A tool's answer: the text the user sees and the structure an agent chains on (specs/12). */
export type ToolResult = { text: string; structured: unknown; isError?: boolean };

export type Server = {
  info: { name: string; version: string };
  instructions: string;
  tools: ToolDef[];
  resources: ResourceDef[];
  callTool(name: string, args: Record<string, unknown>): Promise<ToolResult>;
  readResource(uri: string): Promise<{ mimeType: string; text: string } | null>;
};

/** The HTTP answer for one POST. */
export type HttpReply = { status: number; body: unknown | null; headers?: Record<string, string> };

/** An error a handler raises for the client (bad arguments), not a server failure. */
export class McpError extends Error {
  constructor(readonly code: number, message: string, readonly data?: unknown) {
    super(message);
  }
}

function error(id: unknown, code: number, message: string, data?: unknown) {
  return {
    jsonrpc: "2.0",
    id: id ?? null,
    error: data === undefined ? { code, message } : { code, message, data },
  };
}

/** The value of an Mcp-Name or Mcp-Param-* header, with the Base64 sentinel decoded. */
export function decodeHeaderValue(value: string): string {
  const m = /^=\?base64\?(.*)\?=$/.exec(value);
  if (!m) return value;
  try {
    return new TextDecoder().decode(Uint8Array.from(atob(m[1]), (c) => c.charCodeAt(0)));
  } catch {
    return "\u0000invalid";
  }
}

type Request = {
  jsonrpc: "2.0";
  id?: string | number | null;
  method: string;
  params?: Record<string, unknown>;
};

/**
 * Answers one POSTed message. `headers` reads a request header (case-insensitively). The
 * caller has authenticated the request already; Origin and the HTTP method are checked there.
 */
export async function handle(
  body: unknown,
  headers: (name: string) => string | null,
  server: Server,
): Promise<HttpReply> {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return { status: 400, body: error(null, INVALID_REQUEST, "one JSON-RPC message per request") };
  }
  const req = body as Partial<Request>;
  if (req.jsonrpc !== "2.0" || typeof req.method !== "string") {
    return { status: 400, body: error(req.id, INVALID_REQUEST, "not a JSON-RPC 2.0 request") };
  }
  const params = (req.params && typeof req.params === "object" ? req.params : {}) as Record<string, unknown>;
  const isNotification = !("id" in req) || req.id === undefined;
  if (isNotification) return { status: 202, body: null };

  const meta = (params._meta && typeof params._meta === "object" ? params._meta : {}) as Record<
    string,
    unknown
  >;
  const modernVersion = meta[META_VERSION];

  // ── revision 2026-07-28 ─────────────────────────────────────────────────────────
  if (modernVersion !== undefined) {
    const headerVersion = headers("MCP-Protocol-Version");
    if (headerVersion === null || headerVersion !== modernVersion) {
      return mismatch(req.id, "MCP-Protocol-Version header does not match _meta");
    }
    if (headers("Mcp-Method") !== req.method) {
      return mismatch(req.id, "Mcp-Method header does not match the method");
    }
    if (["tools/call", "resources/read", "prompts/get"].includes(req.method)) {
      const name = req.method === "resources/read" ? params.uri : params.name;
      const header = headers("Mcp-Name");
      if (header === null || decodeHeaderValue(header) !== name) {
        return mismatch(req.id, "Mcp-Name header does not match the body");
      }
    }
    if (modernVersion !== MODERN) {
      return {
        status: 400,
        body: error(req.id, UNSUPPORTED_VERSION, "Unsupported protocol version", {
          supported: SUPPORTED,
          requested: modernVersion,
        }),
      };
    }
    return await dispatch(req as Request, params, server, true);
  }

  // ── legacy revisions (initialize handshake) ───────────────────────────────────────
  if (req.method === "initialize") {
    const asked = typeof params.protocolVersion === "string" ? params.protocolVersion : "";
    return {
      status: 200,
      body: {
        jsonrpc: "2.0",
        id: req.id,
        result: {
          protocolVersion: LEGACY.includes(asked) ? asked : LEGACY[0],
          capabilities: capabilities(),
          serverInfo: server.info,
          instructions: server.instructions,
        },
      },
    };
  }
  const headerVersion = headers("MCP-Protocol-Version");
  if (headerVersion !== null && !SUPPORTED.includes(headerVersion)) {
    return {
      status: 400,
      body: error(req.id, UNSUPPORTED_VERSION, "Unsupported protocol version", {
        supported: SUPPORTED,
        requested: headerVersion,
      }),
    };
  }
  if (req.method === "ping") return { status: 200, body: { jsonrpc: "2.0", id: req.id, result: {} } };
  return await dispatch(req as Request, params, server, false);
}

function mismatch(id: unknown, message: string): HttpReply {
  return { status: 400, body: error(id, HEADER_MISMATCH, `Header mismatch: ${message}`) };
}

function capabilities() {
  return { tools: { listChanged: false }, resources: { listChanged: false, subscribe: false } };
}

async function dispatch(
  req: Request,
  params: Record<string, unknown>,
  server: Server,
  modern: boolean,
): Promise<HttpReply> {
  // Every modern result says it is complete and who answered; lists say how long they keep.
  const ok = (result: Record<string, unknown>, cacheMs?: number): HttpReply => ({
    status: 200,
    body: {
      jsonrpc: "2.0",
      id: req.id,
      result: modern
        ? {
          ...result,
          resultType: "complete",
          ...(cacheMs === undefined ? {} : { ttlMs: cacheMs, cacheScope: "private" }),
          _meta: { [META_SERVER]: server.info },
        }
        : result,
    },
  });
  const fail = (code: number, message: string, status = modern ? 400 : 200): HttpReply => ({
    status,
    body: error(req.id, code, message),
  });

  try {
    switch (req.method) {
      case "server/discover":
        return ok(
          { supportedVersions: SUPPORTED, capabilities: capabilities(), instructions: server.instructions },
          3_600_000,
        );
      case "tools/list":
        // The list never changes per caller; an hour is a safe hint.
        return ok({ tools: server.tools }, 3_600_000);
      case "resources/list":
        return ok({ resources: server.resources }, 3_600_000);
      case "resources/templates/list":
        return ok({ resourceTemplates: [] }, 3_600_000);
      case "tools/call": {
        const name = params.name;
        const args = params.arguments ?? {};
        if (typeof name !== "string" || !server.tools.some((t) => t.name === name)) {
          return fail(INVALID_PARAMS, `Unknown tool: ${String(name)}`);
        }
        if (typeof args !== "object" || args === null || Array.isArray(args)) {
          return fail(INVALID_PARAMS, "arguments must be an object");
        }
        const r = await server.callTool(name, args as Record<string, unknown>);
        return ok({
          content: [{ type: "text", text: r.text }],
          structuredContent: r.structured,
          isError: r.isError ?? false,
        });
      }
      case "resources/read": {
        const uri = params.uri;
        const found = typeof uri === "string" ? await server.readResource(uri) : null;
        if (!found) {
          // 2026-07-28 moved "resource not found" to Invalid Params; earlier revisions used -32002.
          return fail(modern ? INVALID_PARAMS : -32002, `Unknown resource: ${String(uri)}`);
        }
        return ok({ contents: [{ uri, mimeType: found.mimeType, text: found.text }] }, 60_000);
      }
      default:
        return fail(METHOD_NOT_FOUND, `Method not found: ${req.method}`, modern ? 404 : 200);
    }
  } catch (err) {
    if (err instanceof McpError) {
      return { status: modern ? 400 : 200, body: error(req.id, err.code, err.message, err.data) };
    }
    throw err;
  }
}

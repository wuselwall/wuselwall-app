import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import {
  decodeHeaderValue,
  handle,
  HEADER_MISMATCH,
  MODERN,
  type Server,
  UNSUPPORTED_VERSION,
} from "./mcp.ts";

// A server with one tool and one resource; the tool echoes its arguments.
const server: Server = {
  info: { name: "test", version: "1" },
  instructions: "test server",
  tools: [{
    name: "echo",
    title: "Echo",
    description: "echoes",
    inputSchema: { type: "object" },
    annotations: { readOnlyHint: true },
  }],
  resources: [{ uri: "family://x", name: "x", title: "X", description: "x", mimeType: "application/json" }],
  callTool: (_name, args) => Promise.resolve({ text: "echo", structured: args }),
  readResource: (uri) =>
    Promise.resolve(uri === "family://x" ? { mimeType: "application/json", text: "{}" } : null),
};

const META = {
  "io.modelcontextprotocol/protocolVersion": MODERN,
  "io.modelcontextprotocol/clientInfo": { name: "t", version: "1" },
  "io.modelcontextprotocol/clientCapabilities": {},
};

function headersOf(map: Record<string, string>) {
  const lower = Object.fromEntries(Object.entries(map).map(([k, v]) => [k.toLowerCase(), v]));
  return (name: string) => lower[name.toLowerCase()] ?? null;
}

function modern(method: string, params: Record<string, unknown> = {}, extra: Record<string, string> = {}) {
  const headers = { "MCP-Protocol-Version": MODERN, "Mcp-Method": method, ...extra };
  return handle(
    { jsonrpc: "2.0", id: 1, method, params: { ...params, _meta: META } },
    headersOf(headers),
    server,
  );
}

// deno-lint-ignore no-explicit-any
type Body = any;

Deno.test("modern: tools/list says it is complete, who answered and how long it keeps", async () => {
  const r = await modern("tools/list");
  assertEquals(r.status, 200);
  const result = (r.body as Body).result;
  assertEquals(result.resultType, "complete");
  assertEquals(result.tools[0].name, "echo");
  assertEquals(result.cacheScope, "private");
  assert(result.ttlMs > 0);
  assertEquals(result._meta["io.modelcontextprotocol/serverInfo"], { name: "test", version: "1" });
});

Deno.test("modern: server/discover lists every version served", async () => {
  const r = await modern("server/discover");
  const result = (r.body as Body).result;
  assertEquals(result.supportedVersions, ["2026-07-28", "2025-11-25", "2025-06-18", "2025-03-26"]);
  assertEquals(result.instructions, "test server");
  assert("tools" in result.capabilities);
});

Deno.test("modern: headers must match the body", async () => {
  const wrongVersion = await handle(
    { jsonrpc: "2.0", id: 1, method: "tools/list", params: { _meta: META } },
    headersOf({ "MCP-Protocol-Version": "2025-11-25", "Mcp-Method": "tools/list" }),
    server,
  );
  assertEquals(wrongVersion.status, 400);
  assertEquals((wrongVersion.body as Body).error.code, HEADER_MISMATCH);

  const noMethod = await handle(
    { jsonrpc: "2.0", id: 1, method: "tools/list", params: { _meta: META } },
    headersOf({ "MCP-Protocol-Version": MODERN }),
    server,
  );
  assertEquals((noMethod.body as Body).error.code, HEADER_MISMATCH);

  const noName = await modern("tools/call", { name: "echo", arguments: {} });
  assertEquals((noName.body as Body).error.code, HEADER_MISMATCH);

  const named = await modern("tools/call", { name: "echo", arguments: { a: 1 } }, { "Mcp-Name": "echo" });
  assertEquals((named.body as Body).result.structuredContent, { a: 1 });
});

Deno.test("modern: an Mcp-Name in the Base64 sentinel form is decoded", async () => {
  assertEquals(decodeHeaderValue("=?base64?SGVsbG8sIOS4lueVjA==?="), "Hello, 世界");
  assertEquals(decodeHeaderValue("plain"), "plain");
  const r = await modern("tools/call", { name: "echo", arguments: {} }, {
    "Mcp-Name": `=?base64?${btoa("echo")}?=`,
  });
  assertEquals(r.status, 200);
});

Deno.test("modern: an unknown version is refused with the supported ones", async () => {
  const r = await handle(
    {
      jsonrpc: "2.0",
      id: 7,
      method: "tools/list",
      params: { _meta: { "io.modelcontextprotocol/protocolVersion": "1900-01-01" } },
    },
    headersOf({ "MCP-Protocol-Version": "1900-01-01", "Mcp-Method": "tools/list" }),
    server,
  );
  assertEquals(r.status, 400);
  const error = (r.body as Body).error;
  assertEquals(error.code, UNSUPPORTED_VERSION);
  assertEquals(error.data.requested, "1900-01-01");
  assert(error.data.supported.includes(MODERN));
});

Deno.test("modern: an unknown method is a 404, a missing resource Invalid Params", async () => {
  const r = await modern("prompts/list");
  assertEquals(r.status, 404);
  assertEquals((r.body as Body).error.code, -32601);
  const missing = await modern("resources/read", { uri: "family://nope" }, { "Mcp-Name": "family://nope" });
  assertEquals((missing.body as Body).error.code, -32602);
  const found = await modern("resources/read", { uri: "family://x" }, { "Mcp-Name": "family://x" });
  assertEquals((found.body as Body).result.contents[0].uri, "family://x");
});

Deno.test("legacy: initialize answers the asked version, or the newest legacy one", async () => {
  const asked = await handle(
    { jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18" } },
    headersOf({}),
    server,
  );
  assertEquals((asked.body as Body).result.protocolVersion, "2025-06-18");
  assertEquals((asked.body as Body).result.serverInfo.name, "test");
  const unknown = await handle(
    { jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05" } },
    headersOf({}),
    server,
  );
  assertEquals((unknown.body as Body).result.protocolVersion, "2025-11-25");
});

Deno.test("legacy: plain results, ping, the initialized notification, the old not-found code", async () => {
  const list = await handle({ jsonrpc: "2.0", id: 2, method: "tools/list" }, headersOf({}), server);
  assertEquals(list.status, 200);
  assertEquals((list.body as Body).result.resultType, undefined);
  const ping = await handle({ jsonrpc: "2.0", id: 3, method: "ping" }, headersOf({}), server);
  assertEquals((ping.body as Body).result, {});
  const note = await handle({ jsonrpc: "2.0", method: "notifications/initialized" }, headersOf({}), server);
  assertEquals(note, { status: 202, body: null });
  const missing = await handle(
    { jsonrpc: "2.0", id: 4, method: "resources/read", params: { uri: "family://nope" } },
    headersOf({ "MCP-Protocol-Version": "2025-06-18" }),
    server,
  );
  assertEquals((missing.body as Body).error.code, -32002);
  const tooNew = await handle(
    { jsonrpc: "2.0", id: 5, method: "tools/list" },
    headersOf({ "MCP-Protocol-Version": "2030-01-01" }),
    server,
  );
  assertEquals((tooNew.body as Body).error.code, UNSUPPORTED_VERSION);
});

Deno.test("batches and non-JSON-RPC bodies are refused", async () => {
  assertEquals(
    (await handle([{ jsonrpc: "2.0", id: 1, method: "ping" }], headersOf({}), server)).status,
    400,
  );
  assertEquals((await handle({ id: 1, method: "ping" }, headersOf({}), server)).status, 400);
});

Deno.test("an unknown tool is Invalid Params", async () => {
  const r = await modern("tools/call", { name: "delete_all", arguments: {} }, { "Mcp-Name": "delete_all" });
  assertEquals((r.body as Body).error.code, -32602);
});

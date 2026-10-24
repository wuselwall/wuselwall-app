// GET → the discovery document (ADR-018, decision 3; supabase/functions/_shared/server_info.ts).
//
// Called by the app before anyone signs in, so it has no user and needs no key: the
// gateway passes /functions/v1/ without one, and hosted Supabase deploys it with
// --no-verify-jwt (config.toml [functions.server-info]). Everything it returns is public
// by design: the publishable key ships in every app, and row-level security, not the
// key, protects a household's data.
//
// It reads api.server_info() with that same publishable key, as any client could. No
// service role.
import {
  CORS_HEADERS,
  errorResponse,
  json,
  preflight,
} from "../_shared/client.ts";
import {
  checkRow,
  discoveryDocument,
  publicUrl,
  publishableKey,
  runtimeFeatures,
  serverVersion,
} from "../_shared/server_info.ts";

const env = (name: string) => Deno.env.get(name);

async function getJson(
  url: string,
  key: string,
  init?: RequestInit,
): Promise<unknown> {
  const response = await fetch(url, {
    ...init,
    headers: {
      apikey: key,
      "Content-Type": "application/json",
      ...init?.headers,
    },
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) {
    throw new Error(`${new URL(url).pathname}: HTTP ${response.status}`);
  }
  return await response.json();
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "GET") {
    return json({ code: "method_not_allowed", message: "use GET" }, 405);
  }

  try {
    const internal = env("SUPABASE_URL")?.replace(/\/+$/, "");
    const key = publishableKey(env);
    if (!internal || !key) {
      throw new Error("SUPABASE_URL and a publishable key must be set");
    }

    const row = await getJson(`${internal}/rest/v1/rpc/server_info`, key, {
      method: "POST",
      body: "{}",
      headers: { "Content-Profile": "api" },
    });

    const doc = discoveryDocument(checkRow(row), key, publicUrl(env), {
      features: runtimeFeatures(env),
      version: serverVersion(env),
    });
    return new Response(JSON.stringify(doc), {
      headers: {
        ...CORS_HEADERS,
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Content-Type": "application/json",
        // Short: a changed setting (household creation, features) shows within minutes.
        "Cache-Control": "public, max-age=300",
      },
    });
  } catch (err) {
    console.error("server-info:", err instanceof Error ? err.message : err);
    return errorResponse(err);
  }
});

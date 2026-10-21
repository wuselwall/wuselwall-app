// The discovery document (ADR-018, decision 3): everything the store app needs to talk
// to this server, which it reads before anyone signs in. Served by the server-info
// function, and by servers with a domain of their own also at
// /.well-known/wuselwall.json (a proxy rewrite to the same function).
//
// Pure: index.ts gathers the inputs, this module checks and shapes them.

/** The document's own format version, independent of the server's api_version. */
export const DISCOVERY_FORMAT = 1;

/** What `api.server_info()` returns (supabase/migrations/20261014200000_server_info.sql). */
export type ServerInfoRow = {
  api_version: number;
  min_app_version: string;
  household_creation: string;
  features: string[];
};

export type DiscoveryDocument = {
  wuselwall: number;
  /** Omitted when this server cannot know its public address: the app then uses the
   * origin it fetched the document from. */
  supabase_url?: string;
  publishable_key: string;
  api_version: number;
  min_app_version: string;
  household_creation: string;
  /** Email codes and passwords, on every server. Passkeys are decided by the app (only builds that name their own server), never by a server. */
  sign_in: { password: true };
  features: string[];
};

/**
 * The server's public address: WW_PUBLIC_URL if the operator set one, else
 * SUPABASE_PUBLIC_URL (the compose stack), else SUPABASE_URL when it is public
 * (hosted Supabase). The compose stack's SUPABASE_URL is the internal gateway
 * (http://api-gw:8000) and must never reach a client.
 */
export function publicUrl(env: (name: string) => string | undefined): string | undefined {
  for (const name of ["WW_PUBLIC_URL", "SUPABASE_PUBLIC_URL", "SUPABASE_URL"]) {
    const value = env(name)?.trim().replace(/\/+$/, "");
    if (value && /^https:\/\/[^/]+$/.test(value)) return value;
  }
  return undefined;
}

/**
 * The key the apps use: the publishable key (opaque, `sb_publishable_…`), or the legacy
 * anon JWT where a stack has no publishable key. Never a secret or service-role key.
 */
export function publishableKey(env: (name: string) => string | undefined): string | undefined {
  const keys = env("SUPABASE_PUBLISHABLE_KEYS");
  if (keys) {
    try {
      const parsed = JSON.parse(keys) as Record<string, unknown>;
      const key = parsed["default"] ?? Object.values(parsed)[0];
      if (typeof key === "string" && key.startsWith("sb_publishable_")) return key;
    } catch {
      // Malformed: fall through to the legacy key.
    }
  }
  const anon = env("SUPABASE_ANON_KEY");
  return anon && anon.length > 0 ? anon : undefined;
}

/** Throws when [row] is not what the migration returns: a half-migrated server must not
 * be offered to an app as if it were whole. */
export function checkRow(row: unknown): ServerInfoRow {
  const r = row as Partial<ServerInfoRow> | null;
  if (
    r === null || typeof r !== "object" ||
    typeof r.api_version !== "number" || !Number.isInteger(r.api_version) ||
    typeof r.min_app_version !== "string" ||
    typeof r.household_creation !== "string" ||
    !Array.isArray(r.features) || !r.features.every((f) => typeof f === "string")
  ) {
    throw new Error("api.server_info() returned an unexpected shape");
  }
  return r as ServerInfoRow;
}

export function discoveryDocument(
  row: ServerInfoRow,
  key: string,
  url: string | undefined,
): DiscoveryDocument {
  return {
    wuselwall: DISCOVERY_FORMAT,
    ...(url ? { supabase_url: url } : {}),
    publishable_key: key,
    api_version: row.api_version,
    min_app_version: row.min_app_version,
    household_creation: row.household_creation,
    sign_in: { password: true },
    features: row.features,
  };
}

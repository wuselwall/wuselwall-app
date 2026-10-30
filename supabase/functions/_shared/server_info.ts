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
  /** Whether a family exists (migration 20261030100000); absent on older servers. */
  claimed?: boolean;
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
  /** Whether a family exists yet. Without one, the app shows the claim step: only the
   * address announced with the setup key may sign up (specs/20 "Claiming the server").
   * Absent on servers from before that migration, which the app treats as claimed. */
  claimed?: boolean;
  /** Passwords on every server; email codes only where the server sends mail
   * (`email_code`, see [emailCode]). Passkeys are decided by the app (only builds that name
   * their own server), never by a server. */
  sign_in: { password: true; email_code: boolean };
  features: string[];
  /** The server release this stack was installed or updated from ("0.2.0"); absent on a
   * stack run from a checkout. Shown in the app's settings next to the app's own version. */
  server_version?: string;
};

/** What the running stack adds to the database's features: abilities that depend on its
 * configuration, not on its migrations. `timetable-scan` needs the optional OCR service
 * (OCR_URL, specs/24): an app hides the scan where it is missing. */
export function runtimeFeatures(
  env: (name: string) => string | undefined,
): string[] {
  const features: string[] = [];
  if (env("OCR_URL")?.trim()) features.push("timetable-scan");
  return features;
}

/** The release in WW_SERVER_VERSION, which `wuselwall install` and `update` write into the
 * stack's settings; undefined when unset or not a version. */
export function serverVersion(
  env: (name: string) => string | undefined,
): string | undefined {
  const value = env("WW_SERVER_VERSION")?.trim();
  return value && /^\d+\.\d+\.\d+$/.test(value) ? value : undefined;
}

/**
 * The server's public address: WW_PUBLIC_URL if the operator set one, else
 * SUPABASE_PUBLIC_URL (the compose stack), else SUPABASE_URL when it is public
 * (hosted Supabase). The compose stack's SUPABASE_URL is the internal gateway
 * (http://api-gw:8000) and must never reach a client.
 */
export function publicUrl(
  env: (name: string) => string | undefined,
): string | undefined {
  for (const name of ["WW_PUBLIC_URL", "SUPABASE_PUBLIC_URL", "SUPABASE_URL"]) {
    const value = env(name)?.trim().replace(/\/+$/, "");
    if (value && /^https:\/\/[^/]+$/.test(value)) return value;
  }
  return undefined;
}

/**
 * The key the apps use: the publishable key (opaque, `sb_publishable_…`), or the legacy
 * anon JWT where a stack has no publishable key. Never a secret or service-role key.
 *
 * WW_PUBLISHABLE_KEY comes first: a hosted project's Edge runtime has no
 * SUPABASE_PUBLISHABLE_KEYS, so deploy-supabase.yml reads the project's publishable key
 * from the Management API and sets it as a function secret. The compose stack passes
 * SUPABASE_PUBLISHABLE_KEYS (upstream's docker-compose.yml).
 */
export function publishableKey(
  env: (name: string) => string | undefined,
): string | undefined {
  const own = env("WW_PUBLISHABLE_KEY")?.trim();
  if (own?.startsWith("sb_publishable_")) return own;
  const keys = env("SUPABASE_PUBLISHABLE_KEYS");
  if (keys) {
    try {
      const parsed = JSON.parse(keys) as Record<string, unknown>;
      const key = parsed["default"] ?? Object.values(parsed)[0];
      if (typeof key === "string" && key.startsWith("sb_publishable_")) {
        return key;
      }
    } catch {
      // Malformed: fall through to the legacy key.
    }
  }
  const anon = env("SUPABASE_ANON_KEY");
  return anon && anon.length > 0 ? anon : undefined;
}

/**
 * Whether this server signs in with email codes, from Auth's public settings
 * (`GET /auth/v1/settings`). A server without mail autoconfirms addresses
 * (`mailer_autoconfirm`, set by the installers exactly when no mail is configured), so it
 * offers passwords only. Settings that cannot be read count as a server with mail, as every
 * server was before mail became optional.
 */
export function emailCode(settings: unknown): boolean {
  const s = settings as { mailer_autoconfirm?: unknown } | null;
  return !(s !== null && typeof s === "object" &&
    s.mailer_autoconfirm === true);
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
    (r.claimed !== undefined && typeof r.claimed !== "boolean") ||
    !Array.isArray(r.features) ||
    !r.features.every((f) => typeof f === "string")
  ) {
    throw new Error("api.server_info() returned an unexpected shape");
  }
  return r as ServerInfoRow;
}

export function discoveryDocument(
  row: ServerInfoRow,
  key: string,
  url: string | undefined,
  stack: { features?: string[]; version?: string; emailCode?: boolean } = {},
): DiscoveryDocument {
  return {
    wuselwall: DISCOVERY_FORMAT,
    ...(url ? { supabase_url: url } : {}),
    publishable_key: key,
    api_version: row.api_version,
    min_app_version: row.min_app_version,
    household_creation: row.household_creation,
    ...(typeof row.claimed === "boolean" ? { claimed: row.claimed } : {}),
    sign_in: { password: true, email_code: stack.emailCode ?? true },
    features: [...new Set([...row.features, ...(stack.features ?? [])])],
    ...(stack.version ? { server_version: stack.version } : {}),
  };
}

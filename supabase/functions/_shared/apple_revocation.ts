// Settling Apple revocation obligations (specs/22 item 6; migration 20261017110000).
//
// When an account with a stored Apple refresh token is deleted, the database keeps the encrypted
// token as an obligation (app.apple_revocation). This tries them: account-delete right after the
// deletion (its own), household-purge once a day (all that are due). Each attempt is recorded:
// a success removes the obligation, anything else keeps it with a short reason code, so a
// missing configuration, a wrong key or Apple being down never loses the token. Nothing here
// blocks an account deletion, and no token or response body is ever logged or returned.
//
// Pure apart from the injected database calls and `fetch`: the tests pass fakes.

import {
  appleClientSecret,
  type AppleConfig,
  AppleError,
  type AppleFetch,
  decryptToken,
  revokeRefreshToken,
} from "./apple.ts";

export type RevocationRow = { id: string; refresh_token_enc: string; attempts: number };

export type RevocationStore = {
  /** api.apple_revocation_due: a deleted user's obligations, or (no user) every due one. */
  due(user?: string): Promise<RevocationRow[]>;
  /** api.apple_revocation_record: null = revoked (the row goes), else the reason code. */
  record(id: string, error: string | null): Promise<void>;
};

export type RevocationOutcome = {
  /** Obligations this run looked at. */
  tried: number;
  revoked: number;
  /** Kept for a later attempt (including those without a configuration). */
  kept: number;
  /** True when the Apple values are missing: nothing could be revoked. */
  unconfigured: boolean;
};

function code(err: unknown): string {
  return err instanceof AppleError ? err.code : "internal";
}

/** Tries the obligations of `user` (or every due one) and records each outcome. */
export async function settleRevocations(
  store: RevocationStore,
  config: AppleConfig | null,
  options: { user?: string; fetchFn?: AppleFetch; now?: Date } = {},
): Promise<RevocationOutcome> {
  const rows = await store.due(options.user);
  const outcome: RevocationOutcome = { tried: rows.length, revoked: 0, kept: 0, unconfigured: !config };
  if (rows.length === 0) return outcome;

  if (!config) {
    for (const row of rows) await store.record(row.id, "config_missing");
    outcome.kept = rows.length;
    return outcome;
  }

  let clientSecret: string;
  try {
    clientSecret = await appleClientSecret(config, options.now ?? new Date());
  } catch (err) {
    for (const row of rows) await store.record(row.id, code(err));
    outcome.kept = rows.length;
    return outcome;
  }

  for (const row of rows) {
    let refresh: string;
    try {
      refresh = await decryptToken(row.refresh_token_enc, config.tokenKey);
    } catch {
      await store.record(row.id, "decrypt_failed");
      outcome.kept++;
      continue;
    }
    try {
      await revokeRefreshToken(
        refresh,
        { clientId: config.clientId, clientSecret },
        options.fetchFn ?? fetch,
      );
    } catch (err) {
      await store.record(row.id, code(err));
      outcome.kept++;
      continue;
    }
    await store.record(row.id, null);
    outcome.revoked++;
  }
  return outcome;
}

/** The store over a service-role Supabase client. */
export function rpcRevocationStore(
  // deno-lint-ignore no-explicit-any
  client: { rpc: (fn: string, args?: Record<string, unknown>) => any },
): RevocationStore {
  return {
    async due(user?: string) {
      const { data, error } = await client.rpc("apple_revocation_due", user ? { p_user: user } : {});
      if (error) throw error;
      return (data ?? []) as RevocationRow[];
    },
    async record(id: string, err: string | null) {
      const { error } = await client.rpc("apple_revocation_record", { p_id: id, p_error: err });
      if (error) throw error;
    },
  };
}

// POST → deletes the caller's account (specs/20 J6, "Konto löschen"; specs/16 step 9.6).
//
// Steps, in order:
//   1. The caller is verified with their own JWT (getUser). Nothing else is trusted from the body.
//   2. The sign-in must be recent: a sign-in within five minutes (the `amr` claim), else 403
//      reauth_required. The app then asks for a fresh sign-in and retries once.
//   3. api.account_delete_prepare decides (the last guardian with an account is refused, 409)
//      and unlinks the profile, revokes the account's devices and closes the family if this
//      was its only person.
//   4. Apple's refresh token, if one was stored, is revoked at Apple. Apple unreachable is
//      logged, not fatal: the account goes either way.
//   5. The Auth user is deleted with the Admin API, and with it every session.
//
// The service role is used in steps 3 to 5, and only for the user verified in step 1: both
// calls pass that user's id, and the database function refuses any other caller.
import {
  errorResponse,
  json,
  preflight,
  RequestError,
  requirePost,
  serviceClient,
} from "../_shared/client.ts";
import { amrOf, RECENT_SIGN_IN_SECONDS, signedInRecently, verifiedCaller } from "../_shared/caller.ts";
import {
  appleClientSecret,
  appleConfig,
  AppleError,
  decryptToken,
  revokeRefreshToken,
} from "../_shared/apple.ts";

/** A refusal in the shape the apps read: `hint` carries the stable reason. */
function refusal(status: number, error: string, message: string): Response {
  return json({ error, code: "42501", message, hint: error }, status);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const { user, token } = await verifiedCaller(req);

    if (!signedInRecently(amrOf(token), new Date(), RECENT_SIGN_IN_SECONDS)) {
      return refusal(403, "reauth_required", "sign in again to delete the account");
    }

    // Service role, for the verified caller only (the database checks the caller's user id).
    const service = serviceClient();
    const { data: prepared, error: prepareError } = await service.rpc("account_delete_prepare", {
      p_user: user.id,
    });
    if (prepareError) throw prepareError;
    const outcome = prepared as { ok?: boolean; reason?: string } | null;
    if (!outcome?.ok) {
      const reason = outcome?.reason ?? "refused";
      return refusal(409, reason, `account deletion refused: ${reason}`);
    }

    // The stored Apple token is read before the user goes, and revoked after: the row cascades
    // away with the user.
    const config = appleConfig();
    let appleRefresh: string | null = null;
    if (config) {
      const { data: enc, error: getError } = await service.rpc("apple_token_get", { p_user: user.id });
      if (getError) throw getError;
      if (typeof enc === "string" && enc !== "") {
        try {
          appleRefresh = await decryptToken(enc, config.tokenKey);
        } catch {
          console.error("account-delete: the stored Apple token could not be decrypted");
        }
      }
    }

    // Service role: the Admin API deletes exactly the verified user.
    const { error: deleteError } = await service.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    if (config && appleRefresh) {
      try {
        const secret = await appleClientSecret(config);
        await revokeRefreshToken(appleRefresh, { clientId: config.clientId, clientSecret: secret });
      } catch (err) {
        console.error("account-delete: Apple revoke failed:", err instanceof AppleError ? err.code : "internal");
      }
    }

    return json({ ok: true, household_deleted: (prepared as { household_deleted?: boolean }).household_deleted === true });
  } catch (err) {
    return errorResponse(err);
  }
});

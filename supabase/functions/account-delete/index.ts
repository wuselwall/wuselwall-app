// POST → deletes the caller's account (specs/20 J6, "Konto löschen"; specs/16 step 9.6).
//
// Steps, in order:
//   1. The caller is verified with their own JWT (getUser). Nothing else is trusted from the body.
//   2. The sign-in must be recent: a sign-in within five minutes (the `amr` claim), else 403
//      reauth_required. The app then asks for a fresh sign-in and retries once.
//   3. api.account_delete_prepare decides (the last guardian with an account is refused, 409)
//      and unlinks the profile, revokes the account's devices and closes the family if this
//      was its only person.
//   4. The Auth user is deleted with the Admin API, and with it every session.
//
// The service role is used in steps 3 and 4, and only for the user verified in step 1: both
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

    // Service role: the Admin API deletes exactly the verified user.
    const { error: deleteError } = await service.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return json({ ok: true, household_deleted: (prepared as { household_deleted?: boolean }).household_deleted === true });
  } catch (err) {
    return errorResponse(err);
  }
});

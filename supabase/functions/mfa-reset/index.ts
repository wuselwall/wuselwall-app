// POST {actor_profile_id, profile_id} → removes another guardian's authenticator (TOTP) factors
// (specs/20 J4: "Zwei-Faktor zurücksetzen", a guardian action, audited).
//
// Three steps:
//   1. The caller is verified with their own JWT (getUser), and the sign-in must be fresh: a
//      sign-in within five minutes (`amr`), else 403 reauth_required; and, when the caller's
//      own account has a verified authenticator, proven in this session (`aal2` with a
//      second-factor entry), else 403 mfa_required (security review 2026-11-01, F3).
//   2. api.mfa_reset_check runs as the CALLER (the user's JWT, not the service role). The SQL
//      decides: the caller is a guardian on a personal device with the same fresh sign-in,
//      the target is another active guardian of the same family with an account, and this
//      guardian did not issue a password reset code for the same person within 24 hours. It
//      audits the reset and returns that target's Auth user id, address and name. Any refusal
//      is returned as the database's error.
//   3. Only then the service role lists that user's factors and deletes each TOTP factor with
//      the Admin API. This acts only on the co-guardian the SQL check approved in step 2, never
//      on the id in the request body. Afterwards the target is told by mail, when the server
//      can send one from a function (the Scaleway values of the send-email hook); otherwise
//      the log says that no notice went out. The reset itself does not depend on the mail.
//
// Authentication: the compose stack runs the functions router with FUNCTIONS_VERIFY_JWT=false,
// so verifiedCaller (getUser) is the check, not the gateway.
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
  serviceClient,
  userClient,
} from "../_shared/client.ts";
import { stepUpRefusal, verifiedCaller } from "../_shared/caller.ts";
import { notifyTarget } from "./notice.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** A refusal in the shape the apps read: `hint` carries the stable reason. */
function refusal(status: number, error: string, message: string): Response {
  return json({ error, code: "42501", message, hint: error }, status);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const body = await readBody(req);
    const actor = body.actor_profile_id;
    const profile = body.profile_id;
    if (typeof actor !== "string" || !UUID.test(actor) || typeof profile !== "string" || !UUID.test(profile)) {
      throw new RequestError(400, "body_invalid", "actor_profile_id and profile_id are required", "body_invalid");
    }

    const { user, token } = await verifiedCaller(req);
    const stepUp = stepUpRefusal(user, token, new Date());
    if (stepUp === "reauth_required") {
      return refusal(403, stepUp, "sign in again to reset a second factor");
    }
    if (stepUp === "mfa_required") {
      return refusal(403, stepUp, "confirm the second factor to reset another one");
    }

    // The caller's own client: the SQL check runs under the caller's identity and device.
    const caller = userClient(req);
    const { data: approved, error: checkError } = await caller.rpc("mfa_reset_check", {
      p_actor: actor,
      p_profile: profile,
    });
    if (checkError) throw checkError;
    const target = approved as { user_id?: string; email?: string | null } | null;
    const targetUser = target?.user_id;
    if (typeof targetUser !== "string") {
      throw new RequestError(500, "internal", "internal error");
    }

    // Service role: the Admin API, for the co-guardian the check above approved. Nothing else.
    const service = serviceClient();
    const { data: listed, error: listError } = await service.auth.admin.mfa.listFactors({
      userId: targetUser,
    });
    if (listError) throw listError;
    let removed = 0;
    for (const factor of listed?.factors ?? []) {
      if (factor.factor_type !== "totp") continue;
      const { error: deleteError } = await service.auth.admin.mfa.deleteFactor({
        id: factor.id,
        userId: targetUser,
      });
      if (deleteError) throw deleteError;
      removed++;
    }
    const notified = removed > 0 ? await notifyTarget(target?.email) : false;
    return json({ ok: true, removed, notified });
  } catch (err) {
    return errorResponse(err);
  }
});

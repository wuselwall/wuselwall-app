// POST {actor_profile_id, profile_id} → removes another guardian's authenticator (TOTP) factors
// (specs/20 J4: "Zwei-Faktor zurücksetzen", a guardian action, audited).
//
// Two steps:
//   1. api.mfa_reset_check runs as the CALLER (the user's JWT, not the service role). The SQL
//      decides: the caller is a guardian on a personal device, the target is another active
//      guardian of the same family with an account. It audits the reset and returns that
//      target's Auth user id. Any refusal is returned as the database's error.
//   2. Only then the service role lists that user's factors and deletes each TOTP factor with
//      the Admin API. This acts only on the co-guardian the SQL check approved in step 1, never
//      on the id in the request body.
//
// The caller's JWT is verified by the gateway and again by getUser.
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
import { verifiedCaller } from "../_shared/caller.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

    await verifiedCaller(req);

    // The caller's own client: the SQL check runs under the caller's identity and device.
    const caller = userClient(req);
    const { data: approved, error: checkError } = await caller.rpc("mfa_reset_check", {
      p_actor: actor,
      p_profile: profile,
    });
    if (checkError) throw checkError;
    const targetUser = (approved as { user_id?: string } | null)?.user_id;
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
    return json({ ok: true, removed });
  } catch (err) {
    return errorResponse(err);
  }
});

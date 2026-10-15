// POST {authorization_code} → stores Apple's refresh token for the caller, encrypted (specs/20
// "Server side"; specs/10 §4). The apps send Apple's one-time authorisation code here right
// after a native Sign in with Apple. The code is exchanged for a refresh token, which is what
// account-delete needs to revoke Apple's access later. Failures are ignored by the apps: a
// missing token only means the revocation cannot be done, and the deletion still goes ahead.
//
// The caller is verified with their own JWT (getUser). The service role is used for one thing:
// api.apple_token_put, which writes the encrypted token. It acts only on the verified caller's
// user id, never on one from the request body.
//
// Without the Apple environment (APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID,
// APPLE_TOKEN_KEY) the answer is 501 apple_not_configured: a server without Apple.
import {
  errorResponse,
  json,
  preflight,
  readBody,
  RequestError,
  requirePost,
  serviceClient,
} from "../_shared/client.ts";
import { verifiedCaller } from "../_shared/caller.ts";
import {
  appleClientSecret,
  appleConfig,
  AppleError,
  encryptToken,
  exchangeAuthorizationCode,
} from "../_shared/apple.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflight();
  try {
    requirePost(req);
    const config = appleConfig();
    if (!config) {
      return json({ code: "apple_not_configured", message: "Sign in with Apple is not configured", hint: null }, 501);
    }

    const body = await readBody(req);
    const code = body.authorization_code;
    if (typeof code !== "string" || code.trim() === "" || code.length > 4096) {
      throw new RequestError(400, "code_invalid", "authorization_code is required", "code_invalid");
    }

    const { user } = await verifiedCaller(req);

    let refresh: string;
    try {
      const secret = await appleClientSecret(config);
      refresh = await exchangeAuthorizationCode(code.trim(), {
        clientId: config.clientId,
        clientSecret: secret,
      });
    } catch (err) {
      console.error("apple-token exchange failed:", err instanceof AppleError ? err.code : "internal");
      throw new RequestError(502, "apple_failed", "Apple did not accept the code", "apple_failed");
    }
    const encrypted = await encryptToken(refresh, config.tokenKey);

    // Service role: the write is for the verified caller only (see the header comment).
    const service = serviceClient();
    const { error } = await service.rpc("apple_token_put", {
      p_user: user.id,
      p_enc: encrypted,
    });
    if (error) throw error;
    return json({ ok: true });
  } catch (err) {
    return errorResponse(err);
  }
});

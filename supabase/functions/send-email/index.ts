// POST: GoTrue's Send Email Hook (specs/10 §4, specs/20 "Email"). Auth calls it instead of
// sending a mail itself, with the recipient, the action and the code, and signs the request
// with SEND_EMAIL_HOOK_SECRET (Standard Webhooks). The logic is in _shared/send_email_hook.ts.
//
// Authentication: none by JWT. GoTrue calls this without one, so the router lists
// `send-email` in NO_USER_FUNCTIONS (infra/supabase/volumes/functions/main/index.ts), and the
// webhook signature is the only gate.
//
// Environment: SEND_EMAIL_HOOK_SECRET, SCW_SECRET_KEY, SCW_PROJECT_ID, MAIL_FROM (required);
// SCW_REGION (default fr-par) and MAIL_FROM_NAME (default WuselWall). Set on the stack's
// .env for the compose stack (infra/supabase/docker-compose.wuselwall.yml) and in
// supabase/.env for a laptop stack.
import { sendEmailHook, settingsFromEnv } from "../_shared/send_email_hook.ts";

Deno.serve(async (req: Request) => {
  const loaded = settingsFromEnv((name) => Deno.env.get(name));
  if (!loaded.ok) {
    // Names only: the variables are missing, their values never appear in a log.
    console.error(
      `send-email: not configured, missing ${loaded.missing.join(", ")}`,
    );
    return Response.json(
      { error: { http_code: 500, message: "send-email is not configured" } },
      { status: 500 },
    );
  }
  return await sendEmailHook(req, loaded.settings);
});

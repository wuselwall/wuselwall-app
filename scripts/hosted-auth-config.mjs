#!/usr/bin/env node
// The Auth settings of a family's hosted Supabase project (deploy-supabase.yml): the choices
// supabase/config.toml and the compose overlay (infra/supabase/docker-compose.wuselwall.yml)
// make, as Management API keys, read back afterwards. Run on every deploy; harmless to repeat.
//
//   PROJECT=<ref> SUPABASE_ACCESS_TOKEN=… [mail variables] node scripts/hosted-auth-config.mjs
//
// Mail is optional (specs/20, Q48). Without it Auth autoconfirms addresses: sign-up and
// sign-in use a password, and the app offers no email code (the discovery document reads
// mailer_autoconfirm). With mail, sign-in codes confirm the address. Mail is one of:
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SENDER [, SMTP_SENDER_NAME]
//       any SMTP server (a transactional provider, or Gmail with an app password); GoTrue
//       sends the code templates
//   SEND_EMAIL_HOOK_SECRET (v1,whsec_…)
//       the Send Email Hook: Auth hands every mail to the send-email function, which the
//       workflow has configured with the Scaleway values; the secret is the one it checks
// Both SMTP and the hook may be set: the hook sends, SMTP is the fallback when it is off.
// Supabase's built-in mailer is never used for the family: it delivers only to the
// account's own addresses, a few times an hour.
//
// Prints key names, never values.
import { pathToFileURL } from 'node:url';

/** Keys whose values the API does not echo, or must not be compared or logged. */
export const SECRET_KEYS = Object.freeze(['smtp_pass', 'hook_send_email_secrets']);

/** The mail configuration the environment describes; {} for a server without mail. */
export function mailFromEnv(env) {
  const mail = {};
  if (env.SMTP_HOST) {
    for (const name of ['SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'SMTP_SENDER']) {
      if (!env[name]) throw new Error(`SMTP_HOST is set, so ${name} is needed too`);
    }
    if (!/^\d+$/.test(env.SMTP_PORT)) throw new Error('SMTP_PORT must be a number');
    mail.smtp = {
      host: env.SMTP_HOST, port: env.SMTP_PORT, user: env.SMTP_USER, pass: env.SMTP_PASS,
      sender: env.SMTP_SENDER, senderName: env.SMTP_SENDER_NAME || 'WuselWall',
    };
  }
  if (env.SEND_EMAIL_HOOK_SECRET) {
    if (!/^v1,whsec_[A-Za-z0-9+/=]+$/.test(env.SEND_EMAIL_HOOK_SECRET)) {
      throw new Error('SEND_EMAIL_HOOK_SECRET must look like v1,whsec_<base64>');
    }
    mail.hook = { secret: env.SEND_EMAIL_HOOK_SECRET };
  }
  return mail;
}

/** The PATCH body for /v1/projects/{ref}/config/auth. */
export function authPatch({ project, mail }) {
  if (!/^[a-z0-9]{20}$/.test(project)) throw new Error('PROJECT is the 20-letter reference ID');
  const base = `https://${project}.supabase.co`;
  const patch = {
    site_url: base,
    // Sign-up is on (specs/20, config.toml [auth] enable_signup): the founder and every
    // invited person sign up, with an email code or, without mail, a password. A stranger's
    // account can do nothing (RLS) until it is invited or founds the household with the
    // setup token.
    disable_signup: false,
    external_email_enabled: true,
    // Autoconfirm exactly when no mail is sent; an autoconfirmed address is never trusted
    // for an invitation (app.proven_email).
    mailer_autoconfirm: !mail.smtp && !mail.hook,
    mailer_secure_email_change_enabled: true,
    // The access-token hook puts household and device into every token.
    hook_custom_access_token_enabled: true,
    hook_custom_access_token_uri: 'pg-functions://postgres/app/custom_access_token_hook',
    // TOTP as the second factor; a guardian's password has at least 10 characters.
    mfa_totp_enroll_enabled: true,
    mfa_totp_verify_enabled: true,
    mfa_max_enrolled_factors: 10,
    password_min_length: 10,
    security_refresh_token_reuse_interval: 10,
    // The compose overlay's limits; a new code per address at most every 60 s.
    rate_limit_token_refresh: 150,
    rate_limit_verify: 30,
    rate_limit_otp: 30,
    rate_limit_anonymous_users: 30,
    smtp_max_frequency: 60,
    hook_send_email_enabled: Boolean(mail.hook),
  };
  if (mail.smtp) {
    Object.assign(patch, {
      smtp_host: mail.smtp.host,
      smtp_port: String(mail.smtp.port),
      smtp_user: mail.smtp.user,
      smtp_pass: mail.smtp.pass,
      smtp_admin_email: mail.smtp.sender,
      smtp_sender_name: mail.smtp.senderName,
    });
  }
  if (mail.hook) {
    Object.assign(patch, {
      hook_send_email_uri: `${base}/functions/v1/send-email`,
      hook_send_email_secrets: mail.hook.secret,
    });
  }
  // The built-in mailer's limit is for testing; with a provider of your own, 30 an hour.
  if (mail.smtp || mail.hook) patch.rate_limit_email_sent = 30;
  return patch;
}

/** The keys of [patch] that [actual] (the GET readback) does not show as sent. */
export function problems(actual, patch) {
  return Object.keys(patch).filter((key) => !SECRET_KEYS.includes(key) && actual[key] !== patch[key]);
}

export async function configureAuth({ project, token, env = {}, fetchFn = fetch, log = console.log }) {
  if (!project || !token) throw new Error('PROJECT and SUPABASE_ACCESS_TOKEN are required');
  const mail = mailFromEnv(env);
  const patch = authPatch({ project, mail });
  const call = async (method, body) => {
    const response = await fetchFn(`https://api.supabase.com/v1/projects/${project}/config/auth`, {
      method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    if (!response.ok) throw new Error(`${method} config/auth: HTTP ${response.status}`);
    return response;
  };
  await call('PATCH', patch);
  const actual = await (await call('GET')).json();
  const wrong = problems(actual, patch);
  if (wrong.length > 0) throw new Error(`Auth settings not applied: ${wrong.join(', ')}`);
  const how = mail.hook ? 'sign-in codes through the send-email hook'
    : mail.smtp ? 'sign-in codes through SMTP'
    : 'no mail: sign-in with email and password, addresses autoconfirmed';
  log(`Auth: ${Object.keys(patch).length} settings applied and read back; ${how}`);
  return { patch, mail };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  configureAuth({ project: process.env.PROJECT, token: process.env.SUPABASE_ACCESS_TOKEN, env: process.env })
    .catch((err) => { console.error(`::error::${err.message}`); process.exitCode = 1; });
}

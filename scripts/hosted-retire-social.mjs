#!/usr/bin/env node
// Retires social sign-in on a family's hosted Supabase project (specs/22, "Credential and
// external-client retirement", items 1 and 3). Run by .github/workflows/deploy-supabase.yml on
// every deploy, after the Auth settings; harmless to run again.
//
//   SUPABASE_ACCESS_TOKEN=… PROJECT=<ref> node scripts/hosted-retire-social.mjs
//
// A Management API update changes only the keys it names: a project that once had Google or
// Apple switched on keeps them on through every later deploy that simply leaves them out. So
// this names them:
//   - Google and Apple sign-in off, their login client IDs and secrets (the GoTrue Apple
//     client-secret JWT, the Google OAuth secret) emptied, manual identity linking off;
//   - the redirect allow-list emptied: its only entry was the native apps' OAuth callback
//     (ch.goomba.wuselwall://login-callback/). E-mail links go to site_url, which stays.
//   - the apple-token Edge Function deleted if it is still deployed: deploying the remaining
//     functions does not remove one that is no longer in the repository.
// Then it reads the settings and the function list back and fails unless they show the result.
//
// Kept, on purpose: the APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID and
// APPLE_TOKEN_KEY Edge Function secrets. account-delete needs them to revoke the Apple tokens of
// accounts from before the removal; they are not sign-in settings.
//
// Prints no secret and no setting value, only what changed and what was checked.

export const RETIRED_AUTH = Object.freeze({
  external_google_enabled: false,
  external_google_client_id: '',
  external_google_secret: '',
  external_google_additional_client_ids: '',
  external_apple_enabled: false,
  external_apple_client_id: '',
  external_apple_secret: '',
  external_apple_additional_client_ids: '',
  security_manual_linking_enabled: false,
  uri_allow_list: '',
});

export const RETIRED_FUNCTIONS = Object.freeze(['apple-token']);

const OBSOLETE_REDIRECT = /login-callback/;

/** What is still wrong with these Auth settings (empty: retired). Never includes values. */
export function authProblems(config) {
  const problems = [];
  if (config.external_google_enabled !== false) problems.push('Google sign-in is still enabled');
  if (config.external_apple_enabled !== false) problems.push('Apple sign-in is still enabled');
  if (config.security_manual_linking_enabled !== false) problems.push('manual identity linking is still enabled');
  if (OBSOLETE_REDIRECT.test(config.uri_allow_list ?? '')) {
    problems.push('the redirect allow-list still holds the native OAuth callback');
  }
  return problems;
}

/** Login credentials still stored (a warning: the API may mask or keep them). */
export function storedLoginCredentials(config) {
  return ['external_google_client_id', 'external_google_secret', 'external_apple_client_id', 'external_apple_secret']
    .filter((k) => typeof config[k] === 'string' && config[k] !== '');
}

export async function retire({ project, token, fetchFn = fetch, log = console.log }) {
  if (!project || !token) throw new Error('PROJECT and SUPABASE_ACCESS_TOKEN are required');
  const base = `https://api.supabase.com/v1/projects/${project}`;
  const call = async (method, path, body) => {
    const res = await fetchFn(`${base}/${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`${method} ${path}: HTTP ${res.status}`);
    const text = await res.text();
    return text ? JSON.parse(text) : null;
  };

  const before = await call('GET', 'config/auth');
  const wasOn = authProblems(before);
  await call('PATCH', 'config/auth', RETIRED_AUTH);
  const after = await call('GET', 'config/auth');
  const left = authProblems(after);
  if (left.length) throw new Error(`Auth settings not retired: ${left.join('; ')}`);
  log(wasOn.length ? `Auth: switched off (${wasOn.join('; ')})` : 'Auth: social sign-in was already off');
  const stored = storedLoginCredentials(after);
  if (stored.length) log(`::warning::login credentials still reported as set: ${stored.join(', ')}`);

  const deployed = (await call('GET', 'functions')) ?? [];
  for (const slug of RETIRED_FUNCTIONS) {
    if (deployed.some((f) => f.slug === slug)) {
      await call('DELETE', `functions/${slug}`);
      log(`Edge Function ${slug}: deleted`);
    } else {
      log(`Edge Function ${slug}: not deployed`);
    }
  }
  const remaining = ((await call('GET', 'functions')) ?? []).map((f) => f.slug);
  const still = RETIRED_FUNCTIONS.filter((s) => remaining.includes(s));
  if (still.length) throw new Error(`still deployed: ${still.join(', ')}`);
  return { switchedOff: wasOn, deletedFunctions: RETIRED_FUNCTIONS.filter((s) => deployed.some((f) => f.slug === s)) };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  retire({ project: process.env.PROJECT, token: process.env.SUPABASE_ACCESS_TOKEN })
    .catch((err) => {
      console.error(`::error::${err.message}`);
      process.exit(1);
    });
}

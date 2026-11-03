#!/usr/bin/env node
// Writes the compose stack's .env (ADR-013 amendment) to stdout. Run once per server: by
// `scripts/remote-stack.sh init-env` (over SSH, from a checkout) or by server/wuselwall
// (on the server, from a release; docs/server). The output holds every secret; nothing is stored here.
//
// Usage:
//   node make-env.mjs [supabase/.env] --api https://api.example.org --web https://web.example.org
//                     [--admin-email you@example.org] [--language de|en|fr|es]
//                     [--rp-id example.org] [--studio] [--caddy]
//
//   supabase/.env  optional. WW_JWT_SECRET, WW_PUBLISHABLE_KEY and WW_SECRET_KEY are kept
//                  from it, so the apps and every device session of an existing server keep
//                  working; WW_CRON_SECRET is taken over when present. Published defaults,
//                  placeholders and short values are refused, and each key kept is named on
//                  stderr with a fingerprint. Whatever is missing is generated. Mail settings
//                  in it (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SENDER, or the
//                  Scaleway hook's SCW_* and MAIL_FROM) are taken over too; without them the
//                  server sends no mail (see below).
//   --api          the server's public address (the gateway behind HTTPS)
//   --web          where the web app is served; Auth sends its redirects there
//   --rp-id        the passkey relying party (default: the web app's host)
//   --studio       keep Studio and its metadata service (switched off otherwise; see
//                  docker-compose.lean.yml)
//   --caddy        add the Caddy front (docker-compose.caddy.yml): HTTPS from Let's Encrypt
//                  for both hosts, the web app, and /.well-known/wuselwall.json
//
// Generated: the Postgres password and the services' own secrets, an EC P-256 key pair
// that signs new tokens, the ES256 "internal API keys" the gateway swaps the opaque keys
// for, and legacy HS256 anon/service JWTs (only the containers' health checks use them).
// The crypto follows upstream's utils/add-new-auth-keys.sh.
import crypto from 'node:crypto';
import fs from 'node:fs';

const args = process.argv.slice(2);
const valued = ['--api', '--web', '--admin-email', '--rp-id', '--language'];
const flag = (name) => args.includes(`--${name}`);
const option = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const fail = (message) => {
  console.error(`make-env: ${message}`);
  process.exit(2);
};
const src = args.find((a, i) => !a.startsWith('--') && !valued.includes(args[i - 1]));

const origin = (name) => {
  const value = option(name);
  if (!value) fail(`--${name} https://… is required`);
  let url;
  try {
    url = new URL(value);
  } catch {
    fail(`--${name}: not an address: ${value}`);
  }
  if (url.protocol !== 'https:' || url.pathname !== '/' || url.search || url.hash) {
    fail(`--${name}: an https:// origin without a path, e.g. https://api.example.org`);
  }
  return url;
};
const api = origin('api');
const web = origin('web');
const mailSubjects = { de: 'Dein WuselWall-Code', en: 'Your WuselWall code', fr: 'Votre code WuselWall', es: 'Tu código de WuselWall' };
const language = option('language') ?? 'de';
if (!Object.hasOwn(mailSubjects, language)) fail('--language must be de, en, fr or es');

const vars = src
  ? Object.fromEntries(
    fs.readFileSync(src, 'utf8').split('\n')
      .map((l) => l.trim()).filter((l) => l && !l.startsWith('#') && l.includes('='))
      .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')]),
  )
  : {};

const hex = (n) => crypto.randomBytes(n).toString('hex');
const b64 = (n) => crypto.randomBytes(n).toString('base64');
const b64url = (x) => Buffer.from(x).toString('base64url');

// Keys taken over from the source file must be this server's own (security review
// 2026-11-01, F8). The Supabase CLI's defaults are printed in its source and in every
// tutorial: a stack that signs with the public JWT secret, or that accepts the public
// sb_secret_ key (the gateway swaps it for the service role), belongs to whoever reads them.
// The list holds the CLI's JWT secret, publishable and secret keys and its demo anon and
// service-role tokens, upstream docker/.env.example's JWT secret, and this repository's
// placeholders (supabase/.env.example). A value is also refused when it is too short or too
// uniform to be random, when it is a JWT (no kept variable holds one), or when it contains
// a placeholder word.
const PUBLIC_VALUES = new Set([
  'super-secret-jwt-token-with-at-least-32-characters-long',
  'your-super-secret-jwt-token-with-at-least-32-characters-long',
  'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  'sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz',
  'sb_publishable_wLdx7w89KWFq-39s4emmnA__9XR9r-_',
  'sb_publishable__4DBgvrDe7ec234wnvCAog_LPzBtkQe',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU',
]);
const PLACEHOLDER = /replace-?me|change-?me|placeholder|example|your-|secret-jwt|xxxxxxxx/i;
// Each kept variable: its prefix and the shortest random part make-env.mjs would accept. 32
// characters for the secrets (make-env.mjs generates 64 hex digits), 22 for the opaque keys
// (16 random bytes in base64url, as generated below and by Supabase).
const KEPT = {
  WW_JWT_SECRET: { prefix: '', min: 32 },
  WW_PUBLISHABLE_KEY: { prefix: 'sb_publishable_', min: 22 },
  WW_SECRET_KEY: { prefix: 'sb_secret_', min: 22 },
  WW_CRON_SECRET: { prefix: '', min: 32 },
};
const fingerprint = (value) => crypto.createHash('sha256').update(value).digest('hex').slice(0, 8);
for (const [name, { prefix, min }] of Object.entries(KEPT)) {
  const value = vars[name];
  if (!value) continue;
  const refuse = (why) => fail(`${name} in ${src} ${why}. Delete the line to have a fresh value generated ` +
    '(a running server then needs its devices connected again), or put in the value of the server that already uses it.');
  if (PUBLIC_VALUES.has(value)) refuse('is a published default (Supabase CLI or upstream example), not a secret');
  if (/^eyJ[\w-]*\.[\w-]*\.[\w-]*$/.test(value)) refuse('is a JWT; it must be the key itself');
  if (!value.startsWith(prefix)) refuse(`must start with ${prefix}`);
  const body = value.slice(prefix.length);
  if (PLACEHOLDER.test(body)) refuse('is a placeholder');
  if (Buffer.byteLength(body) < min) refuse(`is shorter than ${min} characters`);
  // Random text of that length uses many different characters: 64 random hex digits show all
  // 16 almost always, and fewer than 10 would be a pattern ("aaaa…", "abab…"), not a key.
  if (new Set(body).size < 10) refuse('repeats too few characters to be random');
  // The fingerprint lets an operator compare the key without printing it: the same command on
  // the old server's file, `printf %s "$value" | sha256sum | cut -c1-8`, shows the same 8 digits.
  console.error(`make-env: kept ${name} from ${src} (sha256 ${fingerprint(value)})`);
}

// A new server gets fresh keys. They land in the .env printed below (JWT_SECRET,
// SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY, CRON_SECRET): that file is the copy to keep.
vars.WW_JWT_SECRET ||= hex(32);
vars.WW_PUBLISHABLE_KEY ||= `sb_publishable_${b64url(crypto.randomBytes(16))}`;
vars.WW_SECRET_KEY ||= `sb_secret_${b64url(crypto.randomBytes(16))}`;
vars.WW_CRON_SECRET ||= hex(32);
const jwtSecret = vars.WW_JWT_SECRET;

const { privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
const jwk = privateKey.export({ format: 'jwk' });
const kid = crypto.randomUUID();
const oct = { kty: 'oct', k: b64url(jwtSecret), alg: 'HS256' };
const ec = { kty: 'EC', kid, use: 'sig', alg: 'ES256', ext: true, crv: jwk.crv, x: jwk.x, y: jwk.y };
const jwtKeys = [{ ...ec, key_ops: ['sign', 'verify'], d: jwk.d }, oct];
const jwks = { keys: [{ ...ec, key_ops: ['verify'] }, oct] };

const iat = Math.floor(Date.now() / 1000);
const exp = iat + 10 * 365 * 24 * 3600;
function sign(alg, payload) {
  const header = alg === 'ES256' ? { alg, typ: 'JWT', kid } : { alg, typ: 'JWT' };
  const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const sig = alg === 'ES256'
    ? crypto.sign('SHA256', Buffer.from(data), { key: privateKey, dsaEncoding: 'ieee-p1363' })
    : crypto.createHmac('sha256', jwtSecret).update(data).digest();
  return `${data}.${b64url(sig)}`;
}
const claims = (role) => ({ role, iss: 'supabase', iat, exp });

// The send-email hook runs only when the Scaleway project and key are there to send with.
const sendEmailHook = Boolean(vars.SCW_SECRET_KEY && vars.SCW_PROJECT_ID && vars.MAIL_FROM);
// Any SMTP server (a transactional provider, or a mailbox such as Gmail with an app password).
const smtp = vars.SMTP_HOST && vars.SMTP_HOST !== 'localhost' ? vars.SMTP_HOST : '';
// Mail is optional (specs/20, Q48). With it, sign-in codes confirm an address. Without it,
// Auth autoconfirms addresses so that sign-up with a password works, and an autoconfirmed
// address is never trusted for an invitation (app.proven_email). `wuselwall mail` switches
// later (mail-settings.sh, which decides the same way).
const mail = sendEmailHook || Boolean(smtp);

const out = {
  COMPOSE_FILE: [
    'docker-compose.yml',
    'docker-compose.wuselwall.yml',
    // Storage and imgproxy are unused; Studio and meta run only with --studio.
    'docker-compose.lean.yml',
    ...(flag('caddy') ? ['docker-compose.caddy.yml'] : []),
  ].join(':'),
  COMPOSE_PROFILES: flag('studio') ? 'studio' : '',

  // The scheduled jobs' shared secret (tasks-nightly, holidays-sync; infra/jobs).
  CRON_SECRET: vars.WW_CRON_SECRET,

  // Secrets
  POSTGRES_PASSWORD: hex(24),
  JWT_SECRET: jwtSecret,
  ANON_KEY: sign('HS256', claims('anon')),
  SERVICE_ROLE_KEY: sign('HS256', claims('service_role')),
  SUPABASE_PUBLISHABLE_KEY: vars.WW_PUBLISHABLE_KEY,
  SUPABASE_SECRET_KEY: vars.WW_SECRET_KEY,
  JWT_KEYS: JSON.stringify(jwtKeys),
  JWT_JWKS: JSON.stringify(jwks),
  ANON_KEY_ASYMMETRIC: sign('ES256', claims('anon')),
  SERVICE_ROLE_KEY_ASYMMETRIC: sign('ES256', claims('service_role')),
  DASHBOARD_USERNAME: 'wuselwall',
  DASHBOARD_PASSWORD: hex(16),
  SECRET_KEY_BASE: b64(48),
  REALTIME_DB_ENC_KEY: hex(8),
  VAULT_ENC_KEY: hex(16),
  PG_META_CRYPTO_KEY: b64(24),
  LOGFLARE_PUBLIC_ACCESS_TOKEN: b64(24),
  LOGFLARE_PRIVATE_ACCESS_TOKEN: b64(24),
  S3_PROTOCOL_ACCESS_KEY_ID: hex(16),
  S3_PROTOCOL_ACCESS_KEY_SECRET: hex(32),

  // URLs
  SUPABASE_PUBLIC_URL: api.origin,
  API_EXTERNAL_URL: `${api.origin}/auth/v1`,
  // Where GoTrue's e-mail links land: the web app, not the website (ADR-017).
  SITE_URL: `${web.origin}/`,
  // The web app.
  ADDITIONAL_REDIRECT_URLS: `${web.origin}/**`,
  // The relying party is the web app's own host: the store app offers passkeys to no chosen server (ADR-018).
  PASSKEY_RP_ID: option('rp-id') ?? web.hostname,
  PASSKEY_RP_ORIGINS: web.origin,
  // Read by the Caddy front (docker-compose.caddy.yml); harmless without it.
  WW_API_HOST: api.host,
  WW_WEB_HOST: web.host,

  // Ports (docker-compose.wuselwall.yml)
  GATEWAY_BIND: '172.17.0.1',
  GATEWAY_PORT: '54421',
  DB_PORT: '54422',

  // Database
  POSTGRES_HOST: 'db',
  POSTGRES_DB: 'postgres',
  POSTGRES_PORT: '5432',
  POOLER_PROXY_PORT_TRANSACTION: '6543',
  POOLER_DEFAULT_POOL_SIZE: '20',
  POOLER_MAX_CLIENT_CONN: '100',
  POOLER_TENANT_ID: 'wuselwall',
  POOLER_DB_POOL_SIZE: '5',

  // Studio (reached only through an SSH tunnel, behind DASHBOARD_* basic auth)
  STUDIO_DEFAULT_ORGANIZATION: 'WuselWall',
  STUDIO_DEFAULT_PROJECT: 'wuselwall',
  OPENAI_API_KEY: '',

  // Auth: supabase/config.toml [auth]
  JWT_EXPIRY: '3600',
  // The e-mail sign-in code (supabase/config.toml [auth.email]).
  MAILER_OTP_LENGTH: '6',
  MAILER_OTP_EXP: '600',
  // One operator-selected email language, independent of the device's UI locale.
  MAIL_LANGUAGE: language,
  MAIL_CODE_SUBJECT: mailSubjects[language],
  SMTP_MAX_FREQUENCY: '60s',
  // Strangers get an account that can do nothing but wait for an invitation or, while
  // household creation is in `code` mode, start a family with a founder code (specs/20).
  DISABLE_SIGNUP: 'false',
  ENABLE_EMAIL_SIGNUP: 'true',
  // Autoconfirm exactly when no mail is sent; email codes confirm the address by themselves.
  ENABLE_EMAIL_AUTOCONFIRM: mail ? 'false' : 'true',
  ENABLE_ANONYMOUS_USERS: 'false',
  ENABLE_PHONE_SIGNUP: 'false',
  ENABLE_PHONE_AUTOCONFIRM: 'false',
  MAILER_URLPATHS_CONFIRMATION: '/auth/v1/verify',
  MAILER_URLPATHS_INVITE: '/auth/v1/verify',
  MAILER_URLPATHS_RECOVERY: '/auth/v1/verify',
  MAILER_URLPATHS_EMAIL_CHANGE: '/auth/v1/verify',
  // GoTrue's own SMTP; an empty host sends nothing. The port stays a number even then:
  // Auth refuses to start with an empty one.
  SMTP_ADMIN_EMAIL: vars.SMTP_SENDER || option('admin-email') || `wuselwall@${web.hostname}`,
  SMTP_HOST: smtp,
  SMTP_PORT: smtp && /^\d+$/.test(vars.SMTP_PORT ?? '') ? vars.SMTP_PORT : '587',
  SMTP_USER: smtp ? vars.SMTP_USER ?? '' : '',
  SMTP_PASS: smtp ? vars.SMTP_PASS ?? '' : '',
  SMTP_SENDER_NAME: vars.SMTP_SENDER_NAME || 'WuselWall',

  // Mail: the Send Email Hook (supabase/functions/send-email). The secret is generated like the
  // others and must be the same value in GoTrue and in the functions container, which this file
  // guarantees by writing one variable for both. The hook is switched on only when the Scaleway
  // project and key from supabase/.env are present, so a stack never sends mail it cannot send.
  // GoTrue calls the hook at the server's public HTTPS address: it refuses a plain-http one
  // (other than localhost) and would not start (docker-compose.wuselwall.yml).
  SEND_EMAIL_HOOK_SECRET: `v1,whsec_${b64(32)}`,
  SEND_EMAIL_HOOK_ENABLED: sendEmailHook ? 'true' : 'false',
  SEND_EMAIL_HOOK_URI: sendEmailHook ? `${api.origin}/functions/v1/send-email` : '',
  SCW_SECRET_KEY: vars.SCW_SECRET_KEY ?? '',
  SCW_PROJECT_ID: vars.SCW_PROJECT_ID ?? '',
  SCW_REGION: vars.SCW_REGION ?? 'fr-par',
  MAIL_FROM: vars.MAIL_FROM ?? '',
  MAIL_FROM_NAME: vars.MAIL_FROM_NAME ?? 'WuselWall',

  // Storage
  GLOBAL_S3_BUCKET: 'stub',
  REGION: 'stub',
  STORAGE_TENANT_ID: 'stub',
  MINIO_ROOT_USER: 'unused',
  MINIO_ROOT_PASSWORD: hex(16),
  IMGPROXY_AUTO_WEBP: 'true',

  // Functions: each function checks the caller itself (the ICS feed has no JWT).
  FUNCTIONS_VERIFY_JWT: 'false',

  // PostgREST: supabase/config.toml [api]
  PGRST_DB_SCHEMAS: 'api',
  PGRST_DB_MAX_ROWS: '1000',
  PGRST_DB_EXTRA_SEARCH_PATH: 'extensions',

  // Unused overrides of upstream (logs, Kong); present so compose does not warn.
  DOCKER_SOCKET_LOCATION: '/var/run/docker.sock',
  GOOGLE_PROJECT_ID: 'unused',
  GOOGLE_PROJECT_NUMBER: 'unused',
};

// Single-quoted, so compose takes JSON and base64 verbatim.
for (const [name, value] of Object.entries(out)) {
  if (String(value).includes("'")) fail(`${name} must not contain a single quote`);
}
process.stdout.write(
  '# WuselWall compose stack. Generated by infra/supabase/make-env.mjs; secrets — never commit.\n' +
  Object.entries(out).map(([k, v]) => `${k}='${v}'`).join('\n') + '\n',
);

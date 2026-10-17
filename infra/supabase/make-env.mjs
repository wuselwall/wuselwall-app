#!/usr/bin/env node
// Writes the compose stack's .env (ADR-013 amendment) to stdout. Run once per server: by
// `scripts/remote-stack.sh init-env` (over SSH, from a checkout) or by server/wuselwall
// (on the server, from a release; docs/server). The output holds every secret; nothing is stored here.
//
// Usage:
//   node make-env.mjs [supabase/.env] --api https://api.example.org --web https://web.example.org
//                     [--admin-email you@example.org] [--rp-id example.org] [--studio] [--caddy]
//
//   supabase/.env  optional. WW_JWT_SECRET, WW_PUBLISHABLE_KEY and WW_SECRET_KEY are kept
//                  from it, so the apps and every device session of an existing server keep
//                  working; WW_CRON_SECRET and the WW_APPLE_* values (old Apple accounts) are taken
//                  over when present. Whatever is missing is generated.
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
const valued = ['--api', '--web', '--admin-email', '--rp-id'];
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
  ADDITIONAL_REDIRECT_URLS: `${web.origin}/**`,
  // Passkeys work in the native apps only for the first-party hosts (ADR-018); elsewhere
  // the web app's own host is the relying party.
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
  SMTP_MAX_FREQUENCY: '60s',
  // Strangers get an account that can do nothing but wait for an invitation or, while
  // household creation is in `code` mode, start a family with a founder code (specs/20).
  DISABLE_SIGNUP: 'false',
  ENABLE_EMAIL_SIGNUP: 'true',
  // Never autoconfirm: with sign-up open, an autoconfirmed address would count as verified
  // without proof, and an invitation naming that address would match it (specs/20, J2).
  // Email codes confirm the address by themselves; Apple and Google come confirmed.
  ENABLE_EMAIL_AUTOCONFIRM: 'false',
  ENABLE_ANONYMOUS_USERS: 'false',
  ENABLE_PHONE_SIGNUP: 'false',
  ENABLE_PHONE_AUTOCONFIRM: 'false',
  MAILER_URLPATHS_CONFIRMATION: '/auth/v1/verify',
  MAILER_URLPATHS_INVITE: '/auth/v1/verify',
  MAILER_URLPATHS_RECOVERY: '/auth/v1/verify',
  MAILER_URLPATHS_EMAIL_CHANGE: '/auth/v1/verify',
  // No SMTP yet: nothing sends mail today. Set a real relay before e-mail codes ship.
  SMTP_ADMIN_EMAIL: option('admin-email') ?? `wuselwall@${web.hostname}`,
  SMTP_HOST: 'localhost',
  SMTP_PORT: '25',
  SMTP_USER: '',
  SMTP_PASS: '',
  SMTP_SENDER_NAME: 'WuselWall',

  // Apple access for accounts created before sign-in with Apple was removed: account-delete
  // revokes it at Apple. Only these five values are needed; no provider is enabled. The key
  // (.p8) is kept on one line with \n for its line breaks. APPLE_TOKEN_KEY is generated here,
  // once, with the stack: the stored Apple refresh tokens are encrypted with it and cannot be
  // read back with another key.
  APPLE_TEAM_ID: vars.WW_APPLE_TEAM_ID ?? '',
  APPLE_KEY_ID: vars.WW_APPLE_KEY_ID ?? '',
  APPLE_PRIVATE_KEY: (vars.WW_APPLE_PRIVATE_KEY ?? '').replace(/\n/g, '\\n'),
  APPLE_CLIENT_ID: vars.WW_APPLE_BUNDLE_ID ?? '',
  APPLE_TOKEN_KEY: b64(32),

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
process.stdout.write(
  '# WuselWall compose stack. Generated by infra/supabase/make-env.mjs; secrets — never commit.\n' +
  Object.entries(out).map(([k, v]) => `${k}='${v}'`).join('\n') + '\n',
);

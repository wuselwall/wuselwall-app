#!/usr/bin/env node
// Writes the compose stack's .env (ADR-013 amendment) to stdout, from supabase/.env and
// fresh random values. Run by `scripts/remote-stack.sh init-env`, which streams it to the
// server once and never stores it on the laptop.
//
// Usage: node infra/supabase/make-env.mjs supabase/.env
//
// Kept from supabase/.env, so every installed app and every device session keeps
// working: WW_JWT_SECRET (HS256, now also listed in the JWKS) and the opaque
// WW_PUBLISHABLE_KEY / WW_SECRET_KEY the apps ship with.
// Generated: the Postgres password and the services' own secrets, an EC P-256 key pair
// that signs new tokens, the ES256 "internal API keys" the gateway swaps the opaque keys
// for, and legacy HS256 anon/service JWTs (only the containers' health checks use them).
// The crypto follows upstream's utils/add-new-auth-keys.sh.
import crypto from 'node:crypto';
import fs from 'node:fs';

const src = process.argv[2];
if (!src) {
  console.error('usage: make-env.mjs <path to supabase/.env>');
  process.exit(2);
}
const vars = Object.fromEntries(
  fs.readFileSync(src, 'utf8').split('\n')
    .map((l) => l.trim()).filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')]),
);
for (const k of ['WW_JWT_SECRET', 'WW_PUBLISHABLE_KEY', 'WW_SECRET_KEY']) {
  if (!vars[k]) {
    console.error(`${k} missing in ${src}`);
    process.exit(1);
  }
}
const jwtSecret = vars.WW_JWT_SECRET;

const hex = (n) => crypto.randomBytes(n).toString('hex');
const b64 = (n) => crypto.randomBytes(n).toString('base64');
const b64url = (x) => Buffer.from(x).toString('base64url');

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

const out = {
  COMPOSE_FILE: 'docker-compose.yml:docker-compose.wuselwall.yml',

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
  SUPABASE_PUBLIC_URL: 'https://api.wuselwall.app',
  API_EXTERNAL_URL: 'https://api.wuselwall.app/auth/v1',
  // Where GoTrue's e-mail links land: the web app, not the website (ADR-017).
  SITE_URL: 'https://web.wuselwall.app/',
  ADDITIONAL_REDIRECT_URLS: 'https://web.wuselwall.app/**,https://127.0.0.1:3000,ch.goomba.wuselwall://login-callback/',
  // The registrable domain, so a passkey serves the web app and (through the website's
  // /.well-known/ files) the native apps alike.
  PASSKEY_RP_ID: 'wuselwall.app',
  PASSKEY_RP_ORIGINS: 'https://web.wuselwall.app',

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
  // Strangers get an account that can do nothing but wait for an invitation or, while
  // household creation is in `code` mode, start a family with a founder code (specs/20).
  DISABLE_SIGNUP: 'false',
  ENABLE_EMAIL_SIGNUP: 'true',
  ENABLE_EMAIL_AUTOCONFIRM: 'true',
  ENABLE_ANONYMOUS_USERS: 'false',
  ENABLE_PHONE_SIGNUP: 'false',
  ENABLE_PHONE_AUTOCONFIRM: 'false',
  MAILER_URLPATHS_CONFIRMATION: '/auth/v1/verify',
  MAILER_URLPATHS_INVITE: '/auth/v1/verify',
  MAILER_URLPATHS_RECOVERY: '/auth/v1/verify',
  MAILER_URLPATHS_EMAIL_CHANGE: '/auth/v1/verify',
  // No SMTP yet: nothing sends mail today. Set a real relay before e-mail codes ship.
  SMTP_ADMIN_EMAIL: 'anmeldung@goomba.ch',
  SMTP_HOST: 'localhost',
  SMTP_PORT: '25',
  SMTP_USER: '',
  SMTP_PASS: '',
  SMTP_SENDER_NAME: 'WuselWall',

  // Sign in with Apple and Google (specs/10 §4), from supabase/.env when it has them; off
  // otherwise. Later changes go through `scripts/remote-stack.sh set-env`.
  APPLE_ENABLED: vars.WW_APPLE_CLIENT_IDS ? 'true' : 'false',
  APPLE_CLIENT_IDS: vars.WW_APPLE_CLIENT_IDS ?? '',
  APPLE_SECRET: vars.WW_APPLE_SECRET ?? '',
  GOOGLE_ENABLED: vars.WW_GOOGLE_CLIENT_IDS ? 'true' : 'false',
  GOOGLE_CLIENT_IDS: vars.WW_GOOGLE_CLIENT_IDS ?? '',
  GOOGLE_CLIENT_SECRET: vars.WW_GOOGLE_CLIENT_SECRET ?? '',

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

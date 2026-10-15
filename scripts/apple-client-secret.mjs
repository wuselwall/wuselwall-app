#!/usr/bin/env node
// Prints the client secret Supabase Auth needs for Sign in with Apple (specs/10 §4): a
// JWT signed with the Sign in with Apple key (.p8). Apple accepts at most six months, so
// it has to be regenerated before the date printed on stderr (specs/10, "Recurring").
//
// Usage:
//   node scripts/apple-client-secret.mjs --client-id <Services ID> --key-id <10 chars>
//        --p8 <AuthKey_….p8 | -> [--team JSX2VQXW7G] [--days 180]
//
// Straight to the server, never through a file or the clipboard:
//   node scripts/apple-client-secret.mjs --client-id … --key-id … --p8 … \
//     | scripts/remote-stack.sh set-env APPLE_SECRET
//   scripts/remote-stack.sh up -d auth
import crypto from 'node:crypto';
import fs from 'node:fs';
import { parseArgs } from 'node:util';

const { values: o } = parseArgs({
  options: {
    team: { type: 'string', default: 'JSX2VQXW7G' },
    'key-id': { type: 'string' },
    'client-id': { type: 'string' },
    p8: { type: 'string' },
    days: { type: 'string', default: '180' },
  },
});

const fail = (msg) => {
  console.error(msg);
  process.exit(2);
};
if (!/^[A-Z0-9]{10}$/.test(o['key-id'] ?? '')) fail('--key-id: the 10-character Key ID of the Sign in with Apple key');
if (!/^[A-Z0-9]{10}$/.test(o.team)) fail('--team: the 10-character Team ID');
if (!o['client-id']) fail('--client-id: the Services ID used for the web and Android redirect');
if (!o.p8) fail('--p8: path to the AuthKey_….p8 file, or - for stdin');
const days = Number(o.days);
// Apple's limit is 15,777,000 seconds (six months); stay a little under it.
if (!Number.isInteger(days) || days < 1 || days > 182) fail('--days: 1 to 182');

const pem = fs.readFileSync(o.p8 === '-' ? 0 : o.p8, 'utf8');
let key;
try {
  key = crypto.createPrivateKey(pem);
} catch {
  fail('--p8 is not a readable private key: copy the .p8 again, all of it');
}

const b64url = (x) => Buffer.from(x).toString('base64url');
const iat = Math.floor(Date.now() / 1000);
const exp = iat + days * 24 * 3600;
const header = { alg: 'ES256', kid: o['key-id'] };
const claims = { iss: o.team, iat, exp, aud: 'https://appleid.apple.com', sub: o['client-id'] };
const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
const sig = crypto.sign('SHA256', Buffer.from(data), { key, dsaEncoding: 'ieee-p1363' });

process.stdout.write(`${data}.${b64url(sig)}\n`);
console.error(
  `Client secret for ${o['client-id']}, valid until ${new Date(exp * 1000).toISOString().slice(0, 10)}. ` +
    'Put a reminder in the calendar a few weeks before.',
);

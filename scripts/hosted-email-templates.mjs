#!/usr/bin/env node
// Apply the same code-based SMTP fallback as CLI and Compose to a family's hosted
// Supabase project. Does not change the SMTP provider, Send Email Hook, redirects or
// signup policy. Run by deploy-supabase.yml; never prints credentials or config values.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export async function configureEmailTemplates({ project, token, language = 'de', fetchFn = fetch, log = console.log }) {
  if (!project || !token) throw new Error('PROJECT and SUPABASE_ACCESS_TOKEN are required');
  const subjects = { de: 'Dein WuselWall-Code', en: 'Your WuselWall code', fr: 'Votre code WuselWall', es: 'Tu código de WuselWall' };
  if (!Object.hasOwn(subjects, language)) throw new Error('MAIL_LANGUAGE must be de, en, fr or es');
  // Match the app's six-digit input and the validity promised in the mail.
  const patch = { mailer_otp_exp: 600, mailer_otp_length: 6 };
  for (const kind of ['confirmation', 'magic_link', 'recovery', 'email_change', 'reauthentication', 'invite']) {
    patch[`mailer_templates_${kind}_content`] = readFileSync(
      new URL(`../supabase/templates/${language}/${kind}.html`, import.meta.url), 'utf8');
    patch[`mailer_subjects_${kind}`] = subjects[language];
  }
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
  for (const [key, value] of Object.entries(patch)) {
    if (actual[key] !== value) throw new Error(`Email template setting not applied: ${key}`);
  }
  log(`Auth: ${language} email templates applied and verified`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  configureEmailTemplates({ project: process.env.PROJECT, token: process.env.SUPABASE_ACCESS_TOKEN,
    language: process.env.MAIL_LANGUAGE ?? 'de' })
    .catch((err) => { console.error(`::error::${err.message}`); process.exitCode = 1; });
}

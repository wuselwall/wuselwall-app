import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('hosted SMTP fallback uploads both canonical code templates and reads them back', async () => {
  const { configureEmailTemplates } = await import('./hosted-email-templates.mjs');
  const calls = [];
  let stored;
  await configureEmailTemplates({
    project: 'example', token: 'test-token', log: () => {},
    fetchFn: async (url, options) => {
      calls.push({ url, ...options });
      if (options.method === 'PATCH') stored = JSON.parse(options.body);
      return new Response(JSON.stringify(stored), { status: 200 });
    },
  });
  assert.deepEqual(calls.map((c) => c.method), ['PATCH', 'GET']);
  for (const c of calls) assert.equal(c.url, 'https://api.supabase.com/v1/projects/example/config/auth');
  assert.deepEqual(Object.keys(stored).sort(), [
    'mailer_otp_exp', 'mailer_otp_length',
    'mailer_subjects_confirmation', 'mailer_subjects_magic_link',
    'mailer_templates_confirmation_content', 'mailer_templates_magic_link_content',
  ]);
  assert.equal(stored.mailer_otp_exp, 600);
  assert.equal(stored.mailer_otp_length, 6);
  for (const kind of ['confirmation', 'magic_link']) {
    assert.equal(stored[`mailer_templates_${kind}_content`], read(`supabase/templates/${kind}.html`));
    assert.equal(stored[`mailer_subjects_${kind}`], 'Dein WuselWall-Code / Your WuselWall code');
  }
});

test('hosted configuration fails if a template was not applied', async () => {
  const { configureEmailTemplates } = await import('./hosted-email-templates.mjs');
  await assert.rejects(configureEmailTemplates({
    project: 'example', token: 'test-token', log: () => {},
    fetchFn: async () => new Response('{}'),
  }), /not applied/);
});

test('hosted configuration surfaces HTTP errors without leaking credentials', async () => {
  const { configureEmailTemplates } = await import('./hosted-email-templates.mjs');
  await assert.rejects(configureEmailTemplates({
    project: 'example', token: 'test-token', log: () => {},
    fetchFn: async () => new Response('secret response must not be logged', { status: 403 }),
  }), /^Error: PATCH config\/auth: HTTP 403$/);
});

test('hosted deployment runs email template configuration', () => {
  assert.match(read('.github/workflows/deploy-supabase.yml'), /run: node scripts\/hosted-email-templates\.mjs/);
});

-- Development seed: the setup token for a fresh local database is the literal "dev-setup".
-- Production prints a random token at deploy time (specs/08, specs/16).
insert into app.setup_token (token_hash)
values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'))
on conflict do nothing;

-- Founder codes for the onboarding journeys of app/test/integration/onboarding_integration_test.dart
-- (a fresh stack is in `code` mode, specs/20): one per journey. Development and CI only, like
-- "dev-setup" above; a release never runs the seed.
insert into app.setup_token (token_hash)
select encode(extensions.digest(c, 'sha256'), 'hex')
from unnest(array['dev-founder-j1', 'dev-founder-j2', 'dev-founder-j3']) as c
on conflict do nothing;

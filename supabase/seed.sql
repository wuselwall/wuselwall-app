-- Development seed: the setup token for a fresh local database is the literal "dev-setup".
-- Production prints a random token at deploy time (docs/08, docs/16).
insert into app.setup_token (token_hash)
values (encode(extensions.digest('dev-setup', 'sha256'), 'hex'))
on conflict do nothing;

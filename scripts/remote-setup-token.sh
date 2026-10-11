#!/usr/bin/env bash
# Replaces the setup token on the home server with a fresh random one and prints it once
# (specs/10#3-first-household). Only the hash is stored. The dev seed's "dev-setup" is in
# git and must not guard a stack that is reachable from the internet.
set -euo pipefail
token=$(openssl rand -hex 12)
out=$(ssh "${WW_HOST:-unraid}" docker exec -i "${DB_CONTAINER:-supabase-db}" psql -U postgres -X -q -t -A -v ON_ERROR_STOP=1 <<SQL
do \$\$ begin
  if exists (select 1 from app.household) then
    raise exception 'a household exists already; setup is closed';
  end if;
end \$\$;
delete from app.setup_token;
insert into app.setup_token (token_hash) values (encode(extensions.digest('$token', 'sha256'), 'hex'));
select 'ok';
SQL
)
[ "$out" = "ok" ] || { echo "$out" >&2; exit 1; }
echo "Setup token (shown once, enter it in the app): $token"

#!/usr/bin/env bash
# Issues founder codes on the server named in scripts/remote.env (specs/10#3-first-household, specs/20 "Household
# creation: open, or by code"). Prints each code once; only its SHA-256 hash is stored.
#
#   scripts/remote-setup-token.sh           the first setup code. Replaces every code, and
#                                           refuses once a household exists (setup is closed).
#   scripts/remote-setup-token.sh --founder one more single-use founder code, for a household
#                                           created in `code` mode after the first one. Refuses
#                                           while no household exists. Never replaces a code.
#
# The dev seed's "dev-setup" is in git and must not guard a stack that is reachable from the
# internet.
set -euo pipefail
cd "$(dirname "$0")/.."
# The target server comes from scripts/remote.env (git-ignored; see remote.env.example).
[ -f scripts/remote.env ] && . scripts/remote.env

case "${1:-}" in
  '')        mode=first ;;
  --founder) mode=founder ;;
  *) echo "usage: $0 [--founder]" >&2; exit 2 ;;
esac

token=$(openssl rand -hex 12)

if [ "$mode" = first ]; then
  guard_sql=$(cat <<'SQL'
do $$ begin
  if exists (select 1 from app.household) then
    raise exception 'a household exists already; setup is closed';
  end if;
end $$;
delete from app.setup_token;
SQL
)
else
  guard_sql=$(cat <<'SQL'
do $$ begin
  if not exists (select 1 from app.household) then
    raise exception 'no household yet; the first code comes from scripts/remote-setup-token.sh without --founder';
  end if;
end $$;
SQL
)
fi

out=$(ssh "${WW_HOST:?set WW_HOST in scripts/remote.env}" docker exec -i "${DB_CONTAINER:-supabase-db}" psql -U postgres -X -q -t -A -v ON_ERROR_STOP=1 <<SQL
$guard_sql
insert into app.setup_token (token_hash) values (encode(extensions.digest('$token', 'sha256'), 'hex'));
select 'ok';
SQL
)
[ "$out" = "ok" ] || { echo "$out" >&2; exit 1; }

if [ "$mode" = first ]; then
  echo "Setup token (shown once, enter it in the app): $token"
else
  echo "Founder code (shown once, enter it in the app to start a household): $token"
fi

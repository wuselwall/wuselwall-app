-- No Sign in with Apple or Google any more: accounts sign in with an email code or a password
-- (specs/20, "The front door"). The Apple refresh-token store of 20261015106000_account_admin
-- goes with the apple-token function that wrote it and the revocation in account-delete that
-- read it. Additive for api_version: the app never called these functions, only the service
-- role did, and the previous app release's call to apple-token was best effort.

drop function if exists api.apple_token_put(uuid, text);
drop function if exists api.apple_token_get(uuid);
drop table if exists app.apple_token;

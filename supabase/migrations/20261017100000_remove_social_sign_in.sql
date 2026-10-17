-- Social sign-in (Sign in with Apple, Google) is removed (app, Auth configuration, the
-- apple-token Edge Function). Nothing stores an Apple refresh token any more, so its writer
-- goes. The table and its reader stay: accounts that signed in with Apple before this may hold a
-- token, and account-delete still revokes it at Apple when the account is deleted. No row is
-- deleted here: a token disappears with its account (on delete cascade), as before.
--
-- Auth identities (auth.identities) of the providers are left untouched. With the providers
-- switched off in Auth they cannot be used to sign in; the account itself, its e-mail address
-- and its data stay.
--
-- api_version: unchanged. api.apple_token_put was service-role only and never part of the
-- app–server contract; the previous app release called the apple-token function, which is gone
-- and whose failure the app always ignored.

drop function api.apple_token_put(uuid, text);

comment on table app.apple_token is
  'Apple refresh tokens of accounts that signed in with Apple before social sign-in was removed. '
  'Read only by account-delete (api.apple_token_get) to revoke Apple''s access; never written.';

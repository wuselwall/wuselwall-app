begin;
select plan(3);

-- No Sign in with Apple (20261017100000_drop_apple_token): the refresh-token store is gone.
select hasnt_table('app', 'apple_token', 'the Apple token table is gone');
select hasnt_function('api', 'apple_token_put', array['uuid', 'text'], 'and the function that stored a token');
select hasnt_function('api', 'apple_token_get', array['uuid'], 'and the one that read it');

select * from finish();
rollback;

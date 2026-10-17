-- =============================================================================
-- Store the purge token in the Vault (run ONCE, by the owner).
--
-- The nightly photo clean-up (migration 20261018010000) reads this secret to
-- prove to the `visit-photos` function that the call comes from the database.
-- It must be EXACTLY the value of the PURGE_TOKEN secret in Supabase
-- (Edge Functions, Secrets).
--
-- HOW
--   1. Open the Supabase SQL editor in a new tab.
--   2. Replace PASTE-YOUR-PURGE-TOKEN-HERE below with your token.
--   3. Run it. Then CLOSE THE TAB WITHOUT SAVING the snippet, so the token is
--      not kept in your saved queries.
--   Never paste the token in chat, a file in this project, or git.
--
-- To change the token later: change PURGE_TOKEN in Edge Function secrets, then
-- run   select vault.update_secret(id, 'NEW-TOKEN') from vault.secrets
--       where name = 'purge_token';
-- =============================================================================

select vault.create_secret('PASTE-YOUR-PURGE-TOKEN-HERE', 'purge_token',
                           'Token for the nightly visit-photo clean-up');

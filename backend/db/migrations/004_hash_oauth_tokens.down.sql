-- ══════════════════════════════════════════════════════════════════════════
-- 004_hash_oauth_tokens.sql — rollback
--
-- NOTE: hashing is one-way. This restores the `token` column shape but
-- cannot recover original values, so existing rows come back with token
-- NULL (left nullable rather than forcing NOT NULL against un-recoverable
-- data) — those rows will simply fail the exchange lookup, which is safe
-- since exchange tokens are short-lived anyway.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.oauth_exchanges
    DROP CONSTRAINT oauth_exchanges_token_hash_key;

ALTER TABLE public.oauth_exchanges ADD COLUMN token text;

ALTER TABLE public.oauth_exchanges
    DROP COLUMN token_hash;

ALTER TABLE public.oauth_exchanges
    ADD CONSTRAINT oauth_exchanges_token_key UNIQUE (token);

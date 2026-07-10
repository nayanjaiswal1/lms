-- ══════════════════════════════════════════════════════════════════════════
-- 004_hash_oauth_tokens.sql — Stop storing oauth_exchanges tokens in plaintext
--
-- SCHEMA_REVIEW.md Issue #39: refresh_tokens, password_reset_tokens, and
-- email_verifications already store token_hash (and already carry UNIQUE
-- constraints — refresh_tokens_token_hash_key / password_reset_tokens_
-- token_hash_key in 001_baseline.sql, so that part of the issue is already
-- resolved). oauth_exchanges was the one holdout still storing the raw
-- bearer token in plaintext (`token text UNIQUE`).
--
-- Existing rows are hashed in place with pgcrypto's digest(), matching
-- Go's auth.HashToken (hex(sha256(raw))) exactly, so live (non-expired)
-- exchanges keep working after this migration.
--
-- Note: this migration only covers oauth_exchanges. The review's other two
-- plaintext columns (assessment_attempts.active_session_token,
-- public_attempts.session_token) require a new assessment_session_tokens
-- table plus matching Go changes in internal/assessment — that package has
-- unrelated in-flight work and is deferred to a follow-up migration rather
-- than bundled here.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.oauth_exchanges ADD COLUMN token_hash text;

UPDATE public.oauth_exchanges
    SET token_hash = encode(digest(token, 'sha256'), 'hex');

ALTER TABLE public.oauth_exchanges
    DROP CONSTRAINT oauth_exchanges_token_key;

ALTER TABLE public.oauth_exchanges
    DROP COLUMN token;

ALTER TABLE public.oauth_exchanges
    ALTER COLUMN token_hash SET NOT NULL;

ALTER TABLE public.oauth_exchanges
    ADD CONSTRAINT oauth_exchanges_token_hash_key UNIQUE (token_hash);

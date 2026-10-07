-- Refresh-token reuse detection: the hash a connection held before its last
-- rotation. Presenting it again means the rotated-out token leaked, so the
-- connection is revoked.
ALTER TABLE public.mcp_connections ADD COLUMN previous_refresh_token_hash text;

CREATE INDEX idx_mcp_connections_previous_refresh_hash
    ON public.mcp_connections (previous_refresh_token_hash)
    WHERE previous_refresh_token_hash IS NOT NULL;

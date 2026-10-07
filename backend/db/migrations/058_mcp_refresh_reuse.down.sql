DROP INDEX IF EXISTS public.idx_mcp_connections_previous_refresh_hash;
ALTER TABLE public.mcp_connections DROP COLUMN IF EXISTS previous_refresh_token_hash;

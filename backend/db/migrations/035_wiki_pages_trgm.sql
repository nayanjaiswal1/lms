-- pg_trgm is already enabled (see 001_baseline.sql) and already used this
-- way for near-duplicate detection in captures/journal/messaging. This index
-- backs the same similarity() lookup against wiki_pages, so create/update
-- can flag likely-duplicate pages without a full table scan.
CREATE INDEX IF NOT EXISTS idx_wiki_pages_search_text_trgm
  ON public.wiki_pages USING gin (search_text gin_trgm_ops);

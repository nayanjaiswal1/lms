-- OKF v0.2 frontmatter fields the wiki has no native column for (resource,
-- tags, sources, verified, stale_after, and any producer extension key or
-- type override) round-trip through this column rather than one column per
-- field. See backend/internal/wiki/okf.go.
ALTER TABLE public.wiki_pages ADD COLUMN okf_metadata JSONB;

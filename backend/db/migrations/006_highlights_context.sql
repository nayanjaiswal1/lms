-- ════════════════════════════════════════════════════════════════════════════
-- 006_highlights_context.sql — add context_snippet and source_url to highlights
-- context_snippet: surrounding paragraph text captured at creation time so the
--   saved-highlights page can show nearby content without fetching the source.
-- source_url: the page path at creation time, used as the "go to source" link.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE highlights
  ADD COLUMN context_snippet TEXT,
  ADD COLUMN source_url      TEXT;

-- ════════════════════════════════════════════════════════════════════════════
-- 007_highlights_orphan.sql — track deleted source content
-- source_orphaned is set to TRUE when the referenced wiki page, lesson, or
-- problem is deleted. The highlight itself is preserved (the student's
-- context_snippet and explanation remain readable) but the nav link is removed.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE highlights
  ADD COLUMN source_orphaned BOOLEAN NOT NULL DEFAULT FALSE;

-- Partial index: domains call OrphanBySource(type, id) on deletion.
-- The WHERE clause makes it cheap to bulk-update and to query active highlights.
CREATE INDEX idx_highlights_source_active
  ON highlights(source_type, source_id)
  WHERE source_orphaned = FALSE;

-- ══════════════════════════════════════════════════════════════════════════
-- 042_course_section_groups.sql — Nested course section groups
--
-- Additive: sections stay a flat ordered list; group_title is an optional
-- label so consecutive sections sharing the same label render under one
-- group heading (e.g. "Backend" grouping "Python"/"Django"/"FastAPI").
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

ALTER TABLE public.course_sections ADD COLUMN group_title TEXT CHECK (group_title IS NULL OR length(group_title) BETWEEN 1 AND 200);

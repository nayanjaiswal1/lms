-- ═════════════════════════════════════════════════════════════════════════
-- Migration 020 — add_courses_tags_gin_index
-- Supports the "random topic to learn" discovery feature's tag-overlap
-- filter (courses.tags && student's topics_interest) with an index instead
-- of a sequential scan over every published course.
-- ═════════════════════════════════════════════════════════════════════════

CREATE INDEX courses_tags_gin ON public.courses USING GIN (tags)
    WHERE status = 'published';

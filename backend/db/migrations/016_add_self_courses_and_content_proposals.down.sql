-- ═════════════════════════════════════════════════════════════════════════
-- Migration 016 — add_self_courses_and_content_proposals (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.course_content_proposals;

ALTER TABLE public.courses
    DROP CONSTRAINT IF EXISTS courses_owner_fk,
    DROP CONSTRAINT IF EXISTS courses_self_has_owner_check,
    DROP CONSTRAINT IF EXISTS courses_kind_check,
    DROP COLUMN IF EXISTS owner_id,
    DROP COLUMN IF EXISTS kind;

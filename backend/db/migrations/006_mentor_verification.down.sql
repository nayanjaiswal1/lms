-- ═════════════════════════════════════════════════════════════════════════
-- Migration 006 — mentor_verification (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DELETE FROM public.permissions WHERE code = 'mentoring.verify_mentors';

ALTER TABLE public.user_profiles
    DROP COLUMN mentor_verified,
    DROP COLUMN mentor_verified_at,
    DROP COLUMN mentor_verified_by;

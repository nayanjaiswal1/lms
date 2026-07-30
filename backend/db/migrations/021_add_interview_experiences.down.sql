-- ═════════════════════════════════════════════════════════════════════════
-- Migration 021 — add_interview_experiences (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DELETE FROM public.role_permissions
    WHERE permission_id = (SELECT id FROM public.permissions WHERE code = 'content.interview_exp');
DELETE FROM public.permissions WHERE code = 'content.interview_exp';

DROP TABLE IF EXISTS public.interview_exp_votes;
DROP TABLE IF EXISTS public.interview_exp_comments;
DROP TABLE IF EXISTS public.interview_exp_qna;
DROP TABLE IF EXISTS public.interview_exp_entries;
DROP TABLE IF EXISTS public.interview_exp_posts;

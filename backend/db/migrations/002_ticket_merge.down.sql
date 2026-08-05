-- ══════════════════════════════════════════════════════════════════════════
-- 002_ticket_merge.sql — rollback
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.content_reports DROP CONSTRAINT IF EXISTS content_reports_reason_check;
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_reason_check
    CHECK ((reason = ANY (ARRAY['illegal'::text, 'copyright'::text, 'spam'::text, 'harassment'::text, 'other'::text])));

DELETE FROM public.role_permissions WHERE permission_id = 'a1c9c9c1-6b8b-4b6a-9b0f-2f9c8f2d7e11';
DELETE FROM public.permissions WHERE id = 'a1c9c9c1-6b8b-4b6a-9b0f-2f9c8f2d7e11';

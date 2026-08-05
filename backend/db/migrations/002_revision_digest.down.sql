-- ══════════════════════════════════════════════════════════════════════════
-- 002_revision_digest.sql — rollback
-- ══════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.revision_digests;

DELETE FROM public.permissions WHERE code = 'features.revision_digest';

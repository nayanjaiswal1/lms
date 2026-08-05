-- ══════════════════════════════════════════════════════════════════════════
-- 003_org_user_feature_flags.sql — rollback
-- ══════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.user_feature_flags;
DROP TABLE IF EXISTS public.org_feature_flags;

DELETE FROM public.permissions WHERE code = 'features.what_now';

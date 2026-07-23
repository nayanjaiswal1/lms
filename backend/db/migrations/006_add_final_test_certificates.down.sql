-- ═════════════════════════════════════════════════════════════════════════
-- Migration 006 — add_final_test_certificates (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.certificates;
DROP TABLE IF EXISTS public.final_test_attempts;
DROP TABLE IF EXISTS public.final_tests;

-- ══════════════════════════════════════════════════════════════════════════
-- 001_baseline.sql — rollback
-- Drops everything. Extensions are recreated by the up migration on reapply.
-- ══════════════════════════════════════════════════════════════════════════

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

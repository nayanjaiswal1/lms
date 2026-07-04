-- ─── user_stats.tests_passed ──────────────────────────────────────────────────
-- profile.Repo.GetStats (backend/internal/profile/repo.go) has always selected
-- this column, but 001_schema.sql never created it — GET /api/profile/me has
-- been failing with a 500 for every user.
ALTER TABLE user_stats
  ADD COLUMN tests_passed INT NOT NULL DEFAULT 0;

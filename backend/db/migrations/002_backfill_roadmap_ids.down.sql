-- 002_backfill_roadmap_ids rollback: intentionally a no-op. The backfill only
-- fills blank ids and cannot tell generated ids from pre-existing ones, and
-- removing them would orphan any roadmap_module_progress rows recorded since.
SELECT 1;

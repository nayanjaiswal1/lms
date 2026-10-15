-- 006_cancel_platform_recipes_sync.sql
-- Platform labs are now verified in CI and imported on deploy (`coursegen
-- blocks import`, docs/debug-labs.md B5); the lab.platform_recipes_sync cron
-- and handler are gone. Cancel its not-yet-run jobs so a worker never picks one
-- up and dead-letters it as an unknown handler (an ops alert for nothing).
-- Builds that sync already queued keep running through lab.recipe_build /
-- lab.recipe_verify as ordinary builds; they just no longer auto-publish.
-- Idempotent.
UPDATE public.jobs SET status = 'cancelled'
WHERE handler = 'lab.platform_recipes_sync' AND status IN ('pending', 'queued');

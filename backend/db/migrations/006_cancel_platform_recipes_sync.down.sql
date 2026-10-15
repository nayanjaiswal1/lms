-- Nothing to restore: cancelled lab.platform_recipes_sync jobs stay cancelled
-- (the handler no longer exists, so re-queueing them would only dead-letter).
SELECT 1;

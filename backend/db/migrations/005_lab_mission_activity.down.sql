-- Drops the recorded activity and the mission clock; sessions fall back to the
-- provisioning-time deadline.
DROP TABLE IF EXISTS public.lab_activity_events;
ALTER TABLE public.lab_sessions DROP COLUMN IF EXISTS mission_started_at;

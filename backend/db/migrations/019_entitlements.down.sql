DROP TABLE public.usage_counters;
DROP TABLE public.plan_limits;
ALTER TABLE public.organizations DROP COLUMN tier_id;
ALTER TABLE public.users DROP COLUMN tier_id;

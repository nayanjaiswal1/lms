SET LOCAL lock_timeout = '5s';

ALTER TABLE public.course_sections DROP COLUMN IF EXISTS group_title;

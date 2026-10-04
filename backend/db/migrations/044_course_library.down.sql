SET LOCAL lock_timeout = '5s';

DROP INDEX IF EXISTS public.idx_course_modules_lab_id;
ALTER TABLE public.lab_sessions DROP COLUMN IF EXISTS module_id;
ALTER TABLE public.lab_definitions DROP COLUMN IF EXISTS library_visibility;
ALTER TABLE public.course_modules DROP CONSTRAINT IF EXISTS lab_module_has_lab;
ALTER TABLE public.course_modules DROP COLUMN IF EXISTS copied_from_module_id;
ALTER TABLE public.course_modules DROP COLUMN IF EXISTS lab_is_required;
ALTER TABLE public.course_modules DROP COLUMN IF EXISTS lab_id;

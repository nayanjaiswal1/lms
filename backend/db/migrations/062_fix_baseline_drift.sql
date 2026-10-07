-- The squashed baseline carried two defects that break live writes:
-- 1. trg_member_join_enroll calls a function that selects from batch_courses,
--    a table that no longer exists, so every batch_members INSERT failed.
--    Enrollment into batch courses is done in application code
--    (enrollInBatchCourses), so the trigger and its function are dropped.
-- 2. purchases.created_at was NOT NULL with no default, so inserts that do
--    not set it (session packs, course purchases) failed.
DROP TRIGGER IF EXISTS trg_member_join_enroll ON public.batch_members;
DROP FUNCTION IF EXISTS public.enroll_new_member_in_batch_courses();
ALTER TABLE public.purchases ALTER COLUMN created_at SET DEFAULT now();

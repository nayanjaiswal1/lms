SET LOCAL lock_timeout = '5s';

ALTER TABLE public.lab_sessions
  DROP COLUMN IF EXISTS student_diff,
  DROP COLUMN IF EXISTS writeup_review,
  DROP COLUMN IF EXISTS required_passed_at;

DROP INDEX IF EXISTS public.users_status_idx;

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_status_check;

ALTER TABLE public.users
    DROP COLUMN IF EXISTS status_changed_at,
    DROP COLUMN IF EXISTS status_reason,
    DROP COLUMN IF EXISTS status;

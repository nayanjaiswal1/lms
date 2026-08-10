ALTER TABLE public.batches
    DROP CONSTRAINT IF EXISTS batches_mentor_id_fkey,
    DROP COLUMN IF EXISTS mentor_id;

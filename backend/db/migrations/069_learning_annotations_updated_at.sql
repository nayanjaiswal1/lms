-- internal/highlights lists and toggles highlights by updated_at; the baseline
-- learning_annotations table never had the column, so GET /api/highlights 500'd.
ALTER TABLE public.learning_annotations
    ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone NOT NULL DEFAULT now();

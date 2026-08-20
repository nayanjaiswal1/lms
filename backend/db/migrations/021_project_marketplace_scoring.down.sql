ALTER TABLE public.project_applications
    DROP COLUMN IF EXISTS resume_text,
    DROP COLUMN IF EXISTS ai_score,
    DROP COLUMN IF EXISTS ai_rationale,
    DROP COLUMN IF EXISTS ai_scored_at;

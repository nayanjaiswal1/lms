-- ═════════════════════════════════════════════════════════════════════════
-- Migration 014 — activity_feed
-- ═════════════════════════════════════════════════════════════════════════
-- Backs the new /api/activity endpoint (internal/activity) — a day-by-day
-- "what did I do, and when" timeline aggregating existing per-domain
-- timestamps (module_progress.completed_at, assessment_attempts.submitted_at,
-- lesson_reflections.created_at, user_problem_progress.solved_at,
-- lab_sessions.completed_at) via UNION ALL, plus the one genuinely new
-- source: SM-2 flashcard reviews, which srs_cards never kept history for
-- (only current due_date/ease_factor/interval_days).
--
-- srs_reviews.user_id is denormalized off srs_cards (rather than requiring a
-- join for every feed query) so the feed index below is a flat
-- (user_id, reviewed_at DESC) scan. quality/interval_days/ease_factor are the
-- post-review values, so the timeline can render "Next review in Nd" without
-- recomputing SM-2.
--
-- The remaining indexes are partial (WHERE ts IS NOT NULL, and status =
-- 'completed' for module_progress) so each UNION branch can be satisfied by
-- an Index Scan Backward, letting Postgres use a MergeAppend instead of
-- sorting the full union on every request.

CREATE TABLE public.srs_reviews (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id       uuid NOT NULL REFERENCES public.srs_cards(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    quality       smallint NOT NULL CHECK (quality BETWEEN 0 AND 3),
    interval_days integer NOT NULL,
    ease_factor   double precision NOT NULL,
    reviewed_at   timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_srs_reviews_user_reviewed
    ON public.srs_reviews (user_id, reviewed_at DESC);

-- Activity-feed source indexes (see internal/activity/repo.go)
CREATE INDEX idx_module_progress_user_completed
    ON public.module_progress (user_id, completed_at DESC)
    WHERE status = 'completed' AND completed_at IS NOT NULL;

CREATE INDEX idx_enrollments_user_completed
    ON public.enrollments (user_id, completed_at DESC)
    WHERE completed_at IS NOT NULL;

CREATE INDEX idx_assessment_attempts_user_submitted
    ON public.assessment_attempts (user_id, submitted_at DESC)
    WHERE submitted_at IS NOT NULL;

CREATE INDEX idx_lesson_reflections_user_created
    ON public.lesson_reflections (user_id, created_at DESC);

CREATE INDEX idx_user_problem_progress_user_solved
    ON public.user_problem_progress (user_id, solved_at DESC)
    WHERE solved_at IS NOT NULL;

CREATE INDEX idx_lab_sessions_user_completed
    ON public.lab_sessions (user_id, completed_at DESC)
    WHERE completed_at IS NOT NULL;

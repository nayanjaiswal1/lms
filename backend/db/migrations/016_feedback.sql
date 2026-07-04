-- ════════════════════════════════════════════════════════════════════════════
-- 016_feedback.sql — Generic post-completion feedback (course/assessment/lab)
-- ════════════════════════════════════════════════════════════════════════════
-- course_reviews already powers the avg_rating/review_count aggregate shown on
-- course cards and detail pages (011_course_reviews.sql), so it is kept as-is.
-- This table is a separate, generic store covering assessment and lab ratings,
-- plus a "prompted/skipped" record for courses so the completion prompt does
-- not re-appear once a learner has responded (via this table or ReviewForm).

CREATE TABLE feedback (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  subject_type TEXT      NOT NULL CHECK (subject_type IN ('course','assessment','lab')),
  subject_id UUID        NOT NULL,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating     INT         CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT,
  skipped_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT feedback_rated_or_skipped CHECK (rating IS NOT NULL OR skipped_at IS NOT NULL),
  UNIQUE (subject_type, subject_id, user_id)
);

CREATE INDEX idx_feedback_subject ON feedback (subject_type, subject_id);

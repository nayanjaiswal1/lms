-- ════════════════════════════════════════════════════════════════════════════
-- 027_experience_reports.sql — Post-assessment experience reports
-- ════════════════════════════════════════════════════════════════════════════
-- Distinct from feedback (016_feedback.sql), which asks "how would you rate
-- this?" for a star score. experience_reports asks "did anything go wrong?"
-- right after an assessment attempt finishes, so technical issues and
-- complaints can be triaged separately from satisfaction ratings.
--
-- subject_type/subject_id mirrors the generic pattern already used by
-- feedback and highlights, so the same table can back labs/courses later
-- without a schema change. For subject_type='assessment', subject_id is the
-- attempt ID (the specific run the learner just finished), not the
-- assessment definition ID — an issue is about "what happened during my
-- attempt", not the assessment content in general.

CREATE TABLE experience_reports (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  subject_type TEXT        NOT NULL CHECK (subject_type IN ('assessment')),
  subject_id   UUID        NOT NULL,
  user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  experience   TEXT        CHECK (experience IN ('smooth','issue','complaint')),
  description  TEXT,
  skipped_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT experience_reports_reported_or_skipped CHECK (experience IS NOT NULL OR skipped_at IS NOT NULL),
  UNIQUE (subject_type, subject_id, user_id)
);

CREATE INDEX idx_experience_reports_subject ON experience_reports (subject_type, subject_id);

-- Partial index so a future triage view can cheaply pull only flagged reports.
CREATE INDEX idx_experience_reports_flagged ON experience_reports (subject_type, created_at DESC)
  WHERE experience IN ('issue', 'complaint');

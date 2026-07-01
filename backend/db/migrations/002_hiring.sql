-- ════════════════════════════════════════════════════════════════════════════
-- 002_hiring.sql — Hiring assessments: shareable link + anonymous candidate attempts
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE assessments ADD COLUMN short_code TEXT UNIQUE;
CREATE INDEX IF NOT EXISTS idx_assessments_short_code ON assessments(short_code) WHERE short_code IS NOT NULL;

CREATE TABLE public_attempts (
  id            UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID    NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
  name          TEXT    NOT NULL,
  email         TEXT    NOT NULL,
  phone         TEXT,
  session_token TEXT    NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  answers       JSONB   NOT NULL DEFAULT '{}',
  score         NUMERIC,
  max_score     NUMERIC,
  percentage    NUMERIC,
  passed        BOOLEAN,
  flags         INT     NOT NULL DEFAULT 0,
  status        TEXT    NOT NULL DEFAULT 'in_progress'
                        CHECK (status IN ('in_progress', 'submitted')),
  started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  submitted_at  TIMESTAMPTZ,
  duration_sec  INT
);

CREATE INDEX IF NOT EXISTS idx_public_attempts_assessment ON public_attempts(assessment_id);
CREATE INDEX IF NOT EXISTS idx_public_attempts_token      ON public_attempts(session_token);
CREATE INDEX IF NOT EXISTS idx_public_attempts_email      ON public_attempts(assessment_id, email);

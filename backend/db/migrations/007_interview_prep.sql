-- Self-serve "paste a job title/JD, get a scored mock test" feature.
-- Plans are personal and disposable (unlike org-curated assessments/questions),
-- so generated content is frozen JSON on the round row rather than new rows in
-- the shared questions table. Round 1 (conceptual) delegates entirely to the
-- existing practice_sessions engine; round 2 (coding) is self-contained here.

CREATE TABLE interview_prep_plans (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id              UUID REFERENCES organizations(id),
  job_title           TEXT NOT NULL CHECK (length(job_title) BETWEEN 1 AND 200),
  jd_text             TEXT CHECK (jd_text IS NULL OR length(jd_text) <= 10000),
  extracted_role      TEXT,
  extracted_seniority TEXT,
  extracted_skills    TEXT[] NOT NULL DEFAULT '{}',
  status              TEXT NOT NULL DEFAULT 'ready'
                        CHECK (status IN ('generating','ready','in_progress','completed','failed')),
  report              JSONB,
  ai_model            TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at        TIMESTAMPTZ
);

CREATE TABLE interview_prep_rounds (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id              UUID NOT NULL REFERENCES interview_prep_plans(id) ON DELETE CASCADE,
  round_type           TEXT NOT NULL CHECK (round_type IN ('conceptual','coding')),
  order_index          INT NOT NULL DEFAULT 0,
  -- Conceptual round delegates entirely to the existing practice engine.
  practice_session_id  UUID REFERENCES practice_sessions(id),
  -- Coding round is self-contained: generated problems + submissions frozen as JSON.
  -- Item shape: {id, prompt, language, starter_code, test_cases:[{stdin,expected,hidden}],
  --              submitted_code, run_result, passed, skill}
  items                JSONB NOT NULL DEFAULT '[]',
  status               TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','completed')),
  score                NUMERIC(5,2),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at         TIMESTAMPTZ,
  UNIQUE (plan_id, order_index)
);

CREATE INDEX ON interview_prep_plans (user_id, created_at DESC);
CREATE INDEX ON interview_prep_rounds (plan_id, order_index);

-- ════════════════════════════════════════════════════════════════════════════
-- 019_mentor_tickets.sql — Per-student mentor assignment tickets
-- ════════════════════════════════════════════════════════════════════════════
-- Batches (001_schema.sql) link mentors to students at the cohort level via
-- batch_mentors/batch_members — there is no 1:1 "this student needs a mentor"
-- record. mentor_tickets fills that gap: one opens automatically when a
-- student purchases a paid course (see backend/internal/mentoring), and any
-- mentor can self-claim it or a permitted staff member can hand-assign it.

CREATE TABLE mentor_tickets (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id             UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  student_id         UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  course_id          UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  purchase_id        UUID        REFERENCES course_purchases(id) ON DELETE SET NULL,
  status             TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open','assigned','closed')),
  assigned_mentor_id UUID        REFERENCES users(id) ON DELETE SET NULL,
  assigned_by        UUID        REFERENCES users(id) ON DELETE SET NULL,
  assigned_at        TIMESTAMPTZ,
  closed_at          TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mentor_tickets_org_status ON mentor_tickets (org_id, status);
CREATE INDEX idx_mentor_tickets_student    ON mentor_tickets (student_id);
CREATE INDEX idx_mentor_tickets_mentor     ON mentor_tickets (assigned_mentor_id, status);

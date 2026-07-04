-- ════════════════════════════════════════════════════════════════════════════
-- 020_mentor_reports.sql — Mentor complaint/moderation reports
-- ════════════════════════════════════════════════════════════════════════════
-- Distinct from the generic `feedback` table (016_feedback.sql), which is a
-- star rating. A report is a moderation workflow: a student flags a mentor
-- for a specific reason, staff reviews and resolves it.

CREATE TABLE mentor_reports (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  mentor_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reporter_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ticket_id        UUID        REFERENCES mentor_tickets(id) ON DELETE SET NULL,
  reason           TEXT        NOT NULL CHECK (reason IN ('unresponsive','inappropriate_behavior','unqualified','other')),
  description      TEXT        NOT NULL CHECK (length(description) BETWEEN 10 AND 2000),
  status           TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewing','resolved','dismissed')),
  resolved_by      UUID        REFERENCES users(id) ON DELETE SET NULL,
  resolution_note  TEXT,
  resolved_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mentor_reports_org_status ON mentor_reports (org_id, status);
CREATE INDEX idx_mentor_reports_mentor     ON mentor_reports (mentor_id);

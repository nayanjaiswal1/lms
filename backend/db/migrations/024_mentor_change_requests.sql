-- ════════════════════════════════════════════════════════════════════════════
-- 024_mentor_change_requests.sql — Student-initiated mentor change requests
-- ════════════════════════════════════════════════════════════════════════════
-- A student with an 'assigned' ticket can request a different mentor. This is
-- staff-approval-gated (not instant self-service) so students can't churn
-- through mentors unilaterally — staff holding mentoring.assign_tickets
-- review the request; approval reopens the ticket (status back to 'open',
-- mentor cleared, escalation_level reset) for reclaim/reassignment through
-- the existing ticket flow. See backend/internal/mentoring/service.go.

CREATE TABLE mentor_change_requests (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID        NOT NULL REFERENCES organizations(id)   ON DELETE CASCADE,
  ticket_id   UUID        NOT NULL REFERENCES mentor_tickets(id)  ON DELETE CASCADE,
  student_id  UUID        NOT NULL REFERENCES users(id)           ON DELETE CASCADE,
  reason      TEXT        NOT NULL CHECK (length(reason) BETWEEN 10 AND 1000),
  status      TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','denied')),
  reviewed_by UUID        REFERENCES users(id) ON DELETE SET NULL,
  review_note TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mentor_change_requests_org_status ON mentor_change_requests (org_id, status);
CREATE INDEX idx_mentor_change_requests_ticket ON mentor_change_requests (ticket_id);

-- At most one pending request per ticket at a time.
CREATE UNIQUE INDEX uq_mentor_change_requests_pending_ticket
  ON mentor_change_requests (ticket_id)
  WHERE status = 'pending';

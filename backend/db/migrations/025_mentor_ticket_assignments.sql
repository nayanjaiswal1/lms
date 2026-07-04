-- ════════════════════════════════════════════════════════════════════════════
-- 025_mentor_ticket_assignments.sql — Durable mentor assignment history
-- ════════════════════════════════════════════════════════════════════════════
-- mentor_tickets.assigned_mentor_id only reflects the CURRENT mentor — once a
-- change request reopens a ticket, the previous mentor's id is overwritten
-- (cleared then reassigned). That loses the record of who has mentored a
-- student, which matters for two things: (1) a student should still be able
-- to rate a *previous* mentor, not just the current one; (2) an audit trail
-- of who mentored whom. One row is inserted here every time a ticket is
-- claimed or hand-assigned (see backend/internal/mentoring/repo.go).

CREATE TABLE mentor_ticket_assignments (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID        NOT NULL REFERENCES organizations(id)  ON DELETE CASCADE,
  ticket_id   UUID        NOT NULL REFERENCES mentor_tickets(id) ON DELETE CASCADE,
  mentor_id   UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  student_id  UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mentor_ticket_assignments_student_mentor
  ON mentor_ticket_assignments (student_id, mentor_id);
CREATE INDEX idx_mentor_ticket_assignments_ticket
  ON mentor_ticket_assignments (ticket_id);

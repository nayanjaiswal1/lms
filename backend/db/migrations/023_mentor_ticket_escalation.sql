-- ════════════════════════════════════════════════════════════════════════════
-- 023_mentor_ticket_escalation.sql — Escalation tracking for unassigned tickets
-- ════════════════════════════════════════════════════════════════════════════
-- escalation_level tracks how far an 'open' (unclaimed) ticket has escalated:
--   0 = not yet escalated
--   1 = 1 day open  -> org mentors notified
--   2 = 3 days open -> staff holding mentoring.assign_tickets notified
--   3 = 7 days open -> staff notified again + the waiting student notified
-- See backend/internal/jobs/handlers/mentor_escalation.go (HandlerMentorEscalate).

ALTER TABLE mentor_tickets
  ADD COLUMN escalation_level SMALLINT NOT NULL DEFAULT 0 CHECK (escalation_level BETWEEN 0 AND 3);

-- Partial index: escalation scanning only ever looks at open tickets.
CREATE INDEX idx_mentor_tickets_escalation_scan
  ON mentor_tickets (escalation_level, created_at)
  WHERE status = 'open';

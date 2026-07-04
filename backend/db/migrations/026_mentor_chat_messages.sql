-- ════════════════════════════════════════════════════════════════════════════
-- 026_mentor_chat_messages.sql — 1:1 mentor-student chat
-- ════════════════════════════════════════════════════════════════════════════
-- Scoped to a mentor_tickets row (the student+mentor pairing), distinct from
-- the existing batch_messages (cohort Q&A) in the messaging package. Only the
-- ticket's student and its currently assigned mentor may read/send — see
-- backend/internal/mentoring/service.go.

CREATE TABLE mentor_chat_messages (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     UUID        NOT NULL REFERENCES organizations(id)  ON DELETE CASCADE,
  ticket_id  UUID        NOT NULL REFERENCES mentor_tickets(id) ON DELETE CASCADE,
  sender_id  UUID        NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  body       TEXT        NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mentor_chat_messages_ticket ON mentor_chat_messages (ticket_id, created_at);

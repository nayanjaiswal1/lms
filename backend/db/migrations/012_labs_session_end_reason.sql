-- Distinguishes why a lab session was auto-terminated by the background
-- reaper (lab.expire_sessions) from a normal user-driven end/completion,
-- which leaves this column NULL. Powers the "why did my lab end" message on
-- the result page.
ALTER TABLE lab_sessions ADD COLUMN end_reason TEXT
  CHECK (end_reason IN ('time_limit', 'idle_timeout'));

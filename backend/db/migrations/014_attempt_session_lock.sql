-- Locks an in-progress assessment attempt to a single active device/tab.
-- Every StartAttempt/ResumeAttempt call rotates this token, which supersedes
-- whatever device previously held it — the old device's next write (save
-- answer, run code, record event, submit) is rejected until it reopens the
-- attempt and picks up the new token. Never exposed on Attempt's general JSON
-- serialization (see ActiveSessionToken's json:"-" tag) — only returned once,
-- inline in the attempt-start/resume payload.
ALTER TABLE assessment_attempts ADD COLUMN active_session_token TEXT;

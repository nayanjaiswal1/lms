-- ══════════════════════════════════════════════════════════════════════════
-- 046_lab_completion_policy.sql — lab-kind completion policy support
-- (docs/labs.md "Completion policy", docs/debug-labs.md Phase 1b follow-up).
--
-- A lab kind can complete a session on the student's explicit Finish
-- (labkinds.CompleteOnFinish) instead of the instant the last required task
-- passes. Three things need to be stored for that to work:
--
--   required_passed_at  every required task has passed; the session stays
--                       active (write-up, review) until Finish or the
--                       deadline. Expiry/idle-reap then closes such a session
--                       as 'completed' rather than 'expired', in plain SQL
--                       with no kind knowledge (the reaper never loads tasks).
--   writeup_review      latest write-up review result (covered points,
--                       feedback, score_added, ...) so the debrief can show it.
--   student_diff        the student's git diff vs the scenario baseline,
--                       captured at Finish while the sandbox is still alive
--                       (the sandbox is killed right after), for the debrief.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

ALTER TABLE public.lab_sessions
  ADD COLUMN required_passed_at TIMESTAMPTZ,
  ADD COLUMN writeup_review     JSONB,
  ADD COLUMN student_diff       TEXT;

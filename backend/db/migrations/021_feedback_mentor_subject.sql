-- ════════════════════════════════════════════════════════════════════════════
-- 021_feedback_mentor_subject.sql — Allow 'mentor' as a feedback subject_type
-- ════════════════════════════════════════════════════════════════════════════
-- Reuses the generic feedback table (016_feedback.sql) for mentor ratings
-- instead of a parallel ratings table. subject_id = the mentor's user_id,
-- feedback.user_id = the student rating them.

ALTER TABLE feedback DROP CONSTRAINT feedback_subject_type_check;
ALTER TABLE feedback ADD CONSTRAINT feedback_subject_type_check
  CHECK (subject_type IN ('course','assessment','lab','mentor'));

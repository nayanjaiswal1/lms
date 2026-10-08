-- Experience reports ("did anything go wrong?") get their own value column
-- and live under their real subject type. They were filed under a synthetic
-- 'experience_subject' type only so they would not collide with a rating on
-- the same subject under a (subject_type, subject_id, user_id) key; keying on
-- kind as well removes the need. Every experience report so far was about an
-- assessment (the only subject the UI offers).
ALTER TABLE feedback
    ADD COLUMN experience text CHECK (experience IN ('smooth', 'issue', 'complaint'));

ALTER TABLE feedback DROP CONSTRAINT feedback_subject_type_subject_id_user_id_key;
ALTER TABLE feedback
    ADD CONSTRAINT feedback_kind_subject_user_key UNIQUE (kind, subject_type, subject_id, user_id);

UPDATE feedback SET subject_type = 'assessment'
WHERE kind = 'experience' AND subject_type = 'experience_subject';

ALTER TABLE feedback DROP CONSTRAINT feedback_subject_type_check;
ALTER TABLE feedback
    ADD CONSTRAINT feedback_subject_type_check
    CHECK (subject_type IN ('course', 'assessment', 'lab', 'mentor', 'mentor_session'));

ALTER TABLE feedback DROP CONSTRAINT feedback_rated_or_skipped;
ALTER TABLE feedback
    ADD CONSTRAINT feedback_answered_or_skipped CHECK (
        skipped_at IS NOT NULL
        OR (kind = 'rating' AND rating IS NOT NULL)
        OR (kind = 'experience' AND experience IS NOT NULL));

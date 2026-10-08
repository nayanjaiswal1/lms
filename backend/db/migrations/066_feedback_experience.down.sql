ALTER TABLE feedback DROP CONSTRAINT feedback_answered_or_skipped;
DELETE FROM feedback WHERE kind = 'experience' AND skipped_at IS NULL;
ALTER TABLE feedback
    ADD CONSTRAINT feedback_rated_or_skipped CHECK (rating IS NOT NULL OR skipped_at IS NOT NULL);

ALTER TABLE feedback DROP CONSTRAINT feedback_subject_type_check;
ALTER TABLE feedback
    ADD CONSTRAINT feedback_subject_type_check
    CHECK (subject_type IN ('course', 'assessment', 'lab', 'mentor', 'mentor_session', 'experience_subject'));

UPDATE feedback SET subject_type = 'experience_subject' WHERE kind = 'experience';

ALTER TABLE feedback DROP CONSTRAINT feedback_kind_subject_user_key;
ALTER TABLE feedback
    ADD CONSTRAINT feedback_subject_type_subject_id_user_id_key UNIQUE (subject_type, subject_id, user_id);

ALTER TABLE feedback DROP COLUMN experience;

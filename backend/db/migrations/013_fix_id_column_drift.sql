-- Migrations 001, 003, and 008 were edited in place on 2026-07-01 to change
-- several tables' id columns (UUID -> BIGINT IDENTITY, or dropped in favor of
-- a composite PK), on the assumption the dev DB had never been deployed.
-- It had (001 applied 2026-06-24), so schema_migrations already marked those
-- files as applied and the edits never reached the live database. The Go code
-- was updated to match the intended (edited) schema, so job_runs inserts have
-- been failing ever since ("cannot scan uuid in binary format into *int64").
-- This migration brings the live schema in line with the current file
-- contents of 001/003/008.

ALTER TABLE job_runs DROP CONSTRAINT job_runs_pkey;
ALTER TABLE job_runs DROP COLUMN id;
ALTER TABLE job_runs ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

ALTER TABLE audit_logs DROP CONSTRAINT audit_logs_pkey;
ALTER TABLE audit_logs DROP COLUMN id;
ALTER TABLE audit_logs ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

ALTER TABLE audit_log DROP CONSTRAINT audit_log_pkey;
ALTER TABLE audit_log DROP COLUMN id;
ALTER TABLE audit_log ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

ALTER TABLE xp_events DROP CONSTRAINT xp_events_pkey;
ALTER TABLE xp_events DROP COLUMN id;
ALTER TABLE xp_events ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

ALTER TABLE lab_usage_events DROP CONSTRAINT lab_usage_events_pkey;
ALTER TABLE lab_usage_events DROP COLUMN id;
ALTER TABLE lab_usage_events ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

ALTER TABLE attempt_events DROP CONSTRAINT attempt_events_pkey;
ALTER TABLE attempt_events DROP COLUMN id;
ALTER TABLE attempt_events ADD COLUMN id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

ALTER TABLE batch_members DROP CONSTRAINT batch_members_pkey;
ALTER TABLE batch_members DROP CONSTRAINT batch_members_batch_id_user_id_key;
ALTER TABLE batch_members DROP COLUMN id;
ALTER TABLE batch_members ADD PRIMARY KEY (batch_id, user_id);

ALTER TABLE batch_mentors DROP CONSTRAINT batch_mentors_pkey;
ALTER TABLE batch_mentors DROP CONSTRAINT batch_mentors_batch_id_user_id_key;
ALTER TABLE batch_mentors DROP COLUMN id;
ALTER TABLE batch_mentors ADD PRIMARY KEY (batch_id, user_id);

ALTER TABLE batch_courses DROP CONSTRAINT batch_courses_pkey;
ALTER TABLE batch_courses DROP CONSTRAINT batch_courses_batch_id_course_id_key;
ALTER TABLE batch_courses DROP COLUMN id;
ALTER TABLE batch_courses ADD PRIMARY KEY (batch_id, course_id);

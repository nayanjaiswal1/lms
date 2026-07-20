-- 014_offline_test_scores.sql
-- Manual entry for offline/paper classroom tests — a mentor/instructor
-- types in a class's scores for a named, dated test in one "Enter Scores"
-- submission. test_id groups every row from that one submission so the
-- test is addressable (view/edit) without a separate test-catalog table;
-- a test is just a name + date, not a reusable entity.
CREATE TABLE offline_test_scores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    user_id uuid NOT NULL,
    test_id uuid DEFAULT gen_random_uuid() NOT NULL,
    test_name text NOT NULL,
    test_date date NOT NULL,
    max_score numeric(6,2) NOT NULL,
    score numeric(6,2) NOT NULL,
    entered_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offline_test_scores_pkey PRIMARY KEY (id),
    CONSTRAINT offline_test_scores_test_name_check CHECK ((length(test_name) >= 1) AND (length(test_name) <= 200)),
    CONSTRAINT offline_test_scores_max_score_check CHECK (max_score > 0),
    CONSTRAINT offline_test_scores_score_check CHECK (score >= 0 AND score <= max_score),
    CONSTRAINT offline_test_scores_test_user_unique UNIQUE (test_id, user_id),
    CONSTRAINT offline_test_scores_org_id_fkey FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CONSTRAINT offline_test_scores_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE CASCADE,
    CONSTRAINT offline_test_scores_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT offline_test_scores_entered_by_fkey FOREIGN KEY (entered_by) REFERENCES users(id)
);

CREATE INDEX offline_test_scores_batch_test_idx ON offline_test_scores (batch_id, test_id);

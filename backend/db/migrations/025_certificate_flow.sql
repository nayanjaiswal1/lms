-- ═════════════════════════════════════════════════════════════════════════
-- Migration 025 — certificate_flow
-- Certificates were previously issuable only by passing a course's final
-- test. This adds two more issuance paths that reuse the same certificates
-- table (so "my certificates" / public verification keep working
-- unchanged): a mentor manually awarding one to a student, and an automatic
-- award once a learner crosses a per-course completion threshold (paid
-- courses additionally require a completed purchase). issue_type records
-- which path produced a given row; issued_by is set only for the manual
-- path. final_test_attempt_id becomes nullable since the manual/threshold
-- paths have no attempt behind them.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.certificates
    ALTER COLUMN final_test_attempt_id DROP NOT NULL,
    ADD COLUMN issue_type text DEFAULT 'final_test'::text NOT NULL,
    ADD COLUMN issued_by uuid,
    ADD CONSTRAINT certificates_issue_type_check
        CHECK (issue_type = ANY (ARRAY['final_test'::text, 'manual'::text, 'threshold'::text])),
    ADD CONSTRAINT certificates_issued_by_fkey FOREIGN KEY (issued_by)
        REFERENCES public.users(id) ON DELETE SET NULL;

CREATE TABLE public.certificate_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    threshold_percent int NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT certificate_rules_pkey PRIMARY KEY (id),
    CONSTRAINT certificate_rules_course_fkey FOREIGN KEY (course_id)
        REFERENCES public.courses(id) ON DELETE CASCADE,
    CONSTRAINT certificate_rules_course_unique UNIQUE (course_id),
    CONSTRAINT certificate_rules_threshold_check CHECK (threshold_percent BETWEEN 1 AND 100)
);

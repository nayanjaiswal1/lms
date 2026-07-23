-- ═════════════════════════════════════════════════════════════════════════
-- Migration 006 — add_final_test_certificates
-- A course may have one final test (time-limited MCQ + coding questions).
-- Passing it issues a certificate with a publicly-verifiable UUID
-- (GET /api/certificates/:uuid, no auth). final_test_id has no course-scoped
-- uniqueness on attempts/certificates beyond the FKs below — max_attempts and
-- "already passed" are enforced in the service layer, not by constraints,
-- since a passed learner may still have earlier failed attempts on record.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.final_tests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    course_id uuid NOT NULL,
    org_id uuid,
    questions jsonb DEFAULT '[]'::jsonb NOT NULL,
    time_limit_minutes int NOT NULL,
    passing_score_percent int DEFAULT 70 NOT NULL,
    max_attempts int DEFAULT 3 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT final_tests_pkey PRIMARY KEY (id),
    CONSTRAINT final_tests_course_fk FOREIGN KEY (course_id)
        REFERENCES public.courses(id) ON DELETE CASCADE,
    CONSTRAINT final_tests_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT final_tests_course_unique UNIQUE (course_id),
    CONSTRAINT final_tests_time_limit_check CHECK (time_limit_minutes > 0),
    CONSTRAINT final_tests_passing_score_check CHECK (passing_score_percent BETWEEN 1 AND 100),
    CONSTRAINT final_tests_max_attempts_check CHECK (max_attempts > 0)
);

CREATE TABLE public.final_test_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    final_test_id uuid NOT NULL,
    answers jsonb NOT NULL,
    score int NOT NULL,
    total int NOT NULL,
    passed boolean NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT final_test_attempts_pkey PRIMARY KEY (id),
    CONSTRAINT final_test_attempts_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT final_test_attempts_test_fk FOREIGN KEY (final_test_id)
        REFERENCES public.final_tests(id) ON DELETE CASCADE
);

CREATE INDEX idx_final_test_attempts_user_test ON public.final_test_attempts (user_id, final_test_id);

CREATE TABLE public.certificates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    final_test_attempt_id uuid NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    cert_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    CONSTRAINT certificates_pkey PRIMARY KEY (id),
    CONSTRAINT certificates_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT certificates_course_fk FOREIGN KEY (course_id)
        REFERENCES public.courses(id) ON DELETE CASCADE,
    CONSTRAINT certificates_attempt_fk FOREIGN KEY (final_test_attempt_id)
        REFERENCES public.final_test_attempts(id) ON DELETE CASCADE,
    CONSTRAINT certificates_attempt_unique UNIQUE (final_test_attempt_id),
    CONSTRAINT certificates_cert_uuid_unique UNIQUE (cert_uuid)
);

CREATE INDEX idx_certificates_user_course ON public.certificates (user_id, course_id);

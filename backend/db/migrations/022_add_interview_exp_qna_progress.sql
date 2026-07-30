-- ═════════════════════════════════════════════════════════════════════════
-- Migration 022 — add_interview_exp_qna_progress
-- Per-user todo/done/revisit status + star on individual interview_exp_qna
-- rows, powering the /interview-exp/faq page (cross-post aggregate of every
-- question, styled like the Sheet Tracker). Deliberately its own table
-- rather than a mirrored sheet_items row — see docs/interview-experiences.md
-- "Frequently Asked Questions Page" for why. No SRS/revision-date scheduling
-- (that's Sheets' spaced-repetition layer); just the 3-state status + star.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.interview_exp_qna_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    qna_id uuid NOT NULL,
    status text DEFAULT 'todo'::text NOT NULL,
    is_starred boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT interview_exp_qna_progress_pkey PRIMARY KEY (id),
    CONSTRAINT interview_exp_qna_progress_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_qna_progress_qna_fk FOREIGN KEY (qna_id)
        REFERENCES public.interview_exp_qna(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_qna_progress_status_check CHECK (status = ANY (ARRAY['todo'::text, 'done'::text, 'revisit'::text])),
    CONSTRAINT interview_exp_qna_progress_unique UNIQUE (user_id, qna_id)
);

CREATE INDEX idx_interview_exp_qna_progress_user
    ON public.interview_exp_qna_progress (user_id);

-- ═════════════════════════════════════════════════════════════════════════
-- Migration 010 — add_practice_question_bank
-- Question generation is currently one LLM call per session, even when many
-- users request the same (technology, difficulty, category) combo. This adds
-- a shared bank: practice.Service.generateQuestions becomes cache-first,
-- reusing a recent bank row across users/sessions and only calling the LLM
-- on a genuine miss. Per-answer AI feedback is NOT cached — it depends on
-- the specific answer text and must stay live.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.practice_question_bank (
    id            uuid DEFAULT gen_random_uuid() NOT NULL,
    technology    text NOT NULL,
    difficulty    text NOT NULL,
    category      text DEFAULT 'technical'::text NOT NULL,
    questions     text[] NOT NULL,
    ai_model      text,
    use_count     integer DEFAULT 0 NOT NULL,
    created_at    timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT practice_question_bank_pkey PRIMARY KEY (id),
    CONSTRAINT practice_question_bank_category_check CHECK (category IN ('technical', 'behavioral')),
    CONSTRAINT practice_question_bank_questions_check CHECK (cardinality(questions) > 0)
);

CREATE INDEX idx_practice_question_bank_lookup
    ON public.practice_question_bank (technology, difficulty, category, created_at DESC);

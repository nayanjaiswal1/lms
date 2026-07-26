-- ═════════════════════════════════════════════════════════════════════════
-- Migration 019 — add_mistake_entries
-- Mistake & Progress Ledger: a first-class, timestamped event log for
-- student mistakes (grammar/concept/etc.), separate from course modules
-- (static content) and from lesson_reflections (free-text understanding
-- notes). Deliberately a single table — trend, recurrence, and per-category
-- counts are derived at read time (GROUP BY / LAG window functions) rather
-- than materialized, since one learner's ledger is a few hundred to a few
-- thousand rows, not an analytics-at-scale dataset. Spaced revision reuses
-- the existing internal/srs engine (source_type = 'mistake') instead of a
-- second scheduler — mistake_entry_id links a card back to the mistake it
-- drills.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.mistake_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    category text NOT NULL,
    sub_topic text NOT NULL,
    original_text text NOT NULL,
    corrected_text text NOT NULL,
    context_tag text,
    source_module_id uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mistake_entries_pkey PRIMARY KEY (id),
    CONSTRAINT mistake_entries_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT mistake_entries_module_fk FOREIGN KEY (source_module_id)
        REFERENCES public.course_modules(id) ON DELETE SET NULL,
    CONSTRAINT mistake_entries_category_check CHECK (category = ANY (ARRAY[
        'tense'::text, 'article'::text, 'preposition'::text, 'subject_verb_agreement'::text,
        'spelling'::text, 'sentence_fragment'::text, 'run_on'::text, 'vocabulary'::text,
        'punctuation'::text, 'other'::text])),
    CONSTRAINT mistake_entries_sub_topic_not_blank_check CHECK (btrim(sub_topic) <> ''::text),
    CONSTRAINT mistake_entries_original_not_blank_check CHECK (btrim(original_text) <> ''::text)
);

-- Serves both the timeline (ORDER BY created_at) and the per-category
-- summary (which aggregates every category for the user, so a
-- category-leading key would buy nothing over this).
CREATE INDEX idx_mistake_entries_user_created
    ON public.mistake_entries (user_id, created_at DESC);

-- Links an SRS card back to the mistake it drills. question_id can't be
-- reused for this: it FKs public.questions specifically.
ALTER TABLE public.srs_cards
    ADD COLUMN mistake_entry_id uuid,
    ADD CONSTRAINT srs_cards_mistake_entry_fk FOREIGN KEY (mistake_entry_id)
        REFERENCES public.mistake_entries(id) ON DELETE CASCADE;

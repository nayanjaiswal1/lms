-- 016_lesson_reflections.sql
-- Free-text "what did you understand from this lesson" reflection, captured
-- at the bottom of every notes-type lesson page — separate from the mcq/sql
-- knowledge-check questions above it (see 012_lesson_knowledge_checks.sql).
-- Ungraded, one row per (user, module): resubmitting replaces the previous
-- answer rather than accumulating a history, since only the student's
-- current stated understanding matters to readers of this table. This is
-- the raw input a future revision-plan / concept-dependency-graph feature
-- will read — that consumer does not exist yet, so this migration only adds
-- the capture table, not any graph/plan schema.
CREATE TABLE lesson_reflections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    module_id uuid NOT NULL,
    response text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lesson_reflections_pkey PRIMARY KEY (id),
    CONSTRAINT lesson_reflections_user_module_key UNIQUE (user_id, module_id),
    CONSTRAINT lesson_reflections_response_not_blank_check CHECK (btrim(response) <> ''),
    CONSTRAINT lesson_reflections_module_id_fkey
      FOREIGN KEY (module_id) REFERENCES course_modules(id) ON DELETE CASCADE,
    CONSTRAINT lesson_reflections_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Supports the future revision-plan/graph reader's natural access pattern:
-- "every reflection for this module, within this org."
CREATE INDEX idx_lesson_reflections_org_module ON lesson_reflections (org_id, module_id);

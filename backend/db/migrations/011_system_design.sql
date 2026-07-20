-- 011_system_design.sql
-- System Design practice board: per-question Excalidraw whiteboard attempts,
-- AI clarifying-question chat, and AI feedback — attached to course modules.
--
-- Reuses course_modules as the question bank (title + content_body already
-- carry "Why interviewers ask this" / "Requirements" guidance for the 28
-- seeded System Design section lessons) instead of a separate questions
-- table. type='system_design' is a new module type alongside the existing
-- video/pdf/notes/assessment/lab set.

ALTER TABLE course_modules DROP CONSTRAINT course_modules_type_check;
ALTER TABLE course_modules ADD CONSTRAINT course_modules_type_check
  CHECK (type = ANY (ARRAY['video'::text, 'pdf'::text, 'notes'::text, 'assessment'::text, 'lab'::text, 'system_design'::text]));

-- Migrate the already-seeded "System Design" section lessons (Day 1 URL
-- Shortener .. Day 28) from 'notes' to the new dedicated type so the learn
-- page renders the whiteboard instead of a plain reading view.
UPDATE course_modules
SET type = 'system_design', updated_at = now()
WHERE section_id = '58424ed6-4690-5ef0-ab6a-65ab3cc84017'
  AND type = 'notes'
  AND title !~ 'Weekly (Review|Checkpoint)';

-- One row per attempt: a student can restart a question from a blank canvas
-- ("+ New attempt") without losing earlier tries. scene is the full
-- Excalidraw document (elements + appState) round-tripped verbatim.
CREATE TABLE system_design_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    module_id uuid NOT NULL,
    user_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    scene jsonb DEFAULT '{"elements": [], "appState": {}}'::jsonb NOT NULL,
    feedback text,
    feedback_model text,
    feedback_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT system_design_attempts_pkey PRIMARY KEY (id),
    CONSTRAINT system_design_attempts_attempt_number_check CHECK (attempt_number >= 1),
    CONSTRAINT system_design_attempts_module_user_attempt_key UNIQUE (module_id, user_id, attempt_number),
    CONSTRAINT system_design_attempts_module_id_fkey
      FOREIGN KEY (module_id) REFERENCES course_modules(id) ON DELETE CASCADE,
    CONSTRAINT system_design_attempts_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- "List my attempts for this question" (attempt selector) + ownership lookups.
CREATE INDEX idx_system_design_attempts_module_user
  ON system_design_attempts (module_id, user_id, attempt_number);

-- The "Ask clarifying questions" AI chat, scoped per student per question
-- (not per attempt — the same clarifying-question thread carries across
-- restarts, matching how a real interview conversation would work).
CREATE TABLE system_design_chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    module_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT system_design_chat_messages_pkey PRIMARY KEY (id),
    CONSTRAINT system_design_chat_messages_role_check CHECK (role = ANY (ARRAY['user'::text, 'assistant'::text])),
    CONSTRAINT system_design_chat_messages_content_check CHECK (char_length(content) <= 4000),
    CONSTRAINT system_design_chat_messages_module_id_fkey
      FOREIGN KEY (module_id) REFERENCES course_modules(id) ON DELETE CASCADE,
    CONSTRAINT system_design_chat_messages_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_system_design_chat_module_user
  ON system_design_chat_messages (module_id, user_id, created_at);

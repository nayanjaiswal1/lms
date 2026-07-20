-- 012_lesson_knowledge_checks.sql
-- Embedded "knowledge check" questions on notes-type lesson modules: 2-3
-- quick questions (mcq | sql) combining the lesson's concepts, shown on the
-- same page as the lesson body, gating the module's "Mark as Complete"
-- button until answered correctly. Content-authored via a `knowledge-check`
-- fenced block in the lesson's canonical markdown (see
-- contentpipeline/generator/render_lesson.go), extracted at generate time.
--
-- knowledge_check holds only what's needed to grade + gate server-side:
--   [{"id": "<question id>", "type": "mcq"|"sql", "correct": "<option id>"}]
-- `correct` is present for mcq only (the answer key) — sql questions have no
-- server-side executor (see backend/internal/assessment/executor.go, which
-- has no "sql" language entry either), so they carry only id/type and stay
-- client-graded, same trust level the pre-existing sql-challenge lesson
-- segment already ships. The prompt/options/starter/solution text lives only
-- in the lesson's content_body markdown, never duplicated here.
ALTER TABLE course_modules ADD COLUMN knowledge_check jsonb NOT NULL DEFAULT '[]'::jsonb;

-- One row per attempt (correct or wrong) — the append-only record the
-- product wants for future analytics/spaced-repetition weighting, and the
-- source of truth UpdateProgress checks before allowing a notes module with
-- knowledge_check questions to be marked complete.
CREATE TABLE lesson_check_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    module_id uuid NOT NULL,
    question_id text NOT NULL,
    question_type text NOT NULL,
    answer jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_correct boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lesson_check_attempts_pkey PRIMARY KEY (id),
    CONSTRAINT lesson_check_attempts_question_type_check CHECK (question_type = ANY (ARRAY['mcq'::text, 'sql'::text])),
    CONSTRAINT lesson_check_attempts_module_id_fkey
      FOREIGN KEY (module_id) REFERENCES course_modules(id) ON DELETE CASCADE,
    CONSTRAINT lesson_check_attempts_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- "Which questions has this student already passed on this module" (the gate
-- check in UpdateProgress, and GetMyCheckProgress seeding the frontend gate
-- on page load).
CREATE INDEX idx_lesson_check_attempts_module_user
  ON lesson_check_attempts (module_id, user_id, is_correct);

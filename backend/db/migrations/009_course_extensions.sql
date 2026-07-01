-- ════════════════════════════════════════════════════════════════════════════
-- 009_course_extensions.sql
-- Extends course domain: adds 'expert' difficulty level and 'lab' module type.
-- Both are additive — no existing data is affected.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── courses.difficulty: add 'expert' ────────────────────────────────────────
-- Drop the generated unnamed CHECK that guards difficulty, then replace it.
DO $$
DECLARE v_name text;
BEGIN
  SELECT con.conname INTO v_name
  FROM pg_constraint con
  JOIN pg_class cl ON cl.oid = con.conrelid
  WHERE cl.relname = 'courses'
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) LIKE '%difficulty%'
  LIMIT 1;
  IF v_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE courses DROP CONSTRAINT ' || quote_ident(v_name);
  END IF;
END$$;

ALTER TABLE courses
  ADD CONSTRAINT courses_difficulty_check
  CHECK (difficulty IN ('beginner','intermediate','advanced','expert'));

-- ─── course_modules.type: add 'lab' ──────────────────────────────────────────
-- A 'lab' module has no content_body — the linked lab_definition provides content.
DO $$
DECLARE v_name text;
BEGIN
  SELECT con.conname INTO v_name
  FROM pg_constraint con
  JOIN pg_class cl ON cl.oid = con.conrelid
  WHERE cl.relname = 'course_modules'
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) LIKE '%video%'
  LIMIT 1;
  IF v_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE course_modules DROP CONSTRAINT ' || quote_ident(v_name);
  END IF;
END$$;

ALTER TABLE course_modules
  ADD CONSTRAINT course_modules_type_check
  CHECK (type IN ('video','pdf','notes','assessment','lab'));

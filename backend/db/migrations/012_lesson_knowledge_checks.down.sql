-- 012_lesson_knowledge_checks.down.sql

DROP TABLE IF EXISTS lesson_check_attempts;
ALTER TABLE course_modules DROP COLUMN IF EXISTS knowledge_check;

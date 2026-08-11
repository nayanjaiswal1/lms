DROP TRIGGER IF EXISTS course_modules_lock_section_trigger ON course_modules;
DROP FUNCTION IF EXISTS course_modules_lock_section();
ALTER TABLE course_modules ALTER COLUMN position SET DEFAULT 0;

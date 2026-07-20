-- 011_system_design.down.sql

DROP TABLE IF EXISTS system_design_chat_messages;
DROP TABLE IF EXISTS system_design_attempts;

UPDATE course_modules
SET type = 'notes', updated_at = now()
WHERE section_id = '58424ed6-4690-5ef0-ab6a-65ab3cc84017'
  AND type = 'system_design';

ALTER TABLE course_modules DROP CONSTRAINT course_modules_type_check;
ALTER TABLE course_modules ADD CONSTRAINT course_modules_type_check
  CHECK (type = ANY (ARRAY['video'::text, 'pdf'::text, 'notes'::text, 'assessment'::text, 'lab'::text]));

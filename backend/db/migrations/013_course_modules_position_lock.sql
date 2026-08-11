-- Serializes concurrent inserts into course_modules for the same section.
--
-- course_modules_section_id_position_key is DEFERRABLE INITIALLY DEFERRED,
-- so a duplicate (section_id, position) isn't caught until COMMIT. Every
-- write path (the CreateModule API, proposal approval, course forking, the
-- roadmap-generation job) independently computed MAX(position)+1, so two
-- transactions touching the same section concurrently could both compute
-- the same position and only collide at commit. An advisory lock keyed on
-- section_id, taken once per row in a BEFORE INSERT trigger, serializes all
-- of those paths without requiring every call site to remember to lock.
--
-- position has DEFAULT 0 NOT NULL, and column defaults are applied before a
-- BEFORE INSERT trigger ever sees the row — so "did the caller ask us to
-- assign a position" can't be read off NEW.position IS NULL unless the
-- default is removed first. NOT NULL stays: the trigger always leaves
-- NEW.position set (either the caller's explicit value or its own MAX+1
-- computation) before the row is actually written.
ALTER TABLE course_modules ALTER COLUMN position DROP DEFAULT;

CREATE OR REPLACE FUNCTION course_modules_lock_section() RETURNS trigger AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(NEW.section_id::text));
  IF NEW.position IS NULL THEN
    SELECT COALESCE(MAX(position) + 1, 0) INTO NEW.position
      FROM course_modules WHERE section_id = NEW.section_id AND deleted_at IS NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER course_modules_lock_section_trigger
  BEFORE INSERT ON course_modules
  FOR EACH ROW EXECUTE FUNCTION course_modules_lock_section();

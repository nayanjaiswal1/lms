-- ════════════════════════════════════════════════════════════════════════════
-- 015_lab_language.sql — Give code labs an authoritative language
-- ════════════════════════════════════════════════════════════════════════════
-- Code labs had no language column: the frontend tracked a client-side
-- "language" dropdown independent of the task being worked on, and the backend
-- trusted whatever language string the client sent when executing the
-- submission through Piston. A stale/mismatched client value let a
-- JavaScript verification script be executed under the Python runtime.
-- Making language a per-lab column lets the backend derive it authoritatively
-- and lets the frontend lock the editor to the lab's language instead of
-- offering a switcher that can drift from what the tasks actually verify.

ALTER TABLE lab_definitions
  ADD COLUMN language TEXT CHECK (language IN ('javascript','typescript','python','go'));

UPDATE lab_definitions
  SET language = 'javascript'
  WHERE lab_type = 'code' AND language IS NULL;

ALTER TABLE lab_definitions
  ADD CONSTRAINT lab_definitions_code_requires_language
  CHECK (lab_type <> 'code' OR language IS NOT NULL);

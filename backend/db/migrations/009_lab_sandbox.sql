-- Sandbox lab type: CodeSandbox-style IDE labs with HackerEarth-style
-- Run (visible sample tests via run_script) and Submit (batch hidden
-- verification). Tasks are optional for sandbox labs, like playground.
ALTER TABLE lab_definitions
  DROP CONSTRAINT lab_definitions_lab_type_check;
ALTER TABLE lab_definitions
  ADD CONSTRAINT lab_definitions_lab_type_check
  CHECK (lab_type = ANY (ARRAY['terminal'::text, 'code'::text, 'playground'::text, 'guided'::text, 'sandbox'::text]));

-- run_script is the instructor-authored, student-visible sample-test command
-- executed in the session container by POST /api/labs/sessions/:id/run.
-- NULL = the workspace shows no Run button. Its content is never sent to the
-- client (only a has_run_script boolean) to keep authoring flexibility.
ALTER TABLE lab_definitions
  ADD COLUMN run_script text;

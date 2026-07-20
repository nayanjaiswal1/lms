ALTER TABLE lab_definitions DROP COLUMN run_script;
ALTER TABLE lab_definitions
  DROP CONSTRAINT lab_definitions_lab_type_check;
ALTER TABLE lab_definitions
  ADD CONSTRAINT lab_definitions_lab_type_check
  CHECK (lab_type = ANY (ARRAY['terminal'::text, 'code'::text, 'playground'::text, 'guided'::text]));

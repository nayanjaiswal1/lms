-- 013_org_type.sql
-- Org-level terminology: lets the UI say "Teacher"/"Class" for a school,
-- "Professor"/"Class" for a college, "Trainer"/"Team" for a company, etc.
-- Nullable with no default so existing orgs keep today's generic wording
-- (Mentor/Batch/Student) until an admin opts in via org settings.
ALTER TABLE organizations ADD COLUMN org_type text;
ALTER TABLE organizations ADD CONSTRAINT organizations_org_type_check
  CHECK (org_type IS NULL OR org_type = ANY (ARRAY['school'::text, 'college'::text, 'university'::text, 'bootcamp'::text, 'corporate'::text]));

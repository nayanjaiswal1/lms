-- 013_org_type.down.sql

ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_org_type_check;
ALTER TABLE organizations DROP COLUMN IF EXISTS org_type;

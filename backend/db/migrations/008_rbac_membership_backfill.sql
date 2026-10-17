-- 008_rbac_membership_backfill.sql
-- user_roles is the single source of RBAC access, and every org membership
-- write now assigns the system role mapped from org_members.role
-- (internal/authz/sysrole). Before that only owner/admin got a role
-- (tenant_admin), so invited / social / provisioned / batch-imported members
-- had an empty permission set. This backfills the gap for live memberships
-- (status active or suspended):
--   A. owner/admin/instructor/mentor missing their mapped system role
--      (tenant_admin/tenant_admin/instructor/mentor) -> grant it.
--   B. learner with no user_roles row at all in that org -> grant member.
--   C. learner already holding any role (viewer, custom) -> left alone; an
--      admin chose that set deliberately.
-- Every row inserted here is recorded in rbac_backfill_008 so the down
-- migration removes exactly these grants and nothing assigned before or since.
-- Cached permission sets (Redis rbac:perms:*) refresh within their 5-minute TTL.
--
-- Pre-flight drift check (run before applying; counts what A and B will insert):
--   WITH m(label, role_name) AS (VALUES ('owner','tenant_admin'), ('admin','tenant_admin'),
--                                       ('instructor','instructor'), ('mentor','mentor'))
--   SELECT 'A:' || om.role AS category, count(*)
--   FROM org_members om
--   JOIN m ON m.label = om.role
--   JOIN roles r ON r.name = m.role_name AND r.is_system
--   WHERE om.status IN ('active','suspended')
--     AND NOT EXISTS (SELECT 1 FROM user_roles ur
--                     WHERE ur.user_id = om.user_id AND ur.org_id = om.org_id AND ur.role_id = r.id)
--   GROUP BY om.role
--   UNION ALL
--   SELECT 'B:learner', count(*)
--   FROM org_members om
--   WHERE om.status IN ('active','suspended') AND om.role = 'learner'
--     AND NOT EXISTS (SELECT 1 FROM user_roles ur
--                     WHERE ur.user_id = om.user_id AND ur.org_id = om.org_id);

CREATE TABLE rbac_backfill_008 (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    org_id  uuid NOT NULL,
    PRIMARY KEY (user_id, role_id, org_id)
);

WITH label_map(label, role_name) AS (
    VALUES ('owner', 'tenant_admin'), ('admin', 'tenant_admin'),
           ('instructor', 'instructor'), ('mentor', 'mentor')
),
wanted AS (
    -- A: staff labels always get their mapped role (ON CONFLICT skips holders).
    SELECT om.user_id, r.id AS role_id, om.org_id
    FROM org_members om
    JOIN label_map m ON m.label = om.role
    JOIN roles r ON r.name = m.role_name AND r.is_system
    WHERE om.status IN ('active', 'suspended')
    UNION ALL
    -- B: learners with no role at all in the org get member.
    SELECT om.user_id, r.id, om.org_id
    FROM org_members om
    JOIN roles r ON r.name = 'member' AND r.is_system
    WHERE om.status IN ('active', 'suspended')
      AND om.role = 'learner'
      AND NOT EXISTS (SELECT 1 FROM user_roles ur
                      WHERE ur.user_id = om.user_id AND ur.org_id = om.org_id)
),
inserted AS (
    INSERT INTO user_roles (user_id, role_id, org_id)
    SELECT user_id, role_id, org_id FROM wanted
    ON CONFLICT DO NOTHING
    RETURNING user_id, role_id, org_id
)
INSERT INTO rbac_backfill_008 (user_id, role_id, org_id)
SELECT user_id, role_id, org_id FROM inserted;

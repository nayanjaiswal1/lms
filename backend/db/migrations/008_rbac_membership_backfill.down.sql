-- 008_rbac_membership_backfill rollback: remove exactly the user_roles rows
-- the up migration inserted (recorded in rbac_backfill_008), then drop the
-- tracking table. Grants that existed before 008, or were added since by an
-- admin, are untouched unless they are the same (user, role, org) row.
DELETE FROM user_roles ur
USING rbac_backfill_008 b
WHERE ur.user_id = b.user_id
  AND ur.role_id = b.role_id
  AND ur.org_id  = b.org_id;

DROP TABLE rbac_backfill_008;

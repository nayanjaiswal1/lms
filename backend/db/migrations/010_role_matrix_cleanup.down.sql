-- 010_role_matrix_cleanup rollback: restore the snapshotted permission rows,
-- grants and overrides exactly as they were, then remove exactly the member
-- grants the up migration added (recorded in rbac_backfill_010).
INSERT INTO permissions SELECT * FROM rbac_010_removed_permissions;

INSERT INTO role_permissions (role_id, permission_id)
SELECT role_id, permission_id FROM rbac_010_removed_grants
ON CONFLICT DO NOTHING;

INSERT INTO user_permission_overrides SELECT * FROM rbac_010_removed_overrides
ON CONFLICT DO NOTHING;

DELETE FROM user_roles ur
USING rbac_backfill_010 b
WHERE ur.user_id = b.user_id
  AND ur.role_id = b.role_id
  AND ur.org_id  = b.org_id;

DROP TABLE rbac_backfill_010, rbac_010_removed_grants, rbac_010_removed_overrides, rbac_010_removed_permissions;

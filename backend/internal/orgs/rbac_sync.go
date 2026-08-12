package orgs

import (
	"context"

	"github.com/jackc/pgx/v5/pgconn"
)

// sqlExecer is satisfied by both *pgxpool.Pool and pgx.Tx, so syncTenantAdminRole
// can run inside an existing transaction or standalone.
type sqlExecer interface {
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
}

// syncTenantAdminRole keeps the RBAC user_roles table in step with
// org_members.role. Nothing else assigns RBAC roles automatically — a user
// becoming owner/admin here previously granted every legacy CallerRole check
// but none of the admin.* permission checks (e.g. admin.view_audit_log),
// since those are powered entirely by user_roles/role_permissions, a
// separate table this package never wrote to. Call this everywhere
// org_members.role is set: org creation, invite acceptance, member update,
// and member removal.
func syncTenantAdminRole(ctx context.Context, db sqlExecer, orgID, userID, role string) error {
	if role == RoleOwner || role == RoleAdmin {
		_, err := db.Exec(ctx,
			`INSERT INTO user_roles (user_id, role_id, org_id)
			 SELECT $1, id, $2 FROM roles WHERE name = 'tenant_admin' AND is_system = true
			 ON CONFLICT DO NOTHING`,
			userID, orgID,
		)
		return err
	}
	_, err := db.Exec(ctx,
		`DELETE FROM user_roles
		 WHERE user_id = $1 AND org_id = $2
		   AND role_id = (SELECT id FROM roles WHERE name = 'tenant_admin' AND is_system = true)`,
		userID, orgID,
	)
	return err
}

// Package sysrole is the single writer that keeps user_roles in step with
// org_members.role. Every org membership insert or label change calls Sync in
// the same transaction, so a member's RBAC permission set always contains the
// system role mapped from their label.
//
// It lives in its own leaf package (pgx only) rather than in authz because
// authz imports auth, and auth is one of the callers.
package sysrole

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

// Execer is satisfied by *pgxpool.Pool, *pgx.Conn and pgx.Tx.
type Execer interface {
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
}

// byLabel maps an org_members.role label to the name of the system role
// (roles.is_system = true) it grants.
var byLabel = map[string]string{
	"owner":      "tenant_admin",
	"admin":      "tenant_admin",
	"instructor": "instructor",
	"mentor":     "mentor",
	"learner":    "member",
}

// Sync grants userID the system role mapped from newLabel in orgID and, when
// the label changed, revokes the system role mapped from prevLabel — unless
// both labels map to the same role (owner <-> admin). Any other role the user
// holds (custom roles, extra system roles assigned through the RBAC admin) is
// left untouched. Pass prevLabel "" for a brand-new membership. Idempotent.
func Sync(ctx context.Context, db Execer, orgID, userID, newLabel, prevLabel string) error {
	newRole, ok := byLabel[newLabel]
	if !ok {
		return fmt.Errorf("sysrole: sync: unknown member label %q", newLabel)
	}
	if prevLabel != "" && prevLabel != newLabel {
		prevRole, ok := byLabel[prevLabel]
		if !ok {
			return fmt.Errorf("sysrole: sync: unknown previous member label %q", prevLabel)
		}
		if prevRole != newRole {
			if _, err := db.Exec(ctx,
				`DELETE FROM user_roles
				 WHERE user_id = $1 AND org_id = $2
				   AND role_id = (SELECT id FROM roles WHERE name = $3 AND is_system = true)`,
				userID, orgID, prevRole,
			); err != nil {
				return fmt.Errorf("sysrole: sync: revoke %s: %w", prevRole, err)
			}
		}
	}
	if _, err := db.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id)
		 SELECT $1, id, $2 FROM roles WHERE name = $3 AND is_system = true
		 ON CONFLICT DO NOTHING`,
		userID, orgID, newRole,
	); err != nil {
		return fmt.Errorf("sysrole: sync: grant %s: %w", newRole, err)
	}
	return nil
}

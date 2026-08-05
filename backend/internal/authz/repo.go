package authz

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo handles all authz queries against PostgreSQL.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo backed by the given connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// GetEffectivePermissions returns all active permission codes held by userID
// within orgID, resolved by walking user_roles → roles → role_permissions → permissions,
// unioned with any direct grants in user_permission_overrides (bypasses roles
// entirely — see docs/rbac.md §1 for why this exception exists).
// Returns an empty (non-nil) slice when the user holds no permissions.
func (r *Repo) GetEffectivePermissions(ctx context.Context, userID, orgID string) ([]string, error) {
	const q = `
		SELECT DISTINCT p.code
		FROM user_roles ur
		JOIN roles r ON r.id = ur.role_id AND r.is_active = true
		JOIN role_permissions rp ON rp.role_id = r.id
		JOIN permissions p ON p.id = rp.permission_id AND p.is_active = true
		WHERE ur.user_id = $1
		  AND ur.org_id = $2
		UNION
		SELECT p.code
		FROM user_permission_overrides upo
		JOIN permissions p ON p.id = upo.permission_id AND p.is_active = true
		WHERE upo.user_id = $1
		  AND upo.org_id = $2`

	rows, err := r.pool.Query(ctx, q, userID, orgID)
	if err != nil {
		return nil, fmt.Errorf("authz repo: get effective permissions: %w", err)
	}
	defer rows.Close()

	codes := []string{}
	for rows.Next() {
		var code string
		if err := rows.Scan(&code); err != nil {
			return nil, fmt.Errorf("authz repo: get effective permissions: %w", err)
		}
		codes = append(codes, code)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("authz repo: get effective permissions: %w", err)
	}
	return codes, nil
}

// GetAssignmentsForRole returns every (user_id, org_id) pair that holds roleID.
// Used during role invalidation to flush all affected users from the permission cache.
func (r *Repo) GetAssignmentsForRole(ctx context.Context, roleID string) ([]UserRoleAssignment, error) {
	const q = `SELECT user_id, org_id FROM user_roles WHERE role_id = $1`

	rows, err := r.pool.Query(ctx, q, roleID)
	if err != nil {
		return nil, fmt.Errorf("authz repo: get assignments for role: %w", err)
	}
	defer rows.Close()

	var assignments []UserRoleAssignment
	for rows.Next() {
		var a UserRoleAssignment
		if err := rows.Scan(&a.UserID, &a.OrgID); err != nil {
			return nil, fmt.Errorf("authz repo: get assignments for role: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("authz repo: get assignments for role: %w", err)
	}
	return assignments, nil
}

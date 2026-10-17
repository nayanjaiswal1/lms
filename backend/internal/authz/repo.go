package authz

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
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

// GetEffectivePermissions returns all permission codes userID holds within
// orgID, read from the effective_permissions view (migration 009): active role
// grants unioned with direct user_permission_overrides (see docs/rbac.md §1),
// limited to active roles, active permissions and an active org membership.
// Returns an empty (non-nil) slice when the user holds no permissions.
func (r *Repo) GetEffectivePermissions(ctx context.Context, userID, orgID string) ([]string, error) {
	const q = `SELECT code FROM effective_permissions WHERE user_id = $1 AND org_id = $2`

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

// OrgPermissionHolders returns the IDs of every user who holds code in orgID,
// from the same effective_permissions view per-user checks use — the one
// answer to "who should be notified / may act on this in the org".
func (r *Repo) OrgPermissionHolders(ctx context.Context, orgID, code string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT user_id FROM effective_permissions WHERE org_id = $1 AND code = $2`, orgID, code)
	if err != nil {
		return nil, fmt.Errorf("authz repo: org permission holders: %w", err)
	}
	userIDs, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return nil, fmt.Errorf("authz repo: org permission holders: %w", err)
	}
	return userIDs, nil
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

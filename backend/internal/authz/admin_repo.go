package authz

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/db"
)

// AdminRepo handles RBAC administration queries: permissions, roles, and
// user-role assignments.
type AdminRepo struct {
	pool *pgxpool.Pool
}

// NewAdminRepo constructs an AdminRepo backed by the given connection pool.
func NewAdminRepo(pool *pgxpool.Pool) *AdminRepo {
	return &AdminRepo{pool: pool}
}

// ─── Permission queries ───────────────────────────────────────────────────────

// ListPermissions returns a filtered, paginated list of permissions and the
// total count of matching rows.
func (r *AdminRepo) ListPermissions(ctx context.Context, params ListPermissionsParams) ([]Permission, int, error) {
	args := []interface{}{}
	where := "WHERE 1=1"

	if params.Module != "" {
		args = append(args, params.Module)
		where += fmt.Sprintf(" AND module = $%d", len(args))
	}
	if params.Active != nil {
		args = append(args, *params.Active)
		where += fmt.Sprintf(" AND is_active = $%d", len(args))
	}

	countQ := "SELECT COUNT(*) FROM permissions " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("admin: list permissions: count: %w", err)
	}

	limit := params.Limit
	if limit <= 0 {
		limit = 20
	} else if limit > 100 {
		limit = 100
	}

	args = append(args, limit, params.Offset)
	listQ := fmt.Sprintf(`
		SELECT id, code, name, description, module, is_active, created_at, updated_at
		FROM permissions
		%s
		ORDER BY module, code
		LIMIT $%d OFFSET $%d`, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("admin: list permissions: %w", err)
	}
	defer rows.Close()

	perms, err := scanPermissions(rows)
	if err != nil {
		return nil, 0, fmt.Errorf("admin: list permissions: %w", err)
	}
	return perms, total, nil
}

// GetPermissionsByIDs fetches permissions whose IDs are in the given slice.
// Returns an error if any ID is not a valid UUID string.
func (r *AdminRepo) GetPermissionsByIDs(ctx context.Context, ids []string) ([]Permission, error) {
	for _, id := range ids {
		if !isValidUUID(id) {
			return nil, fmt.Errorf("admin: get permissions by ids: invalid uuid: %q", id)
		}
	}

	const q = `
		SELECT id, code, name, description, module, is_active, created_at, updated_at
		FROM permissions
		WHERE id = ANY($1::uuid[])`

	rows, err := r.pool.Query(ctx, q, ids)
	if err != nil {
		return nil, fmt.Errorf("admin: get permissions by ids: %w", err)
	}
	defer rows.Close()

	perms, err := scanPermissions(rows)
	if err != nil {
		return nil, fmt.Errorf("admin: get permissions by ids: %w", err)
	}
	return perms, nil
}

// ─── Role queries ─────────────────────────────────────────────────────────────

// ListRoles returns a filtered, paginated list of roles visible to the given
// org (own org's roles + all system roles) plus the total matching count.
func (r *AdminRepo) ListRoles(ctx context.Context, params ListRolesParams) ([]Role, int, error) {
	args := []interface{}{params.OrgID} // $1
	where := "WHERE (org_id = $1 OR is_system = true)"

	if params.Search != "" {
		args = append(args, "%"+params.Search+"%")
		where += fmt.Sprintf(" AND name ILIKE $%d", len(args))
	}
	if params.ActiveOnly {
		where += " AND is_active = true"
	}

	countQ := "SELECT COUNT(*) FROM roles " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("admin: list roles: count: %w", err)
	}

	limit := params.Limit
	if limit <= 0 {
		limit = 20
	} else if limit > 100 {
		limit = 100
	}

	args = append(args, limit, params.Offset)
	listQ := fmt.Sprintf(`
		SELECT id, org_id, name, description, is_system, is_editable, is_active, created_at, updated_at
		FROM roles
		%s
		ORDER BY is_system DESC, name ASC
		LIMIT $%d OFFSET $%d`, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("admin: list roles: %w", err)
	}
	defer rows.Close()

	roles, err := scanRoles(rows)
	if err != nil {
		return nil, 0, fmt.Errorf("admin: list roles: %w", err)
	}
	return roles, total, nil
}

// GetRole fetches a single role by ID. Returns nil, nil when not found.
func (r *AdminRepo) GetRole(ctx context.Context, id string) (*Role, error) {
	const q = `
		SELECT id, org_id, name, description, is_system, is_editable, is_active, created_at, updated_at
		FROM roles
		WHERE id = $1`

	row := r.pool.QueryRow(ctx, q, id)
	role, err := scanRole(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("admin: get role: %w", err)
	}
	return role, nil
}

// CreateRole inserts a new org-scoped role and returns it.
func (r *AdminRepo) CreateRole(ctx context.Context, orgID, name, description string) (*Role, error) {
	const q = `
		INSERT INTO roles (id, org_id, name, description, is_system, is_editable, is_active, created_at, updated_at)
		VALUES (gen_random_uuid(), $1, $2, $3, false, true, true, now(), now())
		RETURNING id, org_id, name, description, is_system, is_editable, is_active, created_at, updated_at`

	row := r.pool.QueryRow(ctx, q, orgID, name, description)
	role, err := scanRole(row)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, fmt.Errorf("admin: create role: a role with that name already exists in this org")
		}
		return nil, fmt.Errorf("admin: create role: %w", err)
	}
	return role, nil
}

// UpdateRole modifies the mutable fields of a non-system, editable role.
// It uses SELECT FOR UPDATE inside a transaction to prevent races.
func (r *AdminRepo) UpdateRole(ctx context.Context, id string, req UpdateRoleRequest) (*Role, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("admin: update role: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var isSystem, isEditable bool
	if err := tx.QueryRow(ctx,
		`SELECT is_system, is_editable FROM roles WHERE id = $1 FOR UPDATE`, id,
	).Scan(&isSystem, &isEditable); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("admin: update role: role not found")
		}
		return nil, fmt.Errorf("admin: update role: lock: %w", err)
	}
	if isSystem {
		return nil, fmt.Errorf("admin: update role: cannot modify a system role")
	}
	if !isEditable {
		return nil, fmt.Errorf("admin: update role: role is not editable")
	}

	// Build SET clause for only non-nil fields.
	setClauses := []string{"updated_at = now()"}
	args := []interface{}{}

	if req.Name != nil {
		args = append(args, *req.Name)
		setClauses = append(setClauses, fmt.Sprintf("name = $%d", len(args)))
	}
	if req.Description != nil {
		args = append(args, *req.Description)
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", len(args)))
	}

	args = append(args, id)
	updateQ := fmt.Sprintf(`
		UPDATE roles SET %s WHERE id = $%d
		RETURNING id, org_id, name, description, is_system, is_editable, is_active, created_at, updated_at`,
		strings.Join(setClauses, ", "), len(args))

	role, err := scanRole(tx.QueryRow(ctx, updateQ, args...))
	if err != nil {
		return nil, fmt.Errorf("admin: update role: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("admin: update role: commit: %w", err)
	}
	return role, nil
}

// DisableRole sets is_active=false on an org-owned, non-system, editable role.
func (r *AdminRepo) DisableRole(ctx context.Context, id, orgID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("admin: disable role: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var isSystem, isEditable bool
	var roleOrgID pgtype.UUID
	if err := tx.QueryRow(ctx,
		`SELECT is_system, is_editable, org_id FROM roles WHERE id = $1 FOR UPDATE`, id,
	).Scan(&isSystem, &isEditable, &roleOrgID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("admin: disable role: role not found")
		}
		return fmt.Errorf("admin: disable role: lock: %w", err)
	}
	if isSystem {
		return fmt.Errorf("admin: disable role: cannot disable a system role")
	}
	if !isEditable {
		return fmt.Errorf("admin: disable role: role is not editable")
	}
	if !roleOrgID.Valid || uuidToString(roleOrgID) != orgID {
		return fmt.Errorf("admin: disable role: role does not belong to this org")
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roles SET is_active = false, updated_at = now() WHERE id = $1`, id,
	); err != nil {
		return fmt.Errorf("admin: disable role: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("admin: disable role: commit: %w", err)
	}
	return nil
}

// EnableRole sets is_active=true on an org-owned, non-system, editable role.
func (r *AdminRepo) EnableRole(ctx context.Context, id, orgID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("admin: enable role: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var isSystem, isEditable bool
	var roleOrgID pgtype.UUID
	if err := tx.QueryRow(ctx,
		`SELECT is_system, is_editable, org_id FROM roles WHERE id = $1 FOR UPDATE`, id,
	).Scan(&isSystem, &isEditable, &roleOrgID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("admin: enable role: role not found")
		}
		return fmt.Errorf("admin: enable role: lock: %w", err)
	}
	if isSystem {
		return fmt.Errorf("admin: enable role: cannot enable a system role")
	}
	if !isEditable {
		return fmt.Errorf("admin: enable role: role is not editable")
	}
	if !roleOrgID.Valid || uuidToString(roleOrgID) != orgID {
		return fmt.Errorf("admin: enable role: role does not belong to this org")
	}

	if _, err := tx.Exec(ctx,
		`UPDATE roles SET is_active = true, updated_at = now() WHERE id = $1`, id,
	); err != nil {
		return fmt.Errorf("admin: enable role: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("admin: enable role: commit: %w", err)
	}
	return nil
}

// GetRolePermissions returns all active permissions attached to roleID.
func (r *AdminRepo) GetRolePermissions(ctx context.Context, roleID string) ([]Permission, error) {
	const q = `
		SELECT p.id, p.code, p.name, p.description, p.module, p.is_active, p.created_at, p.updated_at
		FROM role_permissions rp
		JOIN permissions p ON p.id = rp.permission_id AND p.is_active = true
		WHERE rp.role_id = $1
		ORDER BY p.module, p.code`

	rows, err := r.pool.Query(ctx, q, roleID)
	if err != nil {
		return nil, fmt.Errorf("admin: get role permissions: %w", err)
	}
	defer rows.Close()

	perms, err := scanPermissions(rows)
	if err != nil {
		return nil, fmt.Errorf("admin: get role permissions: %w", err)
	}
	return perms, nil
}

// SetRolePermissions replaces the full permission set for a role inside a
// single transaction. The role must be non-system, editable, and belong to
// orgID.
func (r *AdminRepo) SetRolePermissions(ctx context.Context, roleID, orgID string, permissionIDs []string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("admin: set role permissions: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var isSystem, isEditable bool
	var roleOrgID pgtype.UUID
	if err := tx.QueryRow(ctx,
		`SELECT is_system, is_editable, org_id FROM roles WHERE id = $1 FOR UPDATE`, roleID,
	).Scan(&isSystem, &isEditable, &roleOrgID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("admin: set role permissions: role not found")
		}
		return fmt.Errorf("admin: set role permissions: lock: %w", err)
	}
	if isSystem {
		return fmt.Errorf("admin: set role permissions: cannot modify a system role")
	}
	if !isEditable {
		return fmt.Errorf("admin: set role permissions: role is not editable")
	}
	if !roleOrgID.Valid || uuidToString(roleOrgID) != orgID {
		return fmt.Errorf("admin: set role permissions: role does not belong to this org")
	}

	if _, err := tx.Exec(ctx, `DELETE FROM role_permissions WHERE role_id = $1`, roleID); err != nil {
		return fmt.Errorf("admin: set role permissions: delete: %w", err)
	}

	for _, pid := range permissionIDs {
		if _, err := tx.Exec(ctx,
			`INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2)`,
			roleID, pid,
		); err != nil {
			return fmt.Errorf("admin: set role permissions: insert %s: %w", pid, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("admin: set role permissions: commit: %w", err)
	}
	return nil
}

// ─── User queries ─────────────────────────────────────────────────────────────

// ListUsers returns a filtered, paginated list of the org's members (from
// org_members joined with users), each annotated with how many RBAC roles
// they currently hold within the org, plus the total matching count.
func (r *AdminRepo) ListUsers(ctx context.Context, params ListUsersParams) ([]UserSummary, int, error) {
	args := []interface{}{params.OrgID} // $1
	where := "WHERE m.org_id = $1 AND m.status <> 'removed'"

	if params.Search != "" {
		args = append(args, "%"+params.Search+"%")
		where += fmt.Sprintf(" AND (u.name ILIKE $%d OR u.email ILIKE $%d)", len(args), len(args))
	}

	countQ := "SELECT COUNT(*) FROM org_members m JOIN users u ON u.id = m.user_id " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("admin: list users: count: %w", err)
	}

	limit := params.Limit
	if limit <= 0 {
		limit = 20
	} else if limit > 100 {
		limit = 100
	}

	args = append(args, params.OrgID, limit, params.Offset)
	listQ := fmt.Sprintf(`
		SELECT u.id, m.id, u.name, u.email, u.avatar_url, m.created_at, m.status, u.status,
		       COALESCE(ur.role_names, '{}'::text[]) AS role_names
		FROM org_members m
		JOIN users u ON u.id = m.user_id
		LEFT JOIN (
			SELECT ur.user_id, array_agg(r.name ORDER BY r.name) AS role_names
			FROM user_roles ur
			JOIN roles r ON r.id = ur.role_id AND r.is_active = true
			WHERE ur.org_id = $%d
			GROUP BY ur.user_id
		) ur ON ur.user_id = u.id
		%s
		ORDER BY u.name ASC
		LIMIT $%d OFFSET $%d`, len(args)-2, where, len(args)-1, len(args))

	rows, err := r.pool.Query(ctx, listQ, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("admin: list users: %w", err)
	}
	defer rows.Close()

	var users []UserSummary
	for rows.Next() {
		var u UserSummary
		if err := rows.Scan(&u.ID, &u.MemberID, &u.Name, &u.Email, &u.AvatarURL, &u.JoinedAt, &u.Status, &u.AccountStatus, &u.RoleNames); err != nil {
			return nil, 0, fmt.Errorf("admin: list users: scan: %w", err)
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("admin: list users: rows: %w", err)
	}
	return users, total, nil
}

// ─── User-role queries ────────────────────────────────────────────────────────

// GetUserRoles returns all active roles held by userID within orgID.
func (r *AdminRepo) GetUserRoles(ctx context.Context, userID, orgID string) ([]Role, error) {
	const q = `
		SELECT r.id, r.org_id, r.name, r.description, r.is_system, r.is_editable, r.is_active, r.created_at, r.updated_at
		FROM user_roles ur
		JOIN roles r ON r.id = ur.role_id AND r.is_active = true
		WHERE ur.user_id = $1 AND ur.org_id = $2`

	rows, err := r.pool.Query(ctx, q, userID, orgID)
	if err != nil {
		return nil, fmt.Errorf("admin: get user roles: %w", err)
	}
	defer rows.Close()

	roles, err := scanRoles(rows)
	if err != nil {
		return nil, fmt.Errorf("admin: get user roles: %w", err)
	}
	return roles, nil
}

// rowQuerier is the subset of *pgxpool.Pool and pgx.Tx that
// requireOrgMembership needs, so the same check can run inside or outside an
// existing transaction.
type rowQuerier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// requireOrgMembership returns a "not found"-style error unless userID is an
// active member of orgID. Every admin write that scopes a mutation to a
// tenant (assigning a role, granting a permission override, locking an
// account) must call this before writing — otherwise a tenant admin could
// target any platform user by ID, not just members of their own org, since
// the underlying UPDATE/INSERT has no org-membership join of its own.
func requireOrgMembership(ctx context.Context, q rowQuerier, userID, orgID string) error {
	var isMember bool
	if err := q.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM org_members WHERE user_id = $1 AND org_id = $2 AND status = 'active')`,
		userID, orgID,
	).Scan(&isMember); err != nil {
		return fmt.Errorf("check org membership: %w", err)
	}
	if !isMember {
		return fmt.Errorf("user not found in this organization")
	}
	return nil
}

// AssignRole grants roleID to userID within orgID. The role must be a
// system role or belong to orgID. Duplicate assignments are silently ignored.
//
// userID must already be an active member of orgID: without this check a
// tenant admin could write a user_roles row — scoped to their own org — for
// any platform user, including one who has never belonged to that org.
func (r *AdminRepo) AssignRole(ctx context.Context, userID, roleID, orgID string) error {
	if err := requireOrgMembership(ctx, r.pool, userID, orgID); err != nil {
		return fmt.Errorf("admin: assign role: %w", err)
	}

	// Verify the role is accessible to this org.
	var isSystem bool
	var roleOrgID pgtype.UUID
	if err := r.pool.QueryRow(ctx,
		`SELECT is_system, org_id FROM roles WHERE id = $1 AND is_active = true`, roleID,
	).Scan(&isSystem, &roleOrgID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("admin: assign role: role not found or inactive")
		}
		return fmt.Errorf("admin: assign role: lookup: %w", err)
	}

	if !isSystem {
		if !roleOrgID.Valid || uuidToString(roleOrgID) != orgID {
			return fmt.Errorf("admin: assign role: role is not accessible to this org")
		}
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, org_id) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
		userID, roleID, orgID,
	)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return fmt.Errorf("admin: assign role: role already assigned to this user")
		}
		return fmt.Errorf("admin: assign role: %w", err)
	}
	return nil
}

// RevokeRole removes roleID from userID within orgID. Returns a descriptive
// error when the assignment does not exist.
func (r *AdminRepo) RevokeRole(ctx context.Context, userID, roleID, orgID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2 AND org_id = $3`,
		userID, roleID, orgID,
	)
	if err != nil {
		return fmt.Errorf("admin: revoke role: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("admin: revoke role: role was not assigned to this user")
	}
	return nil
}

// ─── User-permission-override queries ──────────────────────────────────────────

// GetUserPermissionOverrides returns permissions granted directly to userID
// within orgID, bypassing roles.
func (r *AdminRepo) GetUserPermissionOverrides(ctx context.Context, userID, orgID string) ([]Permission, error) {
	const q = `
		SELECT p.id, p.code, p.name, p.description, p.module, p.is_active, p.created_at, p.updated_at
		FROM user_permission_overrides upo
		JOIN permissions p ON p.id = upo.permission_id AND p.is_active = true
		WHERE upo.user_id = $1 AND upo.org_id = $2
		ORDER BY p.module, p.code`

	rows, err := r.pool.Query(ctx, q, userID, orgID)
	if err != nil {
		return nil, fmt.Errorf("admin: get user permission overrides: %w", err)
	}
	defer rows.Close()

	perms, err := scanPermissions(rows)
	if err != nil {
		return nil, fmt.Errorf("admin: get user permission overrides: %w", err)
	}
	return perms, nil
}

// GrantUserPermission grants permissionID directly to userID within orgID,
// bypassing roles. Duplicate grants are silently ignored.
//
// userID must already be an active member of orgID — see requireOrgMembership.
func (r *AdminRepo) GrantUserPermission(ctx context.Context, userID, orgID, permissionID, grantedBy string) error {
	if err := requireOrgMembership(ctx, r.pool, userID, orgID); err != nil {
		return fmt.Errorf("admin: grant user permission: %w", err)
	}

	var isActive bool
	if err := r.pool.QueryRow(ctx,
		`SELECT is_active FROM permissions WHERE id = $1`, permissionID,
	).Scan(&isActive); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("admin: grant user permission: permission not found")
		}
		return fmt.Errorf("admin: grant user permission: lookup: %w", err)
	}
	if !isActive {
		return fmt.Errorf("admin: grant user permission: permission is not active")
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_permission_overrides (user_id, org_id, permission_id, granted_by)
		 VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
		userID, orgID, permissionID, grantedBy,
	)
	if err != nil {
		return fmt.Errorf("admin: grant user permission: %w", err)
	}
	return nil
}

// RevokeUserPermission removes a direct permission grant from userID within
// orgID. Returns a descriptive error when the grant does not exist.
func (r *AdminRepo) RevokeUserPermission(ctx context.Context, userID, orgID, permissionID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM user_permission_overrides WHERE user_id = $1 AND org_id = $2 AND permission_id = $3`,
		userID, orgID, permissionID,
	)
	if err != nil {
		return fmt.Errorf("admin: revoke user permission: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("admin: revoke user permission: permission was not granted to this user")
	}
	return nil
}

// ─── scan helpers ─────────────────────────────────────────────────────────────

func scanPermissions(rows pgx.Rows) ([]Permission, error) {
	var perms []Permission
	for rows.Next() {
		var p Permission
		if err := rows.Scan(
			&p.ID, &p.Code, &p.Name, &p.Description,
			&p.Module, &p.IsActive, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan permission: %w", err)
		}
		perms = append(perms, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if perms == nil {
		perms = []Permission{}
	}
	return perms, nil
}

func scanRoles(rows pgx.Rows) ([]Role, error) {
	var roles []Role
	for rows.Next() {
		r, err := scanRoleColumns(rows)
		if err != nil {
			return nil, err
		}
		roles = append(roles, *r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if roles == nil {
		roles = []Role{}
	}
	return roles, nil
}

// scanRole scans a single role from a pgx.Row (QueryRow result).
func scanRole(row pgx.Row) (*Role, error) {
	var role Role
	var orgID pgtype.UUID
	if err := row.Scan(
		&role.ID, &orgID, &role.Name, &role.Description,
		&role.IsSystem, &role.IsEditable, &role.IsActive,
		&role.CreatedAt, &role.UpdatedAt,
	); err != nil {
		return nil, err
	}
	if orgID.Valid {
		s := uuidToString(orgID)
		role.OrgID = &s
	}
	return &role, nil
}

// scanRoleColumns scans a role from a row in a multi-row result set.
func scanRoleColumns(rows pgx.Rows) (*Role, error) {
	var role Role
	var orgID pgtype.UUID
	if err := rows.Scan(
		&role.ID, &orgID, &role.Name, &role.Description,
		&role.IsSystem, &role.IsEditable, &role.IsActive,
		&role.CreatedAt, &role.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("scan role: %w", err)
	}
	if orgID.Valid {
		s := uuidToString(orgID)
		role.OrgID = &s
	}
	return &role, nil
}

// isValidUUID returns true for strings matching the standard UUID format.
func isValidUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		switch i {
		case 8, 13, 18, 23:
			if c != '-' {
				return false
			}
		default:
			if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
				return false
			}
		}
	}
	return true
}

// ─── Account status ───────────────────────────────────────────────────────────

// SetUserStatus locks or restores a platform account, returning the status it
// held before the change.
//
// The session_version bump is what makes a lock take effect immediately: every
// access token the user holds asserts the old version, so RequireAuth rejects
// them on their next request rather than at token expiry. Sign-in and refresh
// read status directly and refuse a locked account, so no new token can be
// minted either. Both writes are one statement so an account can never be left
// locked with live sessions.
//
// reason is stored only for a lock; restoring to active clears it.
//
// orgID must be the caller's tenant, and userID must already be an active
// member of it — see requireOrgMembership. Without this, a tenant admin
// could suspend or restore any platform account by ID, including one that
// has never belonged to their org.
func (r *AdminRepo) SetUserStatus(ctx context.Context, userID, orgID, status, reason string) (string, error) {
	return r.setUserStatus(ctx, userID, status, reason, func(tx pgx.Tx) error {
		if err := requireOrgMembership(ctx, tx, userID, orgID); err != nil {
			return fmt.Errorf("admin: set user status: %w", err)
		}
		return nil
	})
}

// SetUserStatusUnscoped locks or restores a platform account with no
// org-membership check. Only for genuinely tenant-less callers acting on
// their own account — currently self-service account deletion
// (internal/privacy.Service.DeleteAccount), where userID is always the
// authenticated caller, never an admin-supplied target. Any admin-triggered
// path must go through SetUserStatus instead, which enforces that the
// target belongs to the caller's org.
func (r *AdminRepo) SetUserStatusUnscoped(ctx context.Context, userID, status, reason string) (string, error) {
	return r.setUserStatus(ctx, userID, status, reason, nil)
}

// setUserStatus holds the shared read-then-write transaction for
// SetUserStatus and SetUserStatusUnscoped. guard, when non-nil, runs inside
// the transaction before the status is read/written and can abort the
// whole operation by returning an error.
func (r *AdminRepo) setUserStatus(ctx context.Context, userID, status, reason string, guard func(pgx.Tx) error) (previous string, err error) {
	if status == "active" {
		reason = ""
	}
	var reasonArg *string
	if reason != "" {
		reasonArg = &reason
	}

	// Read-then-write inside one transaction, rather than a single statement that
	// leans on PostgreSQL's rule that SET right-hand sides see pre-update values.
	// The one-liner works, but "did session_version go up?" then depends on
	// evaluation-order trivia; here it is answerable by reading the code. The
	// SELECT ... FOR UPDATE serialises two admins acting on the same account.
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("admin: set user status: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	if guard != nil {
		if err = guard(tx); err != nil {
			return "", err
		}
	}

	if err = tx.QueryRow(ctx,
		`SELECT status FROM users WHERE id = $1 FOR UPDATE`, userID,
	).Scan(&previous); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", fmt.Errorf("admin: set user status: user not found")
		}
		return "", fmt.Errorf("admin: set user status: lookup: %w", err)
	}

	// session_version only moves on a real change, so re-applying the status a
	// user already has does not sign them out for nothing.
	bump := 0
	if previous != status {
		bump = 1
	}

	if _, err = tx.Exec(ctx,
		`UPDATE users
		 SET status = $2,
		     status_reason = $3,
		     status_changed_at = now(),
		     updated_at = now(),
		     session_version = session_version + $4
		 WHERE id = $1`,
		userID, status, reasonArg, bump,
	); err != nil {
		return "", fmt.Errorf("admin: set user status: update: %w", err)
	}

	if err = tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("admin: set user status: commit: %w", err)
	}
	return previous, nil
}

package authz

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
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
// tenant (own tenant's roles + all system roles) plus the total matching count.
func (r *AdminRepo) ListRoles(ctx context.Context, params ListRolesParams) ([]Role, int, error) {
	args := []interface{}{params.TenantID} // $1
	where := "WHERE (tenant_id = $1 OR is_system = true)"

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
		SELECT id, tenant_id, name, description, is_system, is_editable, is_active, created_at, updated_at
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
		SELECT id, tenant_id, name, description, is_system, is_editable, is_active, created_at, updated_at
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

// CreateRole inserts a new tenant-scoped role and returns it.
func (r *AdminRepo) CreateRole(ctx context.Context, tenantID, name, description string) (*Role, error) {
	const q = `
		INSERT INTO roles (id, tenant_id, name, description, is_system, is_editable, is_active, created_at, updated_at)
		VALUES (gen_random_uuid(), $1, $2, $3, false, true, true, now(), now())
		RETURNING id, tenant_id, name, description, is_system, is_editable, is_active, created_at, updated_at`

	row := r.pool.QueryRow(ctx, q, tenantID, name, description)
	role, err := scanRole(row)
	if err != nil {
		if isUniqueViolation(err) {
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
		RETURNING id, tenant_id, name, description, is_system, is_editable, is_active, created_at, updated_at`,
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

// DisableRole sets is_active=false on a tenant-owned, non-system, editable role.
func (r *AdminRepo) DisableRole(ctx context.Context, id, tenantID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("admin: disable role: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var isSystem, isEditable bool
	var roleTenantID pgtype.UUID
	if err := tx.QueryRow(ctx,
		`SELECT is_system, is_editable, tenant_id FROM roles WHERE id = $1 FOR UPDATE`, id,
	).Scan(&isSystem, &isEditable, &roleTenantID); err != nil {
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
	if !roleTenantID.Valid || uuidToString(roleTenantID) != tenantID {
		return fmt.Errorf("admin: disable role: role does not belong to this tenant")
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
// tenantID.
func (r *AdminRepo) SetRolePermissions(ctx context.Context, roleID, tenantID string, permissionIDs []string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("admin: set role permissions: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var isSystem, isEditable bool
	var roleTenantID pgtype.UUID
	if err := tx.QueryRow(ctx,
		`SELECT is_system, is_editable, tenant_id FROM roles WHERE id = $1 FOR UPDATE`, roleID,
	).Scan(&isSystem, &isEditable, &roleTenantID); err != nil {
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
	if !roleTenantID.Valid || uuidToString(roleTenantID) != tenantID {
		return fmt.Errorf("admin: set role permissions: role does not belong to this tenant")
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

// ─── User-role queries ────────────────────────────────────────────────────────

// GetUserRoles returns all active roles held by userID within tenantID.
func (r *AdminRepo) GetUserRoles(ctx context.Context, userID, tenantID string) ([]Role, error) {
	const q = `
		SELECT r.id, r.tenant_id, r.name, r.description, r.is_system, r.is_editable, r.is_active, r.created_at, r.updated_at
		FROM user_roles ur
		JOIN roles r ON r.id = ur.role_id AND r.is_active = true
		WHERE ur.user_id = $1 AND ur.tenant_id = $2`

	rows, err := r.pool.Query(ctx, q, userID, tenantID)
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

// AssignRole grants roleID to userID within tenantID. The role must be a
// system role or belong to tenantID. Duplicate assignments are silently ignored.
func (r *AdminRepo) AssignRole(ctx context.Context, userID, roleID, tenantID string) error {
	// Verify the role is accessible to this tenant.
	var isSystem bool
	var roleTenantID pgtype.UUID
	if err := r.pool.QueryRow(ctx,
		`SELECT is_system, tenant_id FROM roles WHERE id = $1 AND is_active = true`, roleID,
	).Scan(&isSystem, &roleTenantID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("admin: assign role: role not found or inactive")
		}
		return fmt.Errorf("admin: assign role: lookup: %w", err)
	}

	if !isSystem {
		if !roleTenantID.Valid || uuidToString(roleTenantID) != tenantID {
			return fmt.Errorf("admin: assign role: role is not accessible to this tenant")
		}
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_roles (user_id, role_id, tenant_id) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
		userID, roleID, tenantID,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return fmt.Errorf("admin: assign role: role already assigned to this user")
		}
		return fmt.Errorf("admin: assign role: %w", err)
	}
	return nil
}

// RevokeRole removes roleID from userID within tenantID. Returns a descriptive
// error when the assignment does not exist.
func (r *AdminRepo) RevokeRole(ctx context.Context, userID, roleID, tenantID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2 AND tenant_id = $3`,
		userID, roleID, tenantID,
	)
	if err != nil {
		return fmt.Errorf("admin: revoke role: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("admin: revoke role: role was not assigned to this user")
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
	var tenantID pgtype.UUID
	if err := row.Scan(
		&role.ID, &tenantID, &role.Name, &role.Description,
		&role.IsSystem, &role.IsEditable, &role.IsActive,
		&role.CreatedAt, &role.UpdatedAt,
	); err != nil {
		return nil, err
	}
	if tenantID.Valid {
		s := uuidToString(tenantID)
		role.TenantID = &s
	}
	return &role, nil
}

// scanRoleColumns scans a role from a row in a multi-row result set.
func scanRoleColumns(rows pgx.Rows) (*Role, error) {
	var role Role
	var tenantID pgtype.UUID
	if err := rows.Scan(
		&role.ID, &tenantID, &role.Name, &role.Description,
		&role.IsSystem, &role.IsEditable, &role.IsActive,
		&role.CreatedAt, &role.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("scan role: %w", err)
	}
	if tenantID.Valid {
		s := uuidToString(tenantID)
		role.TenantID = &s
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

// isUniqueViolation reports whether err is a PostgreSQL unique-constraint
// violation (SQLSTATE 23505).
func isUniqueViolation(err error) bool {
	return strings.Contains(err.Error(), "23505")
}

package authz

import (
	"encoding/json"
	"time"
)

// Permission is a fine-grained capability code stored in the permissions table.
type Permission struct {
	ID          string    `json:"id"`
	Code        string    `json:"code"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Module      string    `json:"module"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Role is a named set of permissions. tenant_id NULL means a system-wide role.
type Role struct {
	ID          string    `json:"id"`
	TenantID    *string   `json:"tenant_id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	IsSystem    bool      `json:"is_system"`
	IsEditable  bool      `json:"is_editable"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// AuditEntry is a single row from the audit_logs table.
type AuditEntry struct {
	ID         int64           `json:"id"`
	TenantID   *string         `json:"tenant_id"`
	ActorID    *string         `json:"actor_id"`
	Action     string          `json:"action"`
	EntityType string          `json:"entity_type"`
	EntityID   string          `json:"entity_id"`
	Diff       json.RawMessage `json:"diff"`
	CreatedAt  time.Time       `json:"created_at"`
}

// UserRoleAssignment is a row from user_roles, scoped to a tenant.
type UserRoleAssignment struct {
	UserID   string `json:"user_id"`
	TenantID string `json:"tenant_id"`
}

// AuditDiff captures the before/after state, stored as audit_logs.before_state/after_state.
type AuditDiff struct {
	Before any `json:"before,omitempty"`
	After  any `json:"after,omitempty"`
}

// CreateRoleRequest is the body for POST /roles.
type CreateRoleRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// UpdateRoleRequest is the body for PATCH /roles/{id}.
type UpdateRoleRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
}

// SetPermissionsRequest replaces all permissions on a role.
type SetPermissionsRequest struct {
	PermissionIDs []string `json:"permission_ids"`
}

// AssignRoleRequest assigns a role to a user within the caller's tenant.
type AssignRoleRequest struct {
	RoleID string `json:"role_id"`
}

// GrantPermissionRequest grants a permission directly to a user, bypassing roles.
type GrantPermissionRequest struct {
	PermissionID string `json:"permission_id"`
}

// SetUserStatusRequest locks or restores a platform account.
// Status is one of "active", "suspended", "deactivated" (users.status).
type SetUserStatusRequest struct {
	Status string `json:"status"`
	Reason string `json:"reason"`
}

// ListPermissionsParams filters the permissions list.
type ListPermissionsParams struct {
	Module string
	Active *bool
	Limit  int
	Offset int
}

// ListRolesParams filters the roles list.
type ListRolesParams struct {
	TenantID      string
	IncludeSystem bool
	Search        string
	ActiveOnly    bool
	Limit         int
	Offset        int
}

// ListUsersParams filters the tenant's user list.
type ListUsersParams struct {
	TenantID string
	Search   string
	Limit    int
	Offset   int
}

// UserSummary is a row in the tenant's user list, joined from org_members +
// users, with the names of RBAC roles currently assigned within the tenant.
// MemberID is the org_members.id primary key — required for lifecycle
// actions (suspend/activate/remove) which operate on the membership row,
// not the user row.
type UserSummary struct {
	ID        string    `json:"id"`
	MemberID  string    `json:"member_id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	AvatarURL *string   `json:"avatar_url"`
	RoleNames []string  `json:"role_names"`
	// Status is the caller's org-membership status (org_members.status) — scoped
	// to this organization. AccountStatus is the platform account status
	// (users.status), which governs whether they can sign in at all. The two are
	// independent: an active member of this org may still hold a locked account.
	Status        string    `json:"status"`
	AccountStatus string    `json:"account_status"`
	JoinedAt      time.Time `json:"joined_at"`
}

// ListAuditParams filters the audit_logs list.
type ListAuditParams struct {
	TenantID   string
	EntityType string
	EntityID   string
	Limit      int
	Offset     int
}

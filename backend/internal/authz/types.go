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

// AuditEntry is a single row from the audit_log table.
type AuditEntry struct {
	ID         string          `json:"id"`
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

// AuditDiff captures the before/after state for an audit_log diff column.
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

// ListAuditParams filters the audit_log list.
type ListAuditParams struct {
	TenantID   string
	EntityType string
	EntityID   string
	Limit      int
	Offset     int
}

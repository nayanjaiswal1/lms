package authz

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/session"
)

// AdminService wraps AdminRepo with audit logging and cache invalidation.
// Every mutation writes an audit entry and busts the permission cache for
// affected users before returning.
type AdminService struct {
	adminRepo *AdminRepo
	auditRepo *AuditRepo
	svc       *Service
	sessions  *session.Cache
}

// NewAdminService constructs an AdminService. sessions is used to drop a user's
// cached session_version the moment their account status changes, so a lock
// takes effect on the next request instead of at the end of the cache TTL.
func NewAdminService(adminRepo *AdminRepo, auditRepo *AuditRepo, svc *Service, sessions *session.Cache) *AdminService {
	return &AdminService{adminRepo: adminRepo, auditRepo: auditRepo, svc: svc, sessions: sessions}
}

// ─── Role management ──────────────────────────────────────────────────────────

// CreateRole creates a tenant-scoped role, writes an audit entry, and returns
// the new role.
func (s *AdminService) CreateRole(ctx context.Context, actorID, tenantID string, req CreateRoleRequest) (*Role, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("admin svc: create role: name is required")
	}

	role, err := s.adminRepo.CreateRole(ctx, tenantID, req.Name, req.Description)
	if err != nil {
		return nil, fmt.Errorf("admin svc: create role: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "role.create", "role", role.ID, &AuditDiff{After: role})
	return role, nil
}

// UpdateRole modifies a tenant-owned role, writes an audit diff, and
// invalidates the permission cache for every user holding the role.
func (s *AdminService) UpdateRole(ctx context.Context, actorID, tenantID, roleID string, req UpdateRoleRequest) (*Role, error) {
	before, err := s.adminRepo.GetRole(ctx, roleID)
	if err != nil {
		return nil, fmt.Errorf("admin svc: update role: %w", err)
	}
	if before == nil {
		return nil, fmt.Errorf("admin svc: update role: role not found")
	}
	if before.IsSystem {
		return nil, fmt.Errorf("admin svc: update role: cannot modify a system role")
	}
	if before.TenantID == nil || *before.TenantID != tenantID {
		return nil, fmt.Errorf("admin svc: update role: role does not belong to this tenant")
	}

	after, err := s.adminRepo.UpdateRole(ctx, roleID, req)
	if err != nil {
		return nil, fmt.Errorf("admin svc: update role: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "role.update", "role", roleID, &AuditDiff{Before: before, After: after})
	_ = s.svc.InvalidateForRoleChange(ctx, roleID)
	return after, nil
}

// DisableRole soft-deletes a role (sets is_active=false), writes an audit
// entry, and invalidates the permission cache for affected users.
func (s *AdminService) DisableRole(ctx context.Context, actorID, tenantID, roleID string) error {
	before, err := s.adminRepo.GetRole(ctx, roleID)
	if err != nil {
		return fmt.Errorf("admin svc: disable role: %w", err)
	}
	if before == nil {
		return fmt.Errorf("admin svc: disable role: role not found")
	}
	if before.IsSystem {
		return fmt.Errorf("admin svc: disable role: cannot disable a system role")
	}
	if before.TenantID == nil || *before.TenantID != tenantID {
		return fmt.Errorf("admin svc: disable role: role does not belong to this tenant")
	}

	if err := s.adminRepo.DisableRole(ctx, roleID, tenantID); err != nil {
		return fmt.Errorf("admin svc: disable role: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "role.disable", "role", roleID, &AuditDiff{Before: before})
	_ = s.svc.InvalidateForRoleChange(ctx, roleID)
	return nil
}

// EnableRole re-activates a previously disabled role, writes an audit entry,
// and invalidates the permission cache for affected users.
func (s *AdminService) EnableRole(ctx context.Context, actorID, tenantID, roleID string) error {
	before, err := s.adminRepo.GetRole(ctx, roleID)
	if err != nil {
		return fmt.Errorf("admin svc: enable role: %w", err)
	}
	if before == nil {
		return fmt.Errorf("admin svc: enable role: role not found")
	}
	if before.IsSystem {
		return fmt.Errorf("admin svc: enable role: cannot enable a system role")
	}
	if before.TenantID == nil || *before.TenantID != tenantID {
		return fmt.Errorf("admin svc: enable role: role does not belong to this tenant")
	}

	if err := s.adminRepo.EnableRole(ctx, roleID, tenantID); err != nil {
		return fmt.Errorf("admin svc: enable role: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "role.enable", "role", roleID, &AuditDiff{Before: before})
	_ = s.svc.InvalidateForRoleChange(ctx, roleID)
	return nil
}

// SetRolePermissions replaces the full permission set for a role in one
// atomic operation, writes an audit diff, and invalidates affected caches.
func (s *AdminService) SetRolePermissions(ctx context.Context, actorID, tenantID, roleID string, req SetPermissionsRequest) ([]Permission, error) {
	role, err := s.adminRepo.GetRole(ctx, roleID)
	if err != nil {
		return nil, fmt.Errorf("admin svc: set role permissions: %w", err)
	}
	if role == nil {
		return nil, fmt.Errorf("admin svc: set role permissions: role not found")
	}
	if role.IsSystem {
		return nil, fmt.Errorf("admin svc: set role permissions: cannot modify a system role")
	}
	if role.TenantID == nil || *role.TenantID != tenantID {
		return nil, fmt.Errorf("admin svc: set role permissions: role does not belong to this tenant")
	}

	before, err := s.adminRepo.GetRolePermissions(ctx, roleID)
	if err != nil {
		return nil, fmt.Errorf("admin svc: set role permissions: get before: %w", err)
	}

	if err := s.adminRepo.SetRolePermissions(ctx, roleID, tenantID, req.PermissionIDs); err != nil {
		return nil, fmt.Errorf("admin svc: set role permissions: %w", err)
	}

	after, err := s.adminRepo.GetRolePermissions(ctx, roleID)
	if err != nil {
		return nil, fmt.Errorf("admin svc: set role permissions: get after: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "role.permissions.set", "role", roleID,
		&AuditDiff{Before: before, After: after})
	_ = s.svc.InvalidateForRoleChange(ctx, roleID)
	return after, nil
}

// ─── User-role management ─────────────────────────────────────────────────────

// AssignRole grants a role to a user within the caller's tenant, audits the
// action, and invalidates the user's permission cache.
func (s *AdminService) AssignRole(ctx context.Context, actorID, tenantID, targetUserID, roleID string) error {
	if err := s.adminRepo.AssignRole(ctx, targetUserID, roleID, tenantID); err != nil {
		return fmt.Errorf("admin svc: assign role: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "user.role.assign", "user_role",
		targetUserID+"/"+roleID, &AuditDiff{After: map[string]string{
			"user_id":   targetUserID,
			"role_id":   roleID,
			"tenant_id": tenantID,
		}})
	_ = s.svc.InvalidateUser(ctx, targetUserID, tenantID)
	return nil
}

// RevokeRole removes a role from a user, audits the action, and invalidates
// the user's permission cache.
func (s *AdminService) RevokeRole(ctx context.Context, actorID, tenantID, targetUserID, roleID string) error {
	if err := s.adminRepo.RevokeRole(ctx, targetUserID, roleID, tenantID); err != nil {
		return fmt.Errorf("admin svc: revoke role: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "user.role.revoke", "user_role",
		targetUserID+"/"+roleID, &AuditDiff{Before: map[string]string{
			"user_id":   targetUserID,
			"role_id":   roleID,
			"tenant_id": tenantID,
		}})
	_ = s.svc.InvalidateUser(ctx, targetUserID, tenantID)
	return nil
}

// ─── User-permission-override management ──────────────────────────────────────

// GrantUserPermission grants a permission directly to a user within the
// caller's tenant, bypassing roles, audits the action, and invalidates the
// user's permission cache.
func (s *AdminService) GrantUserPermission(ctx context.Context, actorID, tenantID, targetUserID, permissionID string) error {
	if err := s.adminRepo.GrantUserPermission(ctx, targetUserID, tenantID, permissionID, actorID); err != nil {
		return fmt.Errorf("admin svc: grant user permission: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "user.permission.grant", "user_permission",
		targetUserID+"/"+permissionID, &AuditDiff{After: map[string]string{
			"user_id":       targetUserID,
			"permission_id": permissionID,
			"tenant_id":     tenantID,
		}})
	_ = s.svc.InvalidateUser(ctx, targetUserID, tenantID)
	return nil
}

// RevokeUserPermission removes a direct permission grant from a user, audits
// the action, and invalidates the user's permission cache.
func (s *AdminService) RevokeUserPermission(ctx context.Context, actorID, tenantID, targetUserID, permissionID string) error {
	if err := s.adminRepo.RevokeUserPermission(ctx, targetUserID, tenantID, permissionID); err != nil {
		return fmt.Errorf("admin svc: revoke user permission: %w", err)
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "user.permission.revoke", "user_permission",
		targetUserID+"/"+permissionID, &AuditDiff{Before: map[string]string{
			"user_id":       targetUserID,
			"permission_id": permissionID,
			"tenant_id":     tenantID,
		}})
	_ = s.svc.InvalidateUser(ctx, targetUserID, tenantID)
	return nil
}

// ─── Account status ───────────────────────────────────────────────────────────

// ValidUserStatus reports whether s is one of the statuses users.status accepts.
func ValidUserStatus(s string) bool {
	return s == "active" || s == "suspended" || s == "deactivated"
}

// SetUserStatus locks or restores a platform account, audits the change, and
// drops the caller's cached session_version so live tokens are rejected on the
// next request rather than at the end of the cache TTL.
//
// Refuses to act on the actor's own account: an admin locking themselves out
// mid-session is never the intent, and undoing it needs another admin.
func (s *AdminService) SetUserStatus(ctx context.Context, actorID, tenantID, targetUserID, status, reason string) error {
	if !ValidUserStatus(status) {
		return fmt.Errorf("admin svc: set user status: invalid status %q", status)
	}
	if actorID == targetUserID {
		return fmt.Errorf("forbidden: you cannot change your own account status")
	}

	previous, err := s.adminRepo.SetUserStatus(ctx, targetUserID, status, reason)
	if err != nil {
		return fmt.Errorf("admin svc: set user status: %w", err)
	}
	if previous == status {
		return nil // no-op; nothing to audit or invalidate
	}

	_ = s.auditRepo.Write(ctx, tenantID, actorID, "user.status.set", "user",
		targetUserID, &AuditDiff{
			Before: map[string]string{"status": previous},
			After:  map[string]string{"status": status, "reason": reason},
		})

	if s.sessions != nil {
		s.sessions.InvalidateVersionCache(ctx, targetUserID)
	}
	_ = s.svc.InvalidateUser(ctx, targetUserID, tenantID)
	return nil
}

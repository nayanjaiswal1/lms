package authz

import (
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

// ─── Permissions ──────────────────────────────────────────────────────────────

// HandleListPermissions returns a paginated list of all platform permissions.
//
// GET /api/admin/rbac/permissions?module=courses&active=true&limit=20&offset=0
func (h *Handler) HandleListPermissions(w http.ResponseWriter, r *http.Request) {
	params := ListPermissionsParams{
		Module: h.queryString(r, "module"),
		Active: h.queryBoolPtr(r, "active"),
		Limit:  h.queryInt(r, "limit", 50),
		Offset: h.queryInt(r, "offset", 0),
	}

	perms, total, err := h.adminRepo.ListPermissions(r.Context(), params)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to list permissions.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"permissions": perms,
		"total":       total,
	})
}

// ─── Roles ────────────────────────────────────────────────────────────────────

// HandleListRoles returns roles visible to the caller's tenant (own roles +
// all system roles).
//
// GET /api/admin/rbac/roles?search=admin&active=true&limit=20&offset=0
func (h *Handler) HandleListRoles(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	params := ListRolesParams{
		TenantID:      claims.OrgID,
		IncludeSystem: true,
		Search:        h.queryString(r, "search"),
		ActiveOnly:    h.queryString(r, "active") == "true",
		Limit:         h.queryInt(r, "limit", 20),
		Offset:        h.queryInt(r, "offset", 0),
	}

	roles, total, err := h.adminRepo.ListRoles(r.Context(), params)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to list roles.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"roles": roles,
		"total": total,
	})
}

// HandleCreateRole creates a new tenant-owned role.
//
// POST /api/admin/rbac/roles
func (h *Handler) HandleCreateRole(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	var req CreateRoleRequest
	if err := h.decodeJSON(r, &req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	role, err := h.adminSvc.CreateRole(r.Context(), claims.UserID, claims.OrgID, req)
	if err != nil {
		if isValidationError(err) {
			httputil.WriteError(w, http.StatusBadRequest, err.Error())
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to create role.")
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]any{"role": role})
}

// HandleGetRole returns a single role by ID, provided it is accessible to the
// caller's tenant (system role or owned by the tenant).
//
// GET /api/admin/rbac/roles/{roleID}
func (h *Handler) HandleGetRole(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	roleID := chi.URLParam(r, "roleID")
	role, err := h.adminRepo.GetRole(r.Context(), roleID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch role.")
		return
	}
	if role == nil || !roleAccessible(role, claims.OrgID) {
		// Identical 404 regardless of whether the role exists — prevents probing.
		httputil.WriteError(w, http.StatusNotFound, "Role not found.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"role": role})
}

// HandleUpdateRole updates the name/description of a tenant-owned role.
//
// PUT /api/admin/rbac/roles/{roleID}
func (h *Handler) HandleUpdateRole(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	roleID := chi.URLParam(r, "roleID")
	var req UpdateRoleRequest
	if err := h.decodeJSON(r, &req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	role, err := h.adminSvc.UpdateRole(r.Context(), claims.UserID, claims.OrgID, roleID, req)
	if err != nil {
		switch {
		case isNotFound(err):
			httputil.WriteError(w, http.StatusNotFound, "Role not found.")
		case isForbidden(err):
			httputil.WriteError(w, http.StatusForbidden, err.Error())
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to update role.")
		}
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"role": role})
}

// HandleDisableRole soft-deletes a role by setting is_active=false.
//
// DELETE /api/admin/rbac/roles/{roleID}
func (h *Handler) HandleDisableRole(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	roleID := chi.URLParam(r, "roleID")
	if err := h.adminSvc.DisableRole(r.Context(), claims.UserID, claims.OrgID, roleID); err != nil {
		switch {
		case isNotFound(err):
			httputil.WriteError(w, http.StatusNotFound, "Role not found.")
		case isForbidden(err):
			httputil.WriteError(w, http.StatusForbidden, err.Error())
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to disable role.")
		}
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"message": "Role disabled."})
}

// HandleGetRolePermissions lists the permissions attached to a role.
//
// GET /api/admin/rbac/roles/{roleID}/permissions
func (h *Handler) HandleGetRolePermissions(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	roleID := chi.URLParam(r, "roleID")

	// Verify accessibility before returning permission data.
	role, err := h.adminRepo.GetRole(r.Context(), roleID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch role.")
		return
	}
	if role == nil || !roleAccessible(role, claims.OrgID) {
		httputil.WriteError(w, http.StatusNotFound, "Role not found.")
		return
	}

	perms, err := h.adminRepo.GetRolePermissions(r.Context(), roleID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch role permissions.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"permissions": perms})
}

// HandleSetRolePermissions replaces the full permission set for a role.
//
// PUT /api/admin/rbac/roles/{roleID}/permissions
func (h *Handler) HandleSetRolePermissions(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	roleID := chi.URLParam(r, "roleID")
	var req SetPermissionsRequest
	if err := h.decodeJSON(r, &req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	perms, err := h.adminSvc.SetRolePermissions(r.Context(), claims.UserID, claims.OrgID, roleID, req)
	if err != nil {
		switch {
		case isNotFound(err):
			httputil.WriteError(w, http.StatusNotFound, "Role not found.")
		case isForbidden(err):
			httputil.WriteError(w, http.StatusForbidden, err.Error())
		default:
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to set role permissions.")
		}
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"permissions": perms})
}

// ─── User-role management ─────────────────────────────────────────────────────

// HandleGetUserRoles lists roles held by a user within the caller's tenant.
//
// GET /api/admin/rbac/users/{userID}/roles
func (h *Handler) HandleGetUserRoles(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	userID := chi.URLParam(r, "userID")
	roles, err := h.adminRepo.GetUserRoles(r.Context(), userID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch user roles.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"roles": roles})
}

// HandleAssignRole grants a role to a user within the caller's tenant.
//
// POST /api/admin/rbac/users/{userID}/roles
func (h *Handler) HandleAssignRole(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	userID := chi.URLParam(r, "userID")
	var req AssignRoleRequest
	if err := h.decodeJSON(r, &req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.RoleID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "role_id is required.")
		return
	}

	if err := h.adminSvc.AssignRole(r.Context(), claims.UserID, claims.OrgID, userID, req.RoleID); err != nil {
		if isForbidden(err) {
			httputil.WriteError(w, http.StatusForbidden, err.Error())
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to assign role.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"message": "Role assigned."})
}

// HandleRevokeRole removes a role from a user within the caller's tenant.
//
// DELETE /api/admin/rbac/users/{userID}/roles/{roleID}
func (h *Handler) HandleRevokeRole(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	userID := chi.URLParam(r, "userID")
	roleID := chi.URLParam(r, "roleID")

	if err := h.adminSvc.RevokeRole(r.Context(), claims.UserID, claims.OrgID, userID, roleID); err != nil {
		if isNotFound(err) {
			httputil.WriteError(w, http.StatusNotFound, "Assignment not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to revoke role.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"message": "Role revoked."})
}

// HandleGetUserPermissions returns the effective permission codes for any user
// within the caller's tenant. Used by the admin effective-permissions viewer.
//
// GET /api/admin/rbac/users/{userID}/permissions
func (h *Handler) HandleGetUserPermissions(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	userID := chi.URLParam(r, "userID")
	codes, err := h.svc.GetEffectivePermissions(r.Context(), userID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch permissions.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"permissions": codes})
}

// ─── Audit log ────────────────────────────────────────────────────────────────

// HandleListAudit returns a paginated audit log scoped to the caller's tenant.
//
// GET /api/admin/rbac/audit?entity_type=role&entity_id=xxx&limit=20&offset=0
func (h *Handler) HandleListAudit(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	params := ListAuditParams{
		TenantID:   claims.OrgID,
		EntityType: h.queryString(r, "entity_type"),
		EntityID:   h.queryString(r, "entity_id"),
		Limit:      h.queryInt(r, "limit", 20),
		Offset:     h.queryInt(r, "offset", 0),
	}

	entries, total, err := h.auditRepo.List(r.Context(), params)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch audit log.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"entries": entries,
		"total":   total,
	})
}

// ─── Internal helpers ─────────────────────────────────────────────────────────

// roleAccessible returns true if a role is visible to the given tenant:
// system roles are always accessible; tenant-owned roles only if they match.
func roleAccessible(role *Role, tenantID string) bool {
	if role.IsSystem {
		return true
	}
	return role.TenantID != nil && *role.TenantID == tenantID
}

// isNotFound checks whether an AdminService error describes a missing entity.
func isNotFound(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "not found")
}

// isForbidden checks whether an AdminService error describes an authorization failure.
func isForbidden(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "cannot modify") ||
		strings.Contains(msg, "cannot disable") ||
		strings.Contains(msg, "does not belong") ||
		strings.Contains(msg, "not accessible") ||
		strings.Contains(msg, "not editable")
}

// isValidationError checks whether an error is a user-input validation failure.
func isValidationError(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), "is required") ||
		strings.Contains(err.Error(), "already exists") ||
		errors.Is(err, errBadInput)
}

var errBadInput = errors.New("bad input")

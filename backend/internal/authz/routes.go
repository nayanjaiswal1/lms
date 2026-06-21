package authz

import "github.com/go-chi/chi/v5"

// RegisterRoutes mounts all RBAC routes onto the given router.
// The router must already have RequireAuth + RequireCSRF applied by the caller.
func (h *Handler) RegisterRoutes(r chi.Router) {
	// Current user's own permissions — no extra permission guard; every
	// authenticated user is allowed to read their own permission set.
	r.Get("/api/me/permissions", h.HandleGetMyPermissions)

	// Admin RBAC management — all sub-routes are protected by at least one
	// of the admin permission codes via per-route RequirePermission/
	// RequireAnyPermission middleware.
	r.Route("/api/admin/rbac", func(r chi.Router) {
		// Permission catalogue — read-only, visible to any admin role.
		r.With(RequireAnyPermission(h.svc,
			"admin.manage_roles",
			"admin.manage_permissions",
			"admin.view_audit_log",
			"admin.view_members",
		)).Get("/permissions", h.HandleListPermissions)

		// ── Roles ────────────────────────────────────────────────────────────
		r.With(RequireAnyPermission(h.svc,
			"admin.manage_roles",
			"admin.manage_permissions",
		)).Get("/roles", h.HandleListRoles)

		r.With(RequirePermission(h.svc, "admin.manage_roles")).
			Post("/roles", h.HandleCreateRole)

		r.With(RequireAnyPermission(h.svc,
			"admin.manage_roles",
			"admin.manage_permissions",
		)).Get("/roles/{roleID}", h.HandleGetRole)

		r.With(RequirePermission(h.svc, "admin.manage_roles")).
			Put("/roles/{roleID}", h.HandleUpdateRole)

		r.With(RequirePermission(h.svc, "admin.manage_roles")).
			Delete("/roles/{roleID}", h.HandleDisableRole)

		r.With(RequireAnyPermission(h.svc,
			"admin.manage_roles",
			"admin.manage_permissions",
		)).Get("/roles/{roleID}/permissions", h.HandleGetRolePermissions)

		r.With(RequirePermission(h.svc, "admin.manage_permissions")).
			Put("/roles/{roleID}/permissions", h.HandleSetRolePermissions)

		// ── User-role management ──────────────────────────────────────────────
		r.With(RequireAnyPermission(h.svc,
			"admin.manage_members",
			"admin.view_members",
		)).Get("/users/{userID}/roles", h.HandleGetUserRoles)

		r.With(RequirePermission(h.svc, "admin.manage_members")).
			Post("/users/{userID}/roles", h.HandleAssignRole)

		r.With(RequirePermission(h.svc, "admin.manage_members")).
			Delete("/users/{userID}/roles/{roleID}", h.HandleRevokeRole)

		r.With(RequireAnyPermission(h.svc,
			"admin.manage_members",
			"admin.view_members",
		)).Get("/users/{userID}/permissions", h.HandleGetUserPermissions)

		// ── Audit log ─────────────────────────────────────────────────────────
		r.With(RequirePermission(h.svc, "admin.view_audit_log")).
			Get("/audit", h.HandleListAudit)
	})
}

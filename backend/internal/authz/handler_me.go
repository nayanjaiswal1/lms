package authz

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// HandleGetMyPermissions returns the full set of permission codes for the
// authenticated user within their current tenant.
//
// GET /api/me/permissions
func (h *Handler) HandleGetMyPermissions(w http.ResponseWriter, r *http.Request) {
	claims, ok := h.getClaims(r)
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	codes, err := h.svc.GetEffectivePermissions(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load permissions.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"permissions": codes})
}

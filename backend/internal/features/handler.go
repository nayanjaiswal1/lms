package features

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// GetMyFeatures resolves and returns the current user's feature config.
func (h *Handler) GetMyFeatures(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	cfg, err := h.service.Resolve(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not resolve features.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, cfg)
}

type setFeatureFlagRequest struct {
	Enabled bool `json:"enabled"`
}

// ─── Platform admin (super_admin): per-org feature flags ─────────────────────

// AdminListOrgFeatureFlags returns every org-toggleable feature's resolved
// state for the org in the {id} URL param.
func (h *Handler) AdminListOrgFeatureFlags(w http.ResponseWriter, r *http.Request) {
	orgID := chi.URLParam(r, "id")
	flags, err := h.service.ListOrgFeatureFlags(r.Context(), orgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not list feature flags.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"flags": flags})
}

// AdminSetOrgFeatureFlag turns a feature on/off for the org in the {id} URL param.
func (h *Handler) AdminSetOrgFeatureFlag(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgID := chi.URLParam(r, "id")
	key := chi.URLParam(r, "key")

	var req setFeatureFlagRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	if err := h.service.SetOrgFeatureFlag(r.Context(), orgID, key, req.Enabled, claims.UserID); err != nil {
		writeFeatureFlagError(w, err, "Could not update feature flag.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// AdminClearOrgFeatureFlag reverts a feature back to its code default for the
// org in the {id} URL param.
func (h *Handler) AdminClearOrgFeatureFlag(w http.ResponseWriter, r *http.Request) {
	orgID := chi.URLParam(r, "id")
	key := chi.URLParam(r, "key")

	if err := h.service.ClearOrgFeatureFlag(r.Context(), orgID, key); err != nil {
		writeFeatureFlagError(w, err, "Could not clear feature flag.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ─── Org admin (owner/admin org role): per-member feature flags ──────────────

// requireOrgAdmin re-derives the org-membership role check handleUpdateMember
// (internal/orgs) already applies to member mutations — kept local to this
// package rather than importing internal/orgs for two string constants.
func requireOrgAdmin(w http.ResponseWriter, r *http.Request) bool {
	orgCtx, ok := apimiddleware.GetOrgCtx(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusForbidden, "Org context missing.")
		return false
	}
	if orgCtx.CallerRole != "owner" && orgCtx.CallerRole != "admin" {
		httputil.WriteError(w, http.StatusForbidden, "Insufficient permissions.")
		return false
	}
	return true
}

// ListMemberFeatureFlags returns every user-toggleable feature the org has
// enabled, resolved for the member in the {member_id} URL param.
func (h *Handler) ListMemberFeatureFlags(w http.ResponseWriter, r *http.Request) {
	if !requireOrgAdmin(w, r) {
		return
	}
	orgCtx, _ := apimiddleware.GetOrgCtx(r.Context())
	// The {member_id} URL segment carries the target user's ID (not an
	// org_members row ID) — see routes.go's RegisterOrgAdminRoutes doc comment.
	userID := chi.URLParam(r, "member_id")

	flags, err := h.service.ListUserFeatureFlags(r.Context(), orgCtx.OrgID, userID)
	if err != nil {
		writeFeatureFlagError(w, err, "Could not list feature flags.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"flags": flags})
}

// SetMemberFeatureFlag turns a feature on/off for the member in the
// {member_id} URL param.
func (h *Handler) SetMemberFeatureFlag(w http.ResponseWriter, r *http.Request) {
	if !requireOrgAdmin(w, r) {
		return
	}
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	orgCtx, _ := apimiddleware.GetOrgCtx(r.Context())
	// The {member_id} URL segment carries the target user's ID (not an
	// org_members row ID) — see routes.go's RegisterOrgAdminRoutes doc comment.
	userID := chi.URLParam(r, "member_id")
	key := chi.URLParam(r, "key")

	var req setFeatureFlagRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	if err := h.service.SetUserFeatureFlag(r.Context(), orgCtx.OrgID, userID, key, req.Enabled, claims.UserID); err != nil {
		writeFeatureFlagError(w, err, "Could not update feature flag.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ClearMemberFeatureFlag reverts a feature back to the org's default
// entitlement for the member in the {member_id} URL param.
func (h *Handler) ClearMemberFeatureFlag(w http.ResponseWriter, r *http.Request) {
	if !requireOrgAdmin(w, r) {
		return
	}
	orgCtx, _ := apimiddleware.GetOrgCtx(r.Context())
	// The {member_id} URL segment carries the target user's ID (not an
	// org_members row ID) — see routes.go's RegisterOrgAdminRoutes doc comment.
	userID := chi.URLParam(r, "member_id")
	key := chi.URLParam(r, "key")

	if err := h.service.ClearUserFeatureFlag(r.Context(), orgCtx.OrgID, userID, key); err != nil {
		writeFeatureFlagError(w, err, "Could not clear feature flag.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func writeFeatureFlagError(w http.ResponseWriter, err error, fallback string) {
	switch {
	case errors.Is(err, ErrUnknownFeatureKey):
		httputil.WriteError(w, http.StatusNotFound, "Unknown feature key.")
	case errors.Is(err, ErrFeatureNotOrgEnabled):
		httputil.WriteError(w, http.StatusConflict, "The organisation has not enabled this feature.")
	case errors.Is(err, ErrNotOrgMember):
		httputil.WriteError(w, http.StatusNotFound, "Member not found.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, fallback)
	}
}

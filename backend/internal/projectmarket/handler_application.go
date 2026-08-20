package projectmarket

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Apply handles POST /api/project-marketplace/board/{id}/apply — any org
// member applies to an open requirement.
func (h *Handler) Apply(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req ApplyRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	app, err := h.service.Apply(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "requirementID"), req.Motivation, req.ResumeText)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, app)
}

// ListMyApplications handles GET /api/my/project-applications.
func (h *Handler) ListMyApplications(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	apps, err := h.service.ListMyApplications(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, apps)
}

// ReviewApplication handles PATCH
// /api/project-marketplace/applications/{id} — staff moves an application to
// shortlisted/selected/rejected.
func (h *Handler) ReviewApplication(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req ApplicationReview
	if !decodeJSON(w, r, &req) {
		return
	}
	app, err := h.service.ReviewApplication(r.Context(), claims.OrgID, chi.URLParam(r, "applicationID"), req.Status, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, app)
}

// WithdrawApplication handles DELETE
// /api/project-marketplace/applications/{id} — a student withdraws their own
// application (scoped to caller — see Repo.WithdrawApplication).
func (h *Handler) WithdrawApplication(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.WithdrawApplication(r.Context(), claims.OrgID, chi.URLParam(r, "applicationID"), claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Application withdrawn."})
}

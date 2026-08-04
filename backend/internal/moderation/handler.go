package moderation

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
)

// PermissionModerate gates the staff queue (view every report, resolve it)
// — mirrors backend/db/migrations/023_content_reports.sql.
const PermissionModerate = "content.moderate"

type Handler struct {
	service  *Service
	authzSvc *authz.Service
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:        {Status: http.StatusNotFound, Message: "Not found."},
	ErrContentNotFound: {Status: http.StatusNotFound, Message: "That content no longer exists."},
	ErrInvalid:         {Status: http.StatusUnprocessableEntity},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// CreateReport lets any authenticated org member flag a piece of content.
// Body: {"content_type": "...", "content_id": "...", "reason": "...", "description": "..."}.
func (h *Handler) CreateReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		ContentType string `json:"content_type"`
		ContentID   string `json:"content_id"`
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}
	report, err := h.service.CreateReport(r.Context(), claims.UserID, req.ContentType, req.ContentID, req.Reason, req.Description)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, report)
}

// ListReports returns every report in the org, optionally filtered by
// ?status= and/or ?content_type=. Staff-only — gated by content.moderate in
// routes.go.
func (h *Handler) ListReports(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	status := queryStrPtr(r, "status")
	contentType := queryStrPtr(r, "content_type")
	reports, err := h.service.ListReports(r.Context(), claims.OrgID, status, contentType)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"reports": reports})
}

// Resolve transitions a report's status, and takes down the underlying
// content if the resolution is 'removed'. Staff-only — gated by
// content.moderate in routes.go. Body: {"status": "...", "resolution_note": "..."}.
func (h *Handler) Resolve(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Status         string `json:"status"`
		ResolutionNote string `json:"resolution_note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}
	report, err := h.service.Resolve(r.Context(), claims.OrgID, chi.URLParam(r, "reportID"), req.Status, claims.UserID, req.ResolutionNote)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, report)
}

func queryStrPtr(r *http.Request, key string) *string {
	v := r.URL.Query().Get(key)
	if v == "" {
		return nil
	}
	return &v
}

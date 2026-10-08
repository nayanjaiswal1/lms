package labs

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// HandleCatalog serves GET /api/labs/catalog?kind=&stack=&category=&difficulty=
// — published, org-visible labs carrying catalog tags, with the caller's best
// status. Generic across lab types (kind filters lab_type).
func (h *Handler) HandleCatalog(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	entries, err := h.repo.ListCatalog(r.Context(), claims.OrgID, claims.UserID,
		strings.TrimSpace(q.Get("kind")), strings.TrimSpace(q.Get("stack")),
		strings.TrimSpace(q.Get("category")), strings.TrimSpace(q.Get("difficulty")))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entries)
}

// HandleDebrief serves GET /api/labs/sessions/{sessionID}/debrief (completed
// sessions only; IDOR via GetSession(userID)).
func (h *Handler) HandleDebrief(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	out, err := h.service.GetDebrief(r.Context(), chi.URLParam(r, "sessionID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, out)
}

// HandleWriteupReview serves POST /api/labs/sessions/{sessionID}/writeup-review.
func (h *Handler) HandleWriteupReview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	out, err := h.service.ReviewWriteup(r.Context(), chi.URLParam(r, "sessionID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, out)
}

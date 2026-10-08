package feedback

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:  {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden: {Status: http.StatusForbidden},
	ErrInvalid:   {Status: http.StatusUnprocessableEntity},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

// SubmitFeedback handles POST /api/feedback (body: SubmitRequest) — creates or
// updates the caller's rating or experience report, or an explicit skip, for
// a course, assessment, lab, mentor or mentor session.
func (h *Handler) SubmitFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req SubmitRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	f, err := h.service.Submit(r.Context(), &claims.OrgID, claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, f)
}

// ListFeedback returns recent public reviews (rating + comment) for a
// subject — e.g. the "Recent feedback" list on a mentor profile page.
// Optional ?limit= query param, clamped server-side.
func (h *Handler) ListFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	subjectType := SubjectType(chi.URLParam(r, "subjectType"))
	subjectID := chi.URLParam(r, "subjectID")
	limit := 0
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}
	reviews, err := h.service.ListPublic(r.Context(), &claims.OrgID, subjectType, subjectID, limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"reviews": reviews})
}

// GetMyFeedback handles GET /api/feedback/{subjectType}/{subjectID}/me?kind=
// (kind defaults to rating) — the caller's own answer. Responds 200 with a
// null feedback field (not 404) when they haven't answered or skipped yet,
// the frontend's signal to show the prompt.
func (h *Handler) GetMyFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	kind := Kind(r.URL.Query().Get("kind"))
	if kind == "" {
		kind = KindRating
	}
	subjectType := SubjectType(chi.URLParam(r, "subjectType"))
	subjectID := chi.URLParam(r, "subjectID")
	f, err := h.service.GetMine(r.Context(), kind, subjectType, subjectID, claims.UserID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"feedback": nil})
			return
		}
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"feedback": f})
}

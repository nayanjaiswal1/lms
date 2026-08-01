package feedback

import (
	"encoding/json"
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

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, err.Error())
	case errors.Is(err, ErrInvalid):
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// SubmitFeedback creates or updates the authenticated user's feedback
// (rating/comment, or an explicit skip) for a course, assessment, or lab.
func (h *Handler) SubmitFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		SubjectType SubjectType `json:"subject_type"`
		SubjectID   string      `json:"subject_id"`
		Rating      *int        `json:"rating"`
		Comment     *string     `json:"comment"`
		Skip        bool        `json:"skip"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	f, err := h.service.Submit(r.Context(), claims.OrgID, body.SubjectType, body.SubjectID, claims.UserID, body.Rating, body.Comment, body.Skip)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, f)
}

// ListFeedback returns recent public reviews (rating + comment) for a
// subject — e.g. the "Recent feedback" list on a mentor profile page.
// Optional ?limit= query param, clamped server-side.
func (h *Handler) ListFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
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
	reviews, err := h.service.ListPublic(r.Context(), claims.OrgID, subjectType, subjectID, limit)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"reviews": reviews})
}

// GetMyFeedback returns the authenticated user's existing feedback for a
// subject. Responds 200 with a null feedback field (not 404) when the user
// hasn't rated or skipped it yet, so the frontend can treat "null" as the
// signal to show the completion prompt.
func (h *Handler) GetMyFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	subjectType := SubjectType(chi.URLParam(r, "subjectType"))
	subjectID := chi.URLParam(r, "subjectID")
	f, err := h.service.GetMine(r.Context(), subjectType, subjectID, claims.UserID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"feedback": nil})
			return
		}
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"feedback": f})
}

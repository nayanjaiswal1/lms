package courses

import (
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// SubmitReview creates or updates the authenticated student's star rating
// for a course. Only enrolled students may rate — this keeps the aggregate
// shown on course cards tied to verified course access.
func (h *Handler) SubmitReview(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Rating int `json:"rating"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Rating < 1 || req.Rating > 5 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"rating": "Rating must be between 1 and 5."})
		return
	}
	courseID := urlParam(r, "courseID")
	enrolled, err := h.repo.IsEnrolled(r.Context(), claims.UserID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if !enrolled {
		httputil.WriteError(w, http.StatusForbidden, "Enroll in this course before rating it.")
		return
	}
	rev, err := h.repo.UpsertReview(r.Context(), CourseReview{
		CourseID: courseID,
		UserID:   claims.UserID,
		Rating:   req.Rating,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rev)
}

// GetMyReview returns the authenticated user's existing rating for a course,
// so the client can pre-select their star choice. 404 if they haven't rated yet.
func (h *Handler) GetMyReview(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	rev, err := h.repo.GetMyReview(r.Context(), claims.UserID, urlParam(r, "courseID"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"rating": nil})
			return
		}
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"rating": rev.Rating})
}

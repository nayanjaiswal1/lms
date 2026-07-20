package revisionplan

import (
	"errors"
	"net/http"

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

// Generate requests a fresh (or regenerated) revision plan for the
// authenticated student's completed course.
func (h *Handler) Generate(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	plan, err := h.service.Generate(r.Context(), claims.UserID, chi.URLParam(r, "courseID"), claims.OrgID)
	if err != nil {
		if errors.Is(err, ErrCourseNotComplete) {
			httputil.WriteError(w, http.StatusUnprocessableEntity, "Complete this course before generating a revision plan.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, plan)
}

// GetMine returns the authenticated student's revision plan for a course, or
// null if they haven't requested one yet.
func (h *Handler) GetMine(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	plan, err := h.service.Get(r.Context(), claims.UserID, chi.URLParam(r, "courseID"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"plan": nil})
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"plan": plan})
}

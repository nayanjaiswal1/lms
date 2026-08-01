package experience

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound: {Status: http.StatusNotFound, Message: "Not found."},
	ErrInvalid:  {Status: http.StatusUnprocessableEntity},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// SubmitReport creates or updates the authenticated user's post-activity
// experience report (smooth/issue/complaint + optional description, or an
// explicit skip) for a subject.
func (h *Handler) SubmitReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		SubjectType SubjectType `json:"subject_type"`
		SubjectID   string      `json:"subject_id"`
		Experience  *Experience `json:"experience"`
		Description *string     `json:"description"`
		Skip        bool        `json:"skip"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	rep, err := h.service.Submit(r.Context(), claims.OrgID, body.SubjectType, body.SubjectID, claims.UserID, body.Experience, body.Description, body.Skip)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rep)
}

// GetMyReport returns the authenticated user's existing experience report for
// a subject. Responds 200 with a null report field (not 404) when the user
// hasn't reported or skipped yet, so the frontend can treat "null" as the
// signal to show the prompt.
func (h *Handler) GetMyReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	subjectType := SubjectType(chi.URLParam(r, "subjectType"))
	subjectID := chi.URLParam(r, "subjectID")
	rep, err := h.service.GetMine(r.Context(), subjectType, subjectID, claims.UserID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"report": nil})
			return
		}
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"report": rep})
}

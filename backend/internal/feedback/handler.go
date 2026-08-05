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

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:  {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden: {Status: http.StatusForbidden},
	ErrInvalid:   {Status: http.StatusUnprocessableEntity},
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

// SubmitFeedback creates or updates the authenticated user's feedback
// (rating/comment, or an explicit skip) for a course, assessment, lab, or mentor.
func (h *Handler) SubmitFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	f, err := h.service.Submit(r.Context(), &claims.OrgID, body.SubjectType, body.SubjectID, claims.UserID, KindRating, body.Rating, body.Comment, body.Skip)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, f)
}

// SubmitExperienceReport creates or updates the authenticated user's experience
// report (a post-activity "did anything go wrong" feedback) for a subject.
func (h *Handler) SubmitExperienceReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		SubjectType string  `json:"subject_type"`
		SubjectID   string  `json:"subject_id"`
		Comment     *string `json:"description"` // legacy key name
		Skip        bool    `json:"skip"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	// experience_reports used custom subject_type values (e.g. 'assessment');
	// now they map to 'experience_subject' in the unified feedback table.
	subjectType := SubjectTypeExperienceSubj
	f, err := h.service.Submit(r.Context(), &claims.OrgID, subjectType, body.SubjectID, claims.UserID, KindExperience, nil, body.Comment, body.Skip)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, f)
}

// GetMyExperienceReport returns the authenticated user's existing experience
// report for a subject. Responds 200 with a null feedback field when the
// user hasn't reported or skipped it yet.
func (h *Handler) GetMyExperienceReport(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	subjectID := chi.URLParam(r, "subjectID")
	// experience_reports used custom subject_type values; look up experience_subject.
	subjectType := SubjectTypeExperienceSubj
	f, err := h.service.GetMine(r.Context(), subjectType, subjectID, claims.UserID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{"experience_report": nil})
			return
		}
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"experience_report": f})
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

// GetMyFeedback returns the authenticated user's existing feedback for a
// subject. Responds 200 with a null feedback field (not 404) when the user
// hasn't rated or skipped it yet, so the frontend can treat "null" as the
// signal to show the completion prompt.
func (h *Handler) GetMyFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"feedback": f})
}

package assessment

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// AssessmentAnalytics returns aggregate performance for one assessment (staff).
func (h *Handler) AssessmentAnalytics(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	stats, err := h.repo.AssessmentAnalytics(r.Context(), claims.OrgID, chiURLParam(r, "assessmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, stats)
}

// ListAssessmentAttempts returns the staff result table for an assessment.
func (h *Handler) ListAssessmentAttempts(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	rows, err := h.repo.ListAssessmentAttempts(r.Context(), claims.OrgID, chiURLParam(r, "assessmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"attempts": rows})
}

// AttemptProctoringLog returns the full anti-cheat event log for an attempt
// (staff review). Scoped to the caller's org via the attempt's assessment.
func (h *Handler) AttemptProctoringLog(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	attemptID := chiURLParam(r, "attemptID")
	att, err := h.repo.GetAttempt(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if att.OrgID != claims.OrgID {
		writeDomainError(w, ErrNotFound)
		return
	}
	events, err := h.repo.ListEvents(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	review, err := h.repo.AttemptReview(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"attempt": att, "events": events, "review": review,
	})
}

// MyAnalytics returns the authenticated learner's personal performance summary.
func (h *Handler) MyAnalytics(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	stats, err := h.repo.StudentAnalytics(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, stats)
}

// OrgAnalytics returns the organisation-wide assessment overview (staff).
func (h *Handler) OrgAnalytics(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	stats, err := h.repo.OrgAnalytics(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, stats)
}

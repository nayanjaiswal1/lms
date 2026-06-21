package assessment

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// HandleGetEvaluationStatus is a lightweight poll endpoint. The client calls
// this every few seconds after a 202 response from SubmitAttempt until
// has_result is true, then fetches the full evaluation.
func (h *Handler) HandleGetEvaluationStatus(w http.ResponseWriter, r *http.Request) {
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
	if att.UserID != claims.UserID {
		writeDomainError(w, ErrNotAttemptOwner)
		return
	}
	status, err := h.repo.GetEvaluationStatus(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, status)
}

// HandleGetEvaluation returns the complete AI evaluation for an owned attempt.
// Only available once status is 'evaluated'.
func (h *Handler) HandleGetEvaluation(w http.ResponseWriter, r *http.Request) {
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
	if att.UserID != claims.UserID {
		writeDomainError(w, ErrNotAttemptOwner)
		return
	}
	eval, err := h.repo.GetEvaluation(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, eval)
}

// HandleCompareEvaluations returns two evaluations side-by-side for the owner.
// Used by the frontend attempt comparison view.
func (h *Handler) HandleCompareEvaluations(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	attemptID := chiURLParam(r, "attemptID")
	otherID := chiURLParam(r, "otherID")

	att, err := h.repo.GetAttempt(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if att.UserID != claims.UserID {
		writeDomainError(w, ErrNotAttemptOwner)
		return
	}
	other, err := h.repo.GetAttempt(r.Context(), otherID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if other.UserID != claims.UserID {
		writeDomainError(w, ErrNotAttemptOwner)
		return
	}

	evalA, err := h.repo.GetEvaluation(r.Context(), attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	evalB, err := h.repo.GetEvaluation(r.Context(), otherID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"attempt_a": evalA,
		"attempt_b": evalB,
	})
}

// HandleStudentProgress returns the student's readiness trend and skill
// breakdown for the interview progress dashboard.
func (h *Handler) HandleStudentProgress(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	progress, err := h.repo.GetStudentProgress(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, progress)
}

// HandleSkillTrends returns the rolling average and latest score per skill for
// the authenticated student.
func (h *Handler) HandleSkillTrends(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	trends, err := h.repo.GetSkillTrends(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"skill_trends": trends})
}

// HandleReviewQueue returns the paginated list of flagged attempts for staff.
// Requires admin/instructor/mentor role (enforced by the staff router group).
func (h *Handler) HandleReviewQueue(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	limit := queryInt(r, "limit", 50)
	offset := queryInt(r, "offset", 0)
	if limit > 200 {
		limit = 200
	}
	items, err := h.repo.GetReviewQueue(r.Context(), claims.OrgID, limit, offset)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}

// HandleEvalQueueHealth returns the number of queued and in-flight eval.subjective jobs.
// Intended for ops dashboards and alerting; requires staff role.
func (h *Handler) HandleEvalQueueHealth(w http.ResponseWriter, r *http.Request) {
	_, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	var pending, processing int
	row := h.pool.QueryRow(r.Context(), `
		SELECT
			COUNT(*) FILTER (WHERE status = 'queued')  AS pending,
			COUNT(*) FILTER (WHERE status = 'running') AS processing
		FROM jobs
		WHERE handler = 'eval.subjective' AND deleted_at IS NULL`,
	)
	if err := row.Scan(&pending, &processing); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to read queue depth.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"pending":    pending,
		"processing": processing,
	})
}

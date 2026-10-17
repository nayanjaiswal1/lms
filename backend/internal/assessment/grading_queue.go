package assessment

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Attempts have no dedicated "pending manual grading" status. The truthful
// equivalent is a submitted (or eval_failed) attempt that still has at least
// one answer no grader has scored (attempt_answers.evaluated_at IS NULL):
// coding answers whose executor was unavailable, and subjective answers
// whose AI evaluation failed. A staff score override sets evaluated_at, so
// the attempt leaves the queue once every answer is scored. Attempts in
// 'evaluating' are excluded — the AI evaluator still owns them.
const (
	defaultGradingQueueLimit = 10
	maxGradingQueueLimit     = 50
)

// GradingQueueItem is one attempt awaiting a staff grade.
type GradingQueueItem struct {
	AttemptID       string     `json:"attempt_id"`
	AssessmentID    string     `json:"assessment_id"`
	AssessmentTitle string     `json:"assessment_title"`
	UserID          *string    `json:"user_id"`
	UserName        *string    `json:"user_name"`
	Status          string     `json:"status"`
	SubmittedAt     *time.Time `json:"submitted_at"`
	UngradedAnswers int        `json:"ungraded_answers"`
}

// GradingQueue returns the oldest-first top `limit` attempts in orgID that
// still have ungraded answers, plus the total count. When batchIDs is non-nil
// the queue is limited to attempts by members of those batches (the
// mentor scope); an empty non-nil slice yields nothing.
func (r *Repo) GradingQueue(ctx context.Context, orgID string, batchIDs []string, limit int) ([]GradingQueueItem, int, error) {
	rows, err := r.pool.Query(ctx, `
		WITH pending AS (
			SELECT at.id, at.assessment_id, at.user_id, at.status, at.submitted_at,
			       (SELECT count(*) FROM attempt_answers ans
			         WHERE ans.attempt_id = at.id AND ans.evaluated_at IS NULL)::int AS ungraded
			FROM assessment_attempts at
			WHERE at.org_id = $1 AND at.status IN ('submitted', 'eval_failed')
			  AND ($2::text[] IS NULL OR EXISTS (
			        SELECT 1 FROM batch_members bm
			        WHERE bm.user_id = at.user_id AND bm.batch_id::text = ANY($2)))
		)
		SELECT p.id, p.assessment_id, a.title, p.user_id, u.name, p.status, p.submitted_at, p.ungraded,
		       (count(*) OVER ())::int
		FROM pending p
		JOIN assessments a ON a.id = p.assessment_id
		LEFT JOIN users u ON u.id = p.user_id
		WHERE p.ungraded > 0
		ORDER BY p.submitted_at ASC NULLS LAST, p.id
		LIMIT $3`, orgID, batchIDs, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("assessment.GradingQueue: %w", err)
	}
	defer rows.Close()
	items := []GradingQueueItem{}
	total := 0
	for rows.Next() {
		var it GradingQueueItem
		if err := rows.Scan(&it.AttemptID, &it.AssessmentID, &it.AssessmentTitle, &it.UserID, &it.UserName,
			&it.Status, &it.SubmittedAt, &it.UngradedAnswers, &total); err != nil {
			return nil, 0, fmt.Errorf("assessment.GradingQueue: scan: %w", err)
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("assessment.GradingQueue: %w", err)
	}
	return items, total, nil
}

// GetGradingQueue returns the caller's attempts awaiting a staff grade.
// Callers without assessments.manage_batches see only attempts by members of
// batches they mentor (same scope as the other results routes).
//
//	GET /api/assessments/grading-queue?limit=10
func (h *Handler) GetGradingQueue(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	limit := httputil.QueryInt(r, "limit", defaultGradingQueueLimit)
	if limit < 1 || limit > maxGradingQueueLimit {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity,
			map[string]string{"limit": fmt.Sprintf("limit must be between 1 and %d.", maxGradingQueueLimit)})
		return
	}
	batchIDs, scoped, err := mentorScopeIDs(r.Context(), h.pool, h.authzSvc, claims)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not verify access.")
		return
	}
	if !scoped {
		batchIDs = nil
	}
	items, total, err := h.repo.GradingQueue(r.Context(), claims.OrgID, batchIDs, limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"total": total, "items": items, "limit": limit})
}

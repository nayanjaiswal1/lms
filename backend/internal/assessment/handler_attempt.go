package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/rewards"
)

// ─── Student: assigned list ──────────────────────────────────────────────────

// ListMyAssessments returns assessments assigned to the authenticated student
// with their attempt progress.
func (h *Handler) ListMyAssessments(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	items, err := h.repo.ListAssignedForUser(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"assessments": items})
}

// attemptPayload is the response shape for starting or resuming an attempt.
type attemptPayload struct {
	Attempt    Attempt           `json:"attempt"`
	Questions  []StudentQuestion `json:"questions"`
	Proctoring ProctoringConfig  `json:"proctoring"`
	Meta       attemptMeta       `json:"meta"`
}

type attemptMeta struct {
	Title           string  `json:"title"`
	DurationMinutes int     `json:"duration_minutes"`
	AllowBacktrack  bool    `json:"allow_backtrack"`
	MockMode        bool    `json:"mock_mode"`
	TotalPoints     float64 `json:"total_points"`
	PassPercentage  float64 `json:"pass_percentage"`
}

// StartAttempt creates or resumes the student's attempt and returns the
// sanitized question set plus proctoring policy.
func (h *Handler) StartAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	att, questions, a, err := h.service.StartAttempt(r.Context(), claims.OrgID, claims.UserID, chiURLParam(r, "assessmentID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, attemptPayload{
		Attempt:    att,
		Questions:  questions,
		Proctoring: a.Proctoring,
		Meta: attemptMeta{
			Title:           a.Title,
			DurationMinutes: a.DurationMinutes,
			AllowBacktrack:  a.AllowBacktrack,
			MockMode:        a.MockMode,
			TotalPoints:     a.TotalPoints,
			PassPercentage:  a.PassPercentage,
		},
	})
}

// ResumeAttempt returns the current state of an owned in-flight attempt.
func (h *Handler) ResumeAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	att, questions, a, err := h.service.ResumeAttempt(r.Context(), claims.OrgID, claims.UserID, chiURLParam(r, "attemptID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, attemptPayload{
		Attempt:    att,
		Questions:  questions,
		Proctoring: a.Proctoring,
		Meta: attemptMeta{
			Title:           a.Title,
			DurationMinutes: a.DurationMinutes,
			AllowBacktrack:  a.AllowBacktrack,
			MockMode:        a.MockMode,
			TotalPoints:     a.TotalPoints,
			PassPercentage:  a.PassPercentage,
		},
	})
}

type saveAnswerRequest struct {
	AssessmentQuestionID string          `json:"assessment_question_id"`
	Answer               json.RawMessage `json:"answer"`
	Transcript           *string         `json:"transcript,omitempty"`
	TimeSpentSeconds     int             `json:"time_spent_seconds"`
}

// SaveAnswer stores a draft answer mid-attempt. For subjective questions the
// client sends transcript; for MCQ/coding it sends the answer JSON payload.
func (h *Handler) SaveAnswer(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req saveAnswerRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.AssessmentQuestionID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"assessment_question_id": "Question is required."})
		return
	}
	err := h.service.SaveAnswer(r.Context(), claims.UserID, chiURLParam(r, "attemptID"),
		req.AssessmentQuestionID, req.Answer, req.Transcript, req.TimeSpentSeconds)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Saved."})
}

// SubmitAttempt grades and finalizes the attempt. Returns 202 when the attempt
// contains subjective questions that require AI evaluation.
func (h *Handler) SubmitAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	att, needsEval, err := h.service.Submit(r.Context(), claims.OrgID, claims.UserID, chiURLParam(r, "attemptID"), false)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if needsEval {
		h.enqueueEval(r.Context(), att.ID)
		httputil.WriteJSON(w, http.StatusAccepted, att)
		return
	}
	// Sync graded path (MCQ/coding): award XP and persist the reward result.
	if h.rewardsSvc != nil && att.Passed != nil && *att.Passed {
		att = h.awardAttemptXP(r.Context(), att)
	}
	httputil.WriteJSON(w, http.StatusOK, att)
}

// awardAttemptXP awards XP for a synchronously graded passed attempt, stores the
// reward result in the DB, and returns the attempt with RewardResult populated.
// All errors are logged and swallowed — reward failures must not break the response.
func (h *Handler) awardAttemptXP(ctx context.Context, att Attempt) Attempt {
	xp := rewards.XPQuizPassedRepeat
	if att.AttemptNumber == 1 {
		xp = rewards.XPQuizPassedFirst
	}
	refType := "attempt"
	result := h.rewardsSvc.AwardXP(ctx, rewards.AwardXPRequest{
		UserID:  att.UserID,
		OrgID:   att.OrgID,
		Reason:  "quiz_passed",
		RefID:   &att.ID,
		RefType: &refType,
		XP:      xp,
	})
	// Perfect score bonus: additional XP + badge check.
	if att.Percentage != nil && *att.Percentage == 100 {
		perfect := h.rewardsSvc.AwardXP(ctx, rewards.AwardXPRequest{
			UserID:  att.UserID,
			OrgID:   att.OrgID,
			Reason:  "quiz_perfect",
			RefID:   &att.ID,
			RefType: &refType,
			XP:      rewards.XPQuizPerfectBonus,
		})
		result.XPGained += perfect.XPGained
		result.NewAchievements = append(result.NewAchievements, perfect.NewAchievements...)
		if perfect.NewLevel != nil {
			result.NewLevel = perfect.NewLevel
		}
	}
	// Streak update — every passed quiz counts as a learning activity.
	streakResult := h.rewardsSvc.UpdateStreakAndCheckMilestones(ctx, att.UserID, att.OrgID)
	result.XPGained += streakResult.XPGained
	result.NewAchievements = append(result.NewAchievements, streakResult.NewAchievements...)
	if streakResult.NewLevel != nil {
		result.NewLevel = streakResult.NewLevel
	}

	if err := h.repo.SetAttemptRewardResult(ctx, att.ID, result); err != nil {
		slog.Error("assessment: persist reward result", "attempt", att.ID, "err", err)
		return att
	}
	raw, _ := json.Marshal(result)
	att.RewardResult = raw
	return att
}

// enqueueEval enqueues an eval.subjective job via the Job Management System.
// Errors are logged but not returned — the attempt is already saved and can be
// retried manually or via the admin jobs UI.
func (h *Handler) enqueueEval(ctx context.Context, attemptID string) {
	// Load the attempt to get orgID for quota enforcement and tenant isolation.
	att, err := h.repo.GetAttempt(ctx, attemptID)
	if err != nil {
		slog.Error("eval: get attempt for enqueue", "attempt", attemptID, "error", err)
		return
	}
	orgID := att.OrgID
	idempKey := "eval:" + attemptID
	_, enqErr := jobs.Enqueue(ctx, h.pool, h.jobRegistry, jobs.EnqueueParams{
		Handler:        "eval.subjective",
		Priority:       jobs.PriorityHigh,
		Payload:        map[string]string{"attempt_id": attemptID},
		OrgID:          &orgID,
		IdempotencyKey: &idempKey,
	})
	if enqErr != nil && !errors.Is(enqErr, jobs.ErrDuplicateKey) {
		slog.Error("failed to enqueue eval job", "attempt_id", attemptID, "error", enqErr)
		// non-fatal: attempt is saved, eval will be retried manually
	}
}

type eventRequest struct {
	EventType string          `json:"event_type"`
	Severity  string          `json:"severity"`
	Metadata  json.RawMessage `json:"metadata"`
	ClientTS  *time.Time      `json:"client_ts"`
}

var validEventTypes = map[string]bool{
	"tab_switch": true, "focus_loss": true, "focus_gain": true, "fullscreen_exit": true,
	"fullscreen_enter": true, "copy": true, "paste": true, "cut": true, "right_click": true,
	"devtools_open": true, "visibility_hidden": true, "visibility_visible": true,
	"window_resize": true, "network_offline": true, "heartbeat": true,
}

// RecordEvent ingests a proctoring signal. If a hard cap is breached and
// auto-submit is on, the attempt is force-submitted and the response signals it.
func (h *Handler) RecordEvent(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req eventRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if !validEventTypes[req.EventType] {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Unknown event type.")
		return
	}
	if req.Severity == "" {
		req.Severity = "info"
	}
	forced, err := h.service.RecordEvent(r.Context(), claims.OrgID, claims.UserID,
		chiURLParam(r, "attemptID"), req.EventType, req.Severity, req.Metadata, req.ClientTS)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"auto_submitted": forced})
}

// GetAttemptResult returns the graded result for an owned attempt. Per-question
// review (correct answers, explanations) is included only when the assessment
// permits showing results.
func (h *Handler) GetAttemptResult(w http.ResponseWriter, r *http.Request) {
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
	a, err := h.repo.GetAssessment(r.Context(), claims.OrgID, att.AssessmentID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	resp := map[string]any{"attempt": att, "show_review": a.ShowResults}
	if a.ShowResults {
		review, err := h.repo.AttemptReview(r.Context(), attemptID)
		if err != nil {
			writeDomainError(w, err)
			return
		}
		resp["review"] = review
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
}

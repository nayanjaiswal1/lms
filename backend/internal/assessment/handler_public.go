package assessment

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/httputil"
)

// ─── Public hiring assessment handlers (no auth required) ────────────────────

type publicTestInfo struct {
	ID              string  `json:"id"`
	Title           string  `json:"title"`
	Description     *string `json:"description,omitempty"`
	DurationMinutes int     `json:"duration_minutes"`
	QuestionCount   int     `json:"question_count"`
	PassPercentage  float64 `json:"pass_percentage"`
}

// GetPublicTest returns metadata for a published hiring assessment.
// GET /api/p/{code}
func (h *Handler) GetPublicTest(w http.ResponseWriter, r *http.Request) {
	code := chiURLParam(r, "code")
	a, err := h.repo.GetAssessmentByShortCode(r.Context(), code)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, publicTestInfo{
		ID:              a.ID,
		Title:           a.Title,
		Description:     a.Description,
		DurationMinutes: a.DurationMinutes,
		QuestionCount:   a.QuestionCount,
		PassPercentage:  a.PassPercentage,
	})
}

type startPublicAttemptRequest struct {
	Name  string  `json:"name"`
	Email string  `json:"email"`
	Phone *string `json:"phone,omitempty"`
}

// StartPublicAttempt creates a candidate session and returns questions.
// POST /api/p/{code}/start
func (h *Handler) StartPublicAttempt(w http.ResponseWriter, r *http.Request) {
	code := chiURLParam(r, "code")
	var req startPublicAttemptRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	if strings.TrimSpace(req.Name) == "" {
		fields["name"] = "Name is required."
	}
	if strings.TrimSpace(req.Email) == "" {
		fields["email"] = "Email is required."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	a, err := h.repo.GetAssessmentByShortCode(r.Context(), code)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	att, err := h.repo.CreatePublicAttempt(r.Context(), a.ID, req.Name, req.Email, req.Phone)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	questions, err := h.repo.ListAssessmentQuestions(r.Context(), a.ID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	studentQuestions := make([]StudentQuestion, 0, len(questions))
	for _, q := range questions {
		sq, err := toStudentView(q, a.ShuffleOptions)
		if err != nil {
			continue
		}
		studentQuestions = append(studentQuestions, sq)
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]any{
		"session_token": att.SessionToken,
		"questions":     studentQuestions,
		"meta": map[string]any{
			"title":            a.Title,
			"duration_minutes": a.DurationMinutes,
			"allow_backtrack":  a.AllowBacktrack,
			"total_points":     a.TotalPoints,
			"pass_percentage":  a.PassPercentage,
		},
	})
}

type submitPublicAttemptRequest struct {
	Answers json.RawMessage `json:"answers"`
}

// SubmitPublicAttempt grades MCQ answers and marks the session complete.
// POST /api/p/{code}/submit/{token}
func (h *Handler) SubmitPublicAttempt(w http.ResponseWriter, r *http.Request) {
	code := chiURLParam(r, "code")
	token := chiURLParam(r, "token")

	var req submitPublicAttemptRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	a, err := h.repo.GetAssessmentByShortCode(r.Context(), code)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	questions, err := h.repo.ListAssessmentQuestions(r.Context(), a.ID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	att, err := h.repo.SubmitPublicAttempt(r.Context(), token, req.Answers, questions, a.PassPercentage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"score":       att.Score,
		"max_score":   att.MaxScore,
		"percentage":  att.Percentage,
		"passed":      att.Passed,
		"duration_sec": att.DurationSec,
	})
}

// GetPublicResult returns the scored result for a candidate session.
// GET /api/p/{code}/result/{token}
func (h *Handler) GetPublicResult(w http.ResponseWriter, r *http.Request) {
	token := chiURLParam(r, "token")
	att, err := h.repo.GetPublicAttemptByToken(r.Context(), token)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if att.Status != "submitted" {
		httputil.WriteError(w, http.StatusConflict, "Test has not been submitted yet.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"name":         att.Name,
		"score":        att.Score,
		"max_score":    att.MaxScore,
		"percentage":   att.Percentage,
		"passed":       att.Passed,
		"duration_sec": att.DurationSec,
		"submitted_at": att.SubmittedAt,
	})
}

// GetPublicCandidates returns all candidate attempts for a hiring assessment (staff).
// GET /api/assessments/{assessmentID}/candidates
func (h *Handler) GetPublicCandidates(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chiURLParam(r, "assessmentID")
	// Verify org ownership.
	if _, err := h.repo.GetAssessment(r.Context(), claims.OrgID, id); err != nil {
		writeDomainError(w, err)
		return
	}
	attempts, err := h.repo.ListPublicAttempts(r.Context(), id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if attempts == nil {
		attempts = []PublicAttempt{}
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"candidates": attempts})
}

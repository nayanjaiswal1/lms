package assessment

import (
	"encoding/json"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/auth"
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
	code := httputil.URLParam(r, "code")
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

const (
	maxPublicStartBytes  = 4 << 10
	maxPublicSubmitBytes = 1 << 20
	maxPublicNameLen     = 120
	maxPublicEmailLen    = 254
	maxPublicPhoneLen    = 32
	// publicSubmitGrace absorbs network latency and clock skew between the
	// candidate's last click and the server deadline.
	publicSubmitGrace = 2 * time.Minute
	// publicTokenTTLAfterEnd is how long after the attempt's time limit the
	// token still opens the result page.
	publicTokenTTLAfterEnd = 24 * time.Hour
	attemptTokenHeader     = "X-Attempt-Token"
)

// attemptToken reads the candidate token from the X-Attempt-Token header. The
// legacy URL-path form is still accepted for one release and logged.
func attemptToken(r *http.Request) string {
	return strings.TrimSpace(r.Header.Get(attemptTokenHeader))
}

// tokenExpired reports whether the attempt token has outlived started_at +
// duration + 24h.
func tokenExpired(att PublicAttempt, a Assessment) bool {
	return time.Now().After(att.StartedAt.Add(time.Duration(a.DurationMinutes)*time.Minute + publicTokenTTLAfterEnd))
}

type startPublicAttemptRequest struct {
	Name  string  `json:"name"`
	Email string  `json:"email"`
	Phone *string `json:"phone,omitempty"`
}

// StartPublicAttempt creates a candidate session and returns questions.
// POST /api/p/{code}/start
func (h *Handler) StartPublicAttempt(w http.ResponseWriter, r *http.Request) {
	code := httputil.URLParam(r, "code")
	r.Body = http.MaxBytesReader(w, r.Body, maxPublicStartBytes)
	var req startPublicAttemptRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.TrimSpace(req.Email)
	fields := validatePublicCandidate(req)
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	a, err := h.repo.GetAssessmentByShortCode(r.Context(), code)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	if err := assertOpen(a); err != nil {
		writeDomainError(w, err)
		return
	}

	att, err := h.repo.CreatePublicAttempt(r.Context(), a.ID, req.Name, req.Email, req.Phone, a.MaxAttempts)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	questions, err := h.repo.ListAssessmentQuestions(r.Context(), a.ID, AssessmentQuestionFilter{})
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
// POST /api/p/{code}/submit with X-Attempt-Token
func (h *Handler) SubmitPublicAttempt(w http.ResponseWriter, r *http.Request) {
	code := httputil.URLParam(r, "code")
	token := attemptToken(r)

	r.Body = http.MaxBytesReader(w, r.Body, maxPublicSubmitBytes)
	var req submitPublicAttemptRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}

	a, err := h.repo.GetAssessmentByShortCode(r.Context(), code)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	pending, err := h.repo.GetPublicAttemptByToken(r.Context(), token)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	// The token must belong to this test (it is otherwise valid for any code),
	// and the server enforces the time limit the client only displays.
	if pending.AssessmentID != a.ID || tokenExpired(pending, a) {
		writeDomainError(w, ErrNotFound)
		return
	}
	if pending.Status != "submitted" && time.Now().After(pending.StartedAt.Add(time.Duration(a.DurationMinutes)*time.Minute+publicSubmitGrace)) {
		writeDomainError(w, ErrAttemptExpired)
		return
	}
	questions, err := h.repo.ListAssessmentQuestions(r.Context(), a.ID, AssessmentQuestionFilter{})
	if err != nil {
		writeDomainError(w, err)
		return
	}

	att, err := h.service.SubmitPublicAttempt(r.Context(), token, req.Answers, questions, a.PassPercentage)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"score":        att.Score,
		"max_score":    att.MaxScore,
		"percentage":   att.Percentage,
		"passed":       att.Passed,
		"duration_sec": att.DurationSec,
	})
}

// GetPublicResult returns the scored result for a candidate session.
// GET /api/p/{code}/result with X-Attempt-Token
func (h *Handler) GetPublicResult(w http.ResponseWriter, r *http.Request) {
	a, err := h.repo.GetAssessmentByShortCode(r.Context(), httputil.URLParam(r, "code"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	att, err := h.repo.GetPublicAttemptByToken(r.Context(), attemptToken(r))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if att.AssessmentID != a.ID || tokenExpired(att, a) {
		writeDomainError(w, ErrNotFound)
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

// validatePublicCandidate bounds and checks the candidate's self-reported
// identity before it is stored as PII.
func validatePublicCandidate(req startPublicAttemptRequest) map[string]string {
	fields := map[string]string{}
	if req.Name == "" {
		fields["name"] = "Name is required."
	} else if len(req.Name) > maxPublicNameLen {
		fields["name"] = "Name is too long."
	}
	if req.Email == "" {
		fields["email"] = "Email is required."
	} else if addr, err := mail.ParseAddress(req.Email); err != nil || addr.Address != req.Email || len(req.Email) > maxPublicEmailLen {
		fields["email"] = "Enter a valid email address."
	}
	if req.Phone != nil && len(*req.Phone) > maxPublicPhoneLen {
		fields["phone"] = "Phone number is too long."
	}
	return fields
}

type overridePublicAttemptRequest struct {
	Score float64 `json:"score"`
	Note  string  `json:"note"`
}

// OverridePublicCandidateScore lets staff manually adjust a hiring candidate's
// total score — e.g. spot-checking a sandbox-graded FastAPI/React submission's
// code quality on top of its pass/fail result. PATCH /api/assessments/{assessmentID}/candidates/{candidateID}/override
func (h *Handler) OverridePublicCandidateScore(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req overridePublicAttemptRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if req.Score < 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"score": "Score cannot be negative."})
		return
	}
	att, err := h.repo.OverridePublicAttemptScore(r.Context(), claims.OrgID,
		httputil.URLParam(r, "candidateID"), claims.UserID, req.Score, req.Note)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, att)
}

// GetPublicCandidates returns all candidate attempts for a hiring assessment (staff).
// GET /api/assessments/{assessmentID}/candidates
func (h *Handler) GetPublicCandidates(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := httputil.URLParam(r, "assessmentID")
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

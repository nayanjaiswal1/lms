package certificates

import (
	"encoding/json"
	"time"

	"github.com/mindforge/backend/internal/assessment"
)

// Question is one entry in a FinalTest's Questions array — a discriminated
// union over the same MCQ/coding content shapes the assessment domain
// already uses, so grading (assessment.GradeMCQ/GradeCoding) and the wire
// format are identical across both features rather than a third invention.
type Question struct {
	ID     string                    `json:"id"`
	Type   string                    `json:"type"` // "mcq" | "coding"
	Points float64                   `json:"points"`
	MCQ    *assessment.MCQContent    `json:"mcq,omitempty"`
	Coding *assessment.CodingContent `json:"coding,omitempty"`
}

const (
	QuestionMCQ    = "mcq"
	QuestionCoding = "coding"
)

// FinalTest is the one-per-course configuration an instructor authors.
type FinalTest struct {
	ID                  string     `json:"id"`
	CourseID            string     `json:"course_id"`
	Questions           []Question `json:"questions"`
	TimeLimitMinutes    int        `json:"time_limit_minutes"`
	PassingScorePercent int        `json:"passing_score_percent"`
	MaxAttempts         int        `json:"max_attempts"`
	CreatedAt           time.Time  `json:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

// Attempt is one learner's graded submission.
type Attempt struct {
	ID          string          `json:"id"`
	UserID      string          `json:"user_id"`
	FinalTestID string          `json:"final_test_id"`
	Answers     json.RawMessage `json:"answers"`
	Score       int             `json:"score"`
	Total       int             `json:"total"`
	Passed      bool            `json:"passed"`
	CompletedAt time.Time       `json:"completed_at"`
}

// Certificate is the issued, publicly-verifiable record of a passed final test.
type Certificate struct {
	ID                 string    `json:"id"`
	UserID             string    `json:"user_id"`
	CourseID           string    `json:"course_id"`
	FinalTestAttemptID string    `json:"final_test_attempt_id"`
	IssuedAt           time.Time `json:"issued_at"`
	CertUUID           string    `json:"cert_uuid"`
}

// CertificateView is what the "my certificates" list and the public
// verification page render — the course/learner names a bare Certificate
// row doesn't carry.
type CertificateView struct {
	Certificate
	CourseTitle string `json:"course_title"`
	LearnerName string `json:"learner_name"`
}

// ─── Request / Response ───────────────────────────────────────────────────────

// UpsertFinalTestRequest is the instructor authoring payload — PUT semantics,
// one final test per course.
type UpsertFinalTestRequest struct {
	Questions           []Question `json:"questions"`
	TimeLimitMinutes    int        `json:"time_limit_minutes"`
	PassingScorePercent int        `json:"passing_score_percent"`
	MaxAttempts         int        `json:"max_attempts"`
}

// SubmitAttemptRequest carries one raw answer payload per question ID —
// {"selected":[...]} for mcq, {"language":..,"code":..} for coding, matching
// assessment.GradeMCQ/GradeCoding's expected wire format exactly.
type SubmitAttemptRequest struct {
	Answers map[string]json.RawMessage `json:"answers"`
}

// SubmitAttemptResponse returns the graded attempt plus the certificate, if
// this submission just earned one.
type SubmitAttemptResponse struct {
	Attempt     Attempt      `json:"attempt"`
	Certificate *Certificate `json:"certificate,omitempty"`
}

// StudentQuestion is a Question with every server-only grading field
// stripped — never send MCQOption.IsCorrect, hidden TestCase content, or
// CodingContent.VerifyFiles/VerifyCommand to the client.
type StudentQuestion struct {
	ID     string                    `json:"id"`
	Type   string                    `json:"type"`
	Points float64                   `json:"points"`
	MCQ    *assessment.MCQContent    `json:"mcq,omitempty"`
	Coding *assessment.CodingContent `json:"coding,omitempty"`
}

// StudentFinalTest is what GET /api/courses/:id/final-test returns — no
// answer keys, no hidden test cases.
type StudentFinalTest struct {
	ID                  string            `json:"id"`
	CourseID            string            `json:"course_id"`
	Questions           []StudentQuestion `json:"questions"`
	TimeLimitMinutes    int               `json:"time_limit_minutes"`
	PassingScorePercent int               `json:"passing_score_percent"`
	MaxAttempts         int               `json:"max_attempts"`
	AttemptsUsed        int               `json:"attempts_used"`
	AlreadyPassed       bool              `json:"already_passed"`
	CertUUID            *string           `json:"cert_uuid,omitempty"`
}

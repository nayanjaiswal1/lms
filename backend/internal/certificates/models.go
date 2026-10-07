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
	ID           string          `json:"id"`
	UserID       string          `json:"user_id"`
	AssessmentID string          `json:"assessment_id"`
	Answers      json.RawMessage `json:"answers"`
	Score        int             `json:"score"`
	Total        int             `json:"total"`
	Passed       bool            `json:"passed"`
	CompletedAt  time.Time       `json:"completed_at"`
}

// Certificate issue-type values — how a given row came to exist.
const (
	IssueTypeFinalTest = "final_test" // learner passed the course's final test
	IssueTypeManual    = "manual"     // a mentor/instructor/admin awarded it directly
	IssueTypeThreshold = "threshold"  // learner crossed the course's configured completion threshold
	// IssueTypeProjectCompletion is Project Workspace's additive sibling
	// (contract-phase5.md 5b): a project owner awarding a member a
	// certificate for their work on a completed Project Workspace project,
	// never tied to a course_id (see project_id below).
	IssueTypeProjectCompletion = "project_completion"
)

// Certificate is the issued, publicly-verifiable record of completion — via
// a passed final test, a mentor's manual award, a crossed completion
// threshold (see IssueType), or (additively) a completed Project Workspace
// project. Exactly one of CourseID/ProjectID is set, never both — enforced
// by the certificates_course_xor_project CHECK (migration 041).
type Certificate struct {
	ID                  string    `json:"id"`
	UserID              string    `json:"user_id"`
	CourseID            string    `json:"course_id,omitempty"`
	ProjectID           *string   `json:"project_id,omitempty"`
	AssessmentAttemptID *string   `json:"assessment_attempt_id,omitempty"`
	IssuedAt            time.Time `json:"issued_at"`
	CertUUID            string    `json:"cert_uuid"`
	IssueType           string    `json:"issue_type"`
	IssuedBy            *string   `json:"issued_by,omitempty"`
	// Note is only set for IssueTypeProjectCompletion — the issuing owner's
	// short write-up of the member's contribution (contract-phase5.md's
	// IssueCertificateRequest.ExperienceNote).
	Note *string `json:"note,omitempty"`
}

// CertificateView is what the "my certificates" list and the public
// verification page render — the course/learner names a bare Certificate
// row doesn't carry.
type CertificateView struct {
	Certificate
	CourseTitle string `json:"course_title"`
	LearnerName string `json:"learner_name"`
}

// PublicCertificate is the minimal no-auth verification payload: no internal
// user, course or attempt IDs.
type PublicCertificate struct {
	CertUUID    string    `json:"cert_uuid"`
	CourseTitle string    `json:"course_title"`
	LearnerName string    `json:"learner_name"`
	IssuedAt    time.Time `json:"issued_at"`
	IssueType   string    `json:"issue_type"`
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

// IssueCertificateRequest is the mentor/instructor/admin manual-award
// payload for POST /api/courses/:id/certificates/issue.
type IssueCertificateRequest struct {
	StudentID string `json:"student_id"`
}

// UpsertCertificateRuleRequest is the instructor authoring payload for the
// threshold-based auto-issue rule — PUT semantics, one rule per course.
type UpsertCertificateRuleRequest struct {
	ThresholdPercent int `json:"threshold_percent"`
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

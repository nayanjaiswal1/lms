// Package revisionplan generates an AI-built, per-(user, course) revision
// plan once a learner finishes a course: ranked weak topics with a concrete
// recommendation for each, grounded in that learner's actual performance
// signals in the course (their knowledge-check accuracy per lesson and their
// own free-text lesson reflections — see internal/courses' lesson_reflections
// and lesson_check_attempts tables) rather than a generic "review everything"
// list. Generation is async, mirroring internal/roadmap's shell-then-job
// pattern: a row is created with status "generating" immediately, a
// background job (internal/jobs/handlers/llm.go, task
// "revision_plan_generate") does the AI call, and the row flips to "ready" or
// "failed".
package revisionplan

import (
	"errors"
	"time"
)

const (
	StatusGenerating = "generating"
	StatusReady      = "ready"
	StatusFailed     = "failed"
)

var ErrNotFound = errors.New("revisionplan: not found")

// RevisionPlan is one learner's AI-generated post-course revision plan.
type RevisionPlan struct {
	ID              string     `json:"id"`
	UserID          string     `json:"-"`
	CourseID        string     `json:"course_id"`
	OrgID           string     `json:"-"`
	Status          string     `json:"status"`
	GenerationError *string    `json:"generation_error,omitempty"`
	GeneratedAt     *time.Time `json:"generated_at"`
	Topics          []Topic    `json:"topics,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

// Topic is one weak-area entry in a RevisionPlan, ranked by Priority
// (1 = revisit first, 5 = lowest priority). ModuleID links back to the
// specific lesson this topic came from when the AI could attribute it to
// one; it is nil when the AI named a broader theme spanning multiple lessons,
// or when the AI's claimed module_id didn't match a real module in the
// course (see ParseTopics — a hallucinated id is dropped, never inserted).
type Topic struct {
	ID             string  `json:"id"`
	ModuleID       *string `json:"module_id,omitempty"`
	Title          string  `json:"title"`
	Reason         string  `json:"reason"`
	Recommendation string  `json:"recommendation"`
	Priority       int     `json:"priority"`
	Position       int     `json:"position"`
}

// CourseSignals is the aggregated per-user, per-course performance data fed
// into the AI prompt — the only data the generator is allowed to reason from.
type CourseSignals struct {
	CourseTitle string
	Modules     []ModuleSignal
}

// ModuleSignal is one lesson's worth of signal. Only lessons with at least
// one knowledge-check attempt or a written reflection are included (see
// Repo.GatherSignals) — untouched lessons carry no signal worth reporting.
type ModuleSignal struct {
	ModuleID             string
	Title                string
	SectionTitle         string
	Reflection           string
	QuestionsTotal       int // distinct knowledge-check questions attempted in this lesson
	QuestionsEverCorrect int // distinct questions answered correctly at least once
	WrongAttempts        int // total incorrect attempts across this lesson (retries signal struggle even if eventually correct)
}

// Package activity aggregates existing per-domain timestamps (module/course
// completions, quiz attempts, MCP-logged reflections, sheet problems solved,
// lab completions, SM-2 flashcard reviews) into one read-only, reverse-
// chronological feed — "what did I do, and when" — for the dashboard widget
// and the /activity page. It owns no writes and no tables of its own beyond
// what srs.ReviewCard already writes to srs_reviews; every source table is
// written by its own domain package as it always was.
package activity

import "time"

// Kind identifies which domain an Entry came from — drives the icon/label
// the frontend renders and, for "reflection", the AI-tinted surface (it's
// the only kind ever written by the MCP connector rather than the student
// acting directly).
const (
	KindModuleCompleted = "module_completed"
	KindCourseCompleted = "course_completed"
	KindQuizAttempt     = "quiz_attempt"
	KindReflection      = "reflection"
	KindSheetSolved     = "sheet_problem_solved"
	KindLabCompleted    = "lab_completed"
	KindCardReviewed    = "card_reviewed"
)

// Entry is one row in the timeline.
type Entry struct {
	Key        string    `json:"key"` // "<kind>:<source row id>" — unique, cursor tiebreak, React key
	Kind       string    `json:"kind"`
	OccurredAt time.Time `json:"occurred_at"`
	Day        string    `json:"day"` // YYYY-MM-DD in the requester's tz offset (see repo.go List)
	Title      string    `json:"title"`
	Summary    string    `json:"summary,omitempty"`
	RefID      string    `json:"ref_id,omitempty"`
	RefType    string    `json:"ref_type,omitempty"`
	RefSlug    string    `json:"ref_slug,omitempty"` // course slug, for deep links
}

// Page is one paginated response.
type Page struct {
	Entries    []Entry `json:"entries"`
	NextCursor string  `json:"next_cursor,omitempty"`
}

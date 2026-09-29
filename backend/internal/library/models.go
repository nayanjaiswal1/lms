// Package library implements "Add from library" — Part 3 of
// docs/debug-labs.md: a course-builder search over the org's (plus
// platform-shared) labs, quizzes, and notes lessons, with one shared insert
// path (Attach) that places a reference or a copy into a course section.
//
// It imports courses, labs, and assessment rather than living inside any of
// them because labs already imports courses (for CompleteModule) — a
// course_modules insert helper reused by both couldn't live in either
// package without an import cycle. See docs/debug-labs.md L0.
package library

import "time"

// Kinds of item the library can list/attach. KindDebug is a lab whose
// lab_type belongs to a pluggable lab kind (backend/internal/labkinds) — it is
// still a lab_definitions row, placed/previewed/tried exactly like KindLab,
// but listed separately so it can carry stack/category/difficulty filters.
const (
	KindLab   = "lab"
	KindDebug = "debug"
	KindQuiz  = "quiz"
	KindNotes = "notes"
)

var validKinds = map[string]bool{KindLab: true, KindDebug: true, KindQuiz: true, KindNotes: true}

// isLabKind reports whether kind resolves to a lab_definitions row.
func isLabKind(kind string) bool { return kind == KindLab || kind == KindDebug }

// Item is one row of the unified library listing — a lab, a quiz, or a notes
// lesson, projected to a common shape. Mode tells the picker UI whether
// "Add" will reference the source (lab/quiz) or copy it (notes) — see
// docs/debug-labs.md L1.
type Item struct {
	Kind        string    `json:"kind"`
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description *string   `json:"description,omitempty"`
	Mode        string    `json:"mode"` // "reference" | "copy"
	Platform    bool      `json:"platform"`
	CreatedAt   time.Time `json:"created_at"`
}

const (
	ModeReference = "reference"
	ModeCopy      = "copy"
)

// ItemPage is a cursor-paginated page of Item — the same envelope shape as
// backend/internal/pagination's other callers (orgs members/invites).
type ItemPage struct {
	Items      []Item `json:"items"`
	NextCursor string `json:"next_cursor,omitempty"`
}

// ListFilter narrows GET /api/library.
type ListFilter struct {
	Kinds  []string // empty = all kinds
	Search string
	Cursor string
	Limit  int
	// Stack/Category/Difficulty filter labs by lab_catalog_meta (empty = any).
	Stack, Category, Difficulty string
}

// AttachReq is library.Service.Attach's input — docs/debug-labs.md L3.
type AttachReq struct {
	SectionID string
	// Position is the 0-based index to insert at; existing modules at or
	// after it shift down by one. nil = append after the section's last
	// module (Phase A's course-builder integration always appends — see
	// docs/debug-labs.md's L5 deviation note in the final report; a future
	// per-slot "+" UI would pass an explicit index here without any backend
	// change).
	Position *int
	Kind     string
	ItemID   string
	// Title overrides the placed module's title (defaults to the source
	// item's own title) — lets an instructor rename a placement without
	// renaming the shared source.
	Title *string
	// IsRequired only applies to kind=lab; ignored for quiz/notes.
	IsRequired bool
}

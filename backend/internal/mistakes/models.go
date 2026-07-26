// Package mistakes implements the Mistake & Progress Ledger: a first-class,
// timestamped event log for student mistakes (tense, articles, spelling,
// etc.), separate from course modules (static content) and from
// courses.LessonReflection (free-text understanding notes). Trend,
// recurrence, and per-category counts are derived at read time from this one
// table — a single learner's ledger is a few hundred to a few thousand rows,
// not an analytics-at-scale dataset, so a materialized snapshot would cost
// more in staleness than it saves in query time. Spaced revision reuses
// internal/srs's existing SM-2 engine (source_type="mistake") rather than a
// second scheduler.
package mistakes

import (
	"errors"
	"time"
)

var ErrNotFound = errors.New("mistakes: not found")

const (
	CategoryTense                = "tense"
	CategoryArticle              = "article"
	CategoryPreposition          = "preposition"
	CategorySubjectVerbAgreement = "subject_verb_agreement"
	CategorySpelling             = "spelling"
	CategorySentenceFragment     = "sentence_fragment"
	CategoryRunOn                = "run_on"
	CategoryVocabulary           = "vocabulary"
	CategoryPunctuation          = "punctuation"
	CategoryOther                = "other"
)

// ValidCategories is the same list as the mistake_entries_category_check DB
// constraint, exposed for handler/MCP-tool input validation so a bad value
// surfaces as a clean 422/tool-error instead of a raw constraint-violation
// wrapped into a generic 500.
var ValidCategories = map[string]bool{
	CategoryTense:                true,
	CategoryArticle:              true,
	CategoryPreposition:          true,
	CategorySubjectVerbAgreement: true,
	CategorySpelling:             true,
	CategorySentenceFragment:     true,
	CategoryRunOn:                true,
	CategoryVocabulary:           true,
	CategoryPunctuation:          true,
	CategoryOther:                true,
}

// Status is derived at read time, never stored (see Repo.List): "new" is the
// first-ever row for a (category, sub_topic) pair, "recurring"/"improving"
// compare the gap before the latest occurrence against the gap before that,
// and "resolved" reflects the one fact a query can't infer — a user or their
// AI explicitly saying "I've got this" (Entry.ResolvedAt).
const (
	StatusNew       = "new"
	StatusRecurring = "recurring"
	StatusImproving = "improving"
	StatusResolved  = "resolved"
)

// Entry is one mistake event.
type Entry struct {
	ID             string     `json:"id"`
	UserID         string     `json:"-"`
	Category       string     `json:"category"`
	SubTopic       string     `json:"sub_topic"`
	OriginalText   string     `json:"original_text"`
	CorrectedText  string     `json:"corrected_text"`
	ContextTag     *string    `json:"context_tag,omitempty"`
	SourceModuleID *string    `json:"source_module_id,omitempty"`
	ResolvedAt     *time.Time `json:"resolved_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	Status         string     `json:"status"`
}

// LogRequest is the input for logging a new mistake.
type LogRequest struct {
	Category       string  `json:"category"`
	SubTopic       string  `json:"sub_topic"`
	OriginalText   string  `json:"original_text"`
	CorrectedText  string  `json:"corrected_text"`
	ContextTag     *string `json:"context_tag,omitempty"`
	SourceModuleID *string `json:"source_module_id,omitempty"`
}

// ListFilter narrows GET /api/mistakes / get_mistake_history.
type ListFilter struct {
	Category   *string
	ContextTag *string
	From       *time.Time
	To         *time.Time
}

// CategorySummary is one row of the per-category dashboard/chart data.
type CategorySummary struct {
	Category        string    `json:"category"`
	Total           int       `json:"total"`
	FirstOccurredAt time.Time `json:"first_occurred_at"`
	LastOccurredAt  time.Time `json:"last_occurred_at"`
	// Trend compares occurrence counts in the last 7 days against the 7 days
	// before that — "worsening", "stable", or "improving".
	Trend string `json:"trend"`
}

const (
	TrendWorsening = "worsening"
	TrendStable    = "stable"
	TrendImproving = "improving"
)

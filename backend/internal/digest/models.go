// Package digest builds the nightly AI revision-digest email: one plain-text
// (optionally AI-narrated) recap per student per night, combining that
// night's learning activity, any 3-day/weekly/monthly spaced-repetition
// windows that close the same night, and any due SRS flashcards, capped at
// one email per user per calendar day (see revision_digests' UNIQUE(user_id,
// digest_date) in migration 002_revision_digest.sql). It reads from — and
// never duplicates — internal/activity (notes, reflections, mistakes,
// completions), internal/sheets (spaced-repetition problem tracker), and
// internal/srs (spaced-repetition flashcards; formerly its own separate
// "Cards due for review" email, folded in here so a student gets one nightly
// email, not two) rather than owning its own copy of that data.
package digest

import (
	"time"

	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/sheets"
	"github.com/mindforge/backend/internal/srs"
)

// Cadence identifies which revision window a digest is covering. A single
// digest can carry more than one — see MergeCadences — since the 1-email/day
// cap means a night where both "daily" and "weekly" close must produce one
// merged email, never two.
type Cadence string

const (
	CadenceDaily   Cadence = "daily"
	CadenceD3      Cadence = "d3"
	CadenceWeekly  Cadence = "weekly"
	CadenceMonthly Cadence = "monthly"
)

// PeriodDays is how many days of history this cadence covers, used by
// WindowFor to size the lookback query.
func (c Cadence) PeriodDays() int {
	switch c {
	case CadenceD3:
		return 3
	case CadenceWeekly:
		return 7
	case CadenceMonthly:
		return 30
	default: // CadenceDaily and any unrecognized value
		return 1
	}
}

// AI generation status recorded on every revision_digests row — never just
// "sent" vs "not sent", since a budget cap or provider outage still sends
// the deterministic fallback content (see render.go).
const (
	AIStatusGenerated          = "generated"
	AIStatusSkippedBudget      = "skipped_budget"
	AIStatusSkippedUnavailable = "skipped_unavailable"
	AIStatusFailed             = "failed"
)

// Digest is one user's one-per-night revision digest — the in-memory shape
// that repo.InsertDigest persists as one revision_digests row.
type Digest struct {
	UserID       string
	OrgID        string
	DigestDate   string // YYYY-MM-DD, the user's local calendar date
	Cadences     []Cadence
	WindowStart  time.Time
	WindowEnd    time.Time
	AIStatus     string
	Model        string
	InputTokens  int
	OutputTokens int
	CostUSD      float64
	Subject      string
	Body         string
}

// Sources bundles everything gathered for one digest — the only data the AI
// prompt (PromptContext) and the deterministic fallback (Render) are allowed
// to draw from, mirroring internal/revisionplan's CourseSignals rule that
// the generator never reasons beyond what was actually gathered.
type Sources struct {
	Activity    []activity.Entry
	NextTasks   []sheets.SheetItem
	DueCards    []srs.Card
	Cadences    []Cadence
	WindowStart time.Time
	WindowEnd   time.Time
}

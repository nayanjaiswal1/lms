package workspace

import (
	"errors"
	"time"
)

// Phase 5 — releases, sprints, completion, peer feedback, member report,
// AI suggestions, CSV export. Lead-owned.

const (
	ReleasePlanned  = "planned"
	ReleaseFrozen   = "frozen"
	ReleaseReleased = "released"

	SprintPlanned   = "planned"
	SprintActive    = "active"
	SprintCompleted = "completed"

	// FeedbackWindow duplicated service_project.go's own CompletionFeedbackWindow
	// (Phase 1) at the same 14-day value — removed in favor of that single
	// constant (CLAUDE.md's DRY rule) rather than keeping two names for one
	// duration; see service_project.go's SetProjectStatus for where it's used.
	FeedbackMinRaters     = 3
	FeedbackCommentMaxLen = 2000
	SprintMaxDays         = 28
	SprintNameMaxLen      = 80
	ReleaseVersionMaxLen  = 40
	ExperienceNoteMaxLen  = 2000
	ExportKindItems       = "items"
	ExportKindTimeLogs    = "time_logs"
	ExportKindMembers     = "members"
)

// ReleaseStatusMachine: planned → frozen → released (design §13).
var ReleaseStatusMachine = newMachine(map[string][]string{
	ReleasePlanned: {ReleaseFrozen},
	ReleaseFrozen:  {ReleasePlanned, ReleaseReleased},
})

// SprintStatusMachine: planned → active → completed.
var SprintStatusMachine = newMachine(map[string][]string{
	SprintPlanned: {SprintActive},
	SprintActive:  {SprintCompleted},
})

var (
	ErrReleaseFrozen    = errors.New("this release is frozen — only bugs can be added")
	ErrReleaseNotReady  = errors.New("every targeted feature must be done or moved to another release first")
	ErrSprintsDisabled  = errors.New("sprints are turned off for this project")
	ErrSprintOverlap    = errors.New("sprints can't overlap")
	ErrFeedbackClosed   = errors.New("the peer feedback window is closed")
	ErrNoSharedWork     = errors.New("you can only rate teammates you worked with on at least one item")
	ErrCompleteBlocked  = errors.New("finish, move to backlog or close every in-progress, in-review and testing item first")
	ErrUnfinishedChoice = errors.New("choose carry-over or backlog for the unfinished items")
)

type Release struct {
	ID         string     `json:"id"`
	Version    string     `json:"version"`
	Status     string     `json:"status"`
	TargetAt   *time.Time `json:"target_at"`
	FrozenAt   *time.Time `json:"frozen_at"`
	ReleasedAt *time.Time `json:"released_at"`
	CreatedBy  *string    `json:"created_by"`
	CreatedAt  time.Time  `json:"created_at"`
	// Rollup
	FeaturesDone  int `json:"features_done"`
	FeaturesTotal int `json:"features_total"`
	OpenBugs      int `json:"open_bugs"`
}

type CreateReleaseRequest struct {
	Version  string     `json:"version"`
	TargetAt *time.Time `json:"target_at"`
}

type UpdateReleaseRequest struct {
	Version     *string    `json:"version"`
	TargetAt    *time.Time `json:"target_at"`
	ClearTarget bool       `json:"clear_target"`
	Status      *string    `json:"status"` // frozen | planned | released
}

// SetItemReleaseRequest / SetItemSprintRequest target an item (nil clears).
type SetItemReleaseRequest struct {
	Version   int     `json:"version"`
	ReleaseID *string `json:"release_id"`
}

type SetItemSprintRequest struct {
	Version  int     `json:"version"`
	SprintID *string `json:"sprint_id"`
}

type ReleaseNotes struct {
	ReleaseID string            `json:"release_id"`
	Items     []ReleaseNoteItem `json:"items"`
	Polished  *string           `json:"polished"` // cached AI text, suggest-only
}

type ReleaseNoteItem struct {
	Item       ItemRef `json:"item"`
	DocVersion *int    `json:"doc_version"`
}

type Sprint struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	StartsOn  string     `json:"starts_on"`
	EndsOn    string     `json:"ends_on"`
	Status    string     `json:"status"`
	CreatedAt time.Time  `json:"created_at"`
	Committed int        `json:"committed"`
	Done      int        `json:"done"`
	Burndown  []DayPoint `json:"burndown,omitempty"`
}

type CreateSprintRequest struct {
	Name     string `json:"name"`
	StartsOn string `json:"starts_on"`
	EndsOn   string `json:"ends_on"`
}

// CloseSprintRequest: unfinished items go to NextSprintID (carry-over) or
// back to the backlog — never silently (design §11).
type CloseSprintRequest struct {
	Unfinished   string  `json:"unfinished"` // carry_over | backlog
	NextSprintID *string `json:"next_sprint_id"`
}

type PeerFeedbackRequest struct {
	ToUserID string  `json:"to_user_id"`
	Rating   int     `json:"rating"`
	Comment  *string `json:"comment"`
}

// PeerFeedbackRow is an individual rating — owner/overseer only.
type PeerFeedbackRow struct {
	FromUser  PersonRef `json:"from_user"`
	ToUser    PersonRef `json:"to_user"`
	Rating    int       `json:"rating"`
	Comment   *string   `json:"comment"`
	CreatedAt time.Time `json:"created_at"`
}

// MyFeedback is what the rated member sees: average + comments only after
// the window closes AND ≥3 distinct raters; no rater ids or timestamps,
// comments sorted by text (02 §7.1).
type MyFeedback struct {
	Available bool     `json:"available"`
	Average   *float64 `json:"average,omitempty"`
	Comments  []string `json:"comments,omitempty"`
}

// FeedbackView is GET …/feedback.
type FeedbackView struct {
	WindowClosesAt *time.Time        `json:"window_closes_at"`
	Open           bool              `json:"open"`
	Rateable       []PersonRef       `json:"rateable"`
	Given          []PeerFeedbackRow `json:"given"`
	Mine           MyFeedback        `json:"mine"`
	All            []PeerFeedbackRow `json:"all,omitempty"` // owner/overseer only
}

// MemberReport is the auto-built outcome report (design §15).
type MemberReport struct {
	Person           PersonRef `json:"person"`
	Role             string    `json:"role"`
	ItemsOwned       int       `json:"items_owned"`
	ItemsDoneOwned   int       `json:"items_done_owned"`
	ItemsReviewed    int       `json:"items_reviewed"`
	ItemsTested      int       `json:"items_tested"`
	ReopensCaused    int       `json:"reopens_caused"`
	DocApprovals     int       `json:"doc_approvals"`
	MRsOpened        int       `json:"mrs_opened"`
	MRsMerged        int       `json:"mrs_merged"`
	ReviewComments   int       `json:"review_comments"`
	MinutesLogged    int       `json:"minutes_logged"`
	MeetingsAttended int       `json:"meetings_attended"`
	MeetingsMissed   int       `json:"meetings_missed"`
	StandupsPosted   int       `json:"standups_posted"`
	PeerRating       *float64  `json:"peer_rating"` // owner view, or own after the ≥3 rule
	ShowcaseOptIn    bool      `json:"showcase_opt_in"`
	CertificateID    *string   `json:"certificate_id"`
}

type IssueCertificateRequest struct {
	UserID         string `json:"user_id"`
	ExperienceNote string `json:"experience_note"`
}

// ─── AI suggestions (suggest-only; a human confirms every write) ─────────────

type SuggestedItem struct {
	Type        string `json:"type"`
	Title       string `json:"title"`
	Description string `json:"description"`
}

type ItemSuggestions struct {
	Items    []SuggestedItem `json:"items"`
	CachedAt time.Time       `json:"cached_at"`
}

type AssigneeSuggestion struct {
	Person PersonRef `json:"person"`
	WIP    int       `json:"wip"`
	Reason string    `json:"reason"`
}

type LateExplanation struct {
	Explanation string    `json:"explanation"`
	CachedAt    time.Time `json:"cached_at"`
}

type ChangeImpact struct {
	AffectedItemIDs []string  `json:"affected_item_ids"`
	Summary         string    `json:"summary"`
	CachedAt        time.Time `json:"cached_at"`
}

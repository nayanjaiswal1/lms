package workspace

import (
	"errors"
	"time"
)

// Phase 2 — work items (Epic → Feature → Task/Bug → Subtask). Lead-owned.

// Event kinds and sources for work_item_events (037 CHECKs).
const (
	EventCreate   = "create"
	EventStatus   = "status"
	EventField    = "field"
	EventAssign   = "assign"
	EventUnassign = "unassign"
	EventLink     = "link"
	EventUnlink   = "unlink"
	EventParent   = "parent"
	EventSeverity = "severity"
	EventDoc      = "doc"
	EventReview   = "review"
	EventSprint   = "sprint"
	EventRelease  = "release"
	EventArchive  = "archive"

	SourceUser   = "user"
	SourceGitlab = "gitlab"
	SourceSystem = "system"
)

var (
	ItemPriorities = []string{"low", "medium", "high", "urgent"}
	BugSeverities  = []string{"S1", "S2", "S3", "S4"}
)

const (
	ItemTitleMaxLen       = 300
	ItemDescriptionMaxLen = 50000
	ReasonMaxLen          = 2000
	SimilarQueryMaxLen    = 200
	SimilarLimit          = 5
	// SimilarityThreshold is applied with SET LOCAL pg_trgm.similarity_threshold
	// so `title % $q` can use idx_work_items_title_trgm (01 §4 Dedup).
	SimilarityThreshold = 0.4
)

// Phase 2 sentinel errors.
var (
	ErrStaleVersion         = errors.New("this item was changed by someone else — reload to see the latest version")
	ErrIllegalHierarchy     = errors.New("that parent/child type combination is not allowed")
	ErrIllegalTransition    = errors.New("that status change is not allowed from the current status")
	ErrBlockedByOpen        = errors.New("an open blocking item must be finished first")
	ErrWipLimit             = errors.New("WIP limit reached — finish or hand off an in-progress item first")
	ErrLinkCycle            = errors.New("that blocks link would create a cycle")
	ErrSoD                  = errors.New("separation of duties: you can't review, approve or test your own work")
	ErrBriefNotAgreed       = errors.New("the project brief isn't agreed yet — items can't move past todo")
	ErrDocNotApproved       = errors.New("the feature spec isn't approved yet")
	ErrOnboardingIncomplete = errors.New("finish the required onboarding steps before taking work")
	ErrNotDeletable         = errors.New("only todo items with no history can be deleted — archive it instead")
	ErrReasonRequired       = errors.New("a reason is required for this change")
	ErrTrackLeaderless      = errors.New("this track has no lead — a manager must assign one before new assignments")
)

// WorkItem is one work_items row. Key is "{key_prefix}-{key_num}".
type WorkItem struct {
	ID        string  `json:"id"`
	ProjectID string  `json:"project_id"`
	Key       string  `json:"key"`
	KeyNum    int     `json:"key_num"`
	Type      string  `json:"type"`
	ParentID  *string `json:"parent_id"`
	EpicID    *string `json:"epic_id"`
	FeatureID *string `json:"feature_id"`
	TrackID   *string `json:"track_id"`
	// ReleaseID/SprintID are set via the dedicated PUT …/release and
	// …/sprint endpoints (service_release.go/service_sprint.go), never via
	// Create/UpdateWorkItemRequest — see contract-phase5.md's route table.
	ReleaseID          *string    `json:"release_id"`
	SprintID           *string    `json:"sprint_id"`
	Title              string     `json:"title"`
	Description        *string    `json:"description"`
	Status             string     `json:"status"`
	Priority           string     `json:"priority"`
	Severity           *string    `json:"severity"`
	IsRegression       bool       `json:"is_regression"`
	EstimateMinutes    *int       `json:"estimate_minutes"`
	DocWikiPageID      *string    `json:"doc_wiki_page_id"`
	DocStatus          *string    `json:"doc_status"`
	ApprovedDocVersion *int       `json:"approved_doc_version"`
	SpecChangedAt      *time.Time `json:"spec_changed_at"`
	BlockedReason      *string    `json:"blocked_reason"`
	ReopenCount        int        `json:"reopen_count"`
	Version            int        `json:"version"`
	DueAt              *time.Time `json:"due_at"`
	CreatedBy          *string    `json:"created_by"`
	ArchivedAt         *time.Time `json:"archived_at"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
	// Assignees is filled on list and detail reads.
	Assignees []Assignee `json:"assignees"`
}

// Assignee is one work_item_assignees row with the user's name.
type Assignee struct {
	UserID     string    `json:"user_id"`
	Name       string    `json:"name"`
	Role       string    `json:"role"`
	AssignedBy *string   `json:"assigned_by"`
	AssignedAt time.Time `json:"assigned_at"`
}

// ItemRef is a compact item pointer used in links, parents and children.
type ItemRef struct {
	ID     string `json:"id"`
	Key    string `json:"key"`
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status string `json:"status"`
}

// ItemLink is one work_item_links row seen from the item being viewed:
// Direction "outgoing" = this item → Other, "incoming" = Other → this item.
type ItemLink struct {
	Kind      string    `json:"kind"`
	Direction string    `json:"direction"`
	Other     ItemRef   `json:"other"`
	CreatedBy *string   `json:"created_by"`
	CreatedAt time.Time `json:"created_at"`
}

// ItemEvent is one work_item_events row with the actor's name ("Former
// member" when the user row is gone).
type ItemEvent struct {
	ID        int64     `json:"id"`
	ItemID    string    `json:"item_id"`
	ActorID   *string   `json:"actor_id"`
	ActorName string    `json:"actor_name"`
	Source    string    `json:"source"`
	Kind      string    `json:"kind"`
	Field     *string   `json:"field"`
	FromValue *string   `json:"from_value"`
	ToValue   *string   `json:"to_value"`
	Reason    *string   `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

// ItemDetail is GET …/items/{itemID}: the item, its neighbourhood and the
// status changes the caller may make right now (04 §4 — the client renders
// only these, the server re-checks on submit).
type ItemDetail struct {
	WorkItem
	Parent           *ItemRef   `json:"parent"`
	Children         []ItemRef  `json:"children"`
	Links            []ItemLink `json:"links"`
	LegalTransitions []string   `json:"legal_transitions"`
	// LockedTransitions are machine-legal moves the caller can't make yet,
	// with the reason (e.g. doc gate) so the UI shows a lock, not nothing.
	LockedTransitions map[string]string `json:"locked_transitions"`
	CanEdit           bool              `json:"can_edit"`
	CanDelete         bool              `json:"can_delete"`
}

// SimilarItem is one duplicate-check hit.
type SimilarItem struct {
	ID         string  `json:"id"`
	Key        string  `json:"key"`
	Title      string  `json:"title"`
	Type       string  `json:"type"`
	Status     string  `json:"status"`
	Similarity float64 `json:"similarity"`
}

// ItemFilter is the GET …/items query (all optional).
type ItemFilter struct {
	Type            string
	Status          string
	TrackID         string
	AssigneeID      string
	ParentID        string
	FeatureID       string
	EpicID          string
	ReleaseID       string
	SprintID        string
	Q               string
	IncludeArchived bool
	Cursor          string
	Limit           int
}

// ─── Requests ─────────────────────────────────────────────────────────────────

// CreateWorkItemRequest is POST …/items.
type CreateWorkItemRequest struct {
	Type            string     `json:"type"`
	ParentID        *string    `json:"parent_id"`
	TrackID         *string    `json:"track_id"`
	Title           string     `json:"title"`
	Description     *string    `json:"description"`
	Priority        string     `json:"priority"`
	Severity        *string    `json:"severity"`
	EstimateMinutes *int       `json:"estimate_minutes"`
	DueAt           *time.Time `json:"due_at"`
}

// CreateWorkItemResult returns the created item plus near-duplicates found
// at create time (non-blocking; the UI offers "link as duplicate").
type CreateWorkItemResult struct {
	Item    WorkItem      `json:"item"`
	Similar []SimilarItem `json:"similar"`
}

// UpdateWorkItemRequest is PATCH …/items/{itemID}; Version is required
// (optimistic lock — a stale version gets 409 with the current row).
type UpdateWorkItemRequest struct {
	Version         int        `json:"version"`
	Title           *string    `json:"title"`
	Description     *string    `json:"description"`
	Priority        *string    `json:"priority"`
	Severity        *string    `json:"severity"`
	IsRegression    *bool      `json:"is_regression"`
	EstimateMinutes *int       `json:"estimate_minutes"`
	ClearEstimate   bool       `json:"clear_estimate"`
	DueAt           *time.Time `json:"due_at"`
	ClearDueAt      bool       `json:"clear_due_at"`
	TrackID         *string    `json:"track_id"`
	ClearTrack      bool       `json:"clear_track"`
}

// MoveWorkItemRequest is POST …/items/{itemID}/move (ParentID nil = root).
type MoveWorkItemRequest struct {
	Version  int     `json:"version"`
	ParentID *string `json:"parent_id"`
}

// TransitionRequest is POST …/items/{itemID}/transition. Blocked needs a
// reason and a blocker (D11: the blocked transition references a blocks
// link); wont_do needs a reason; testing→reopened needs a reason (tester's note).
type TransitionRequest struct {
	Version       int     `json:"version"`
	To            string  `json:"to"`
	Reason        *string `json:"reason"`
	BlockerItemID *string `json:"blocker_item_id"`
}

// AssigneeInput is one desired assignee in PUT …/assignees.
type AssigneeInput struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
}

// SetAssigneesRequest is PUT …/items/{itemID}/assignees: the full desired
// set; the service diffs it against the current rows.
type SetAssigneesRequest struct {
	Assignees []AssigneeInput `json:"assignees"`
}

// CreateLinkRequest is POST …/items/{itemID}/links (this item = from).
type CreateLinkRequest struct {
	ToItemID string `json:"to_item_id"`
	Kind     string `json:"kind"`
}

// ConflictError carries the current row for a 409 so the UI can show "yours
// vs current" (D17). Unwraps to ErrStaleVersion.
type ConflictError struct {
	Current *WorkItem
}

func (e *ConflictError) Error() string { return ErrStaleVersion.Error() }
func (e *ConflictError) Unwrap() error { return ErrStaleVersion }

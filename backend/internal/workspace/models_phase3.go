package workspace

import (
	"errors"
	"time"
)

// Phase 3 — requirement clarification, brief sign-off, feature-spec gate,
// bug triage, meetings and standups. Lead-owned.

const (
	QuestionMinLen      = 5
	QuestionMaxLen      = 2000
	AnswerMaxLen        = 10000
	StandupFieldMaxLen  = 2000
	ReviewCommentMaxLen = 10000
	// QuestionReminderAfter / QuestionAssumptionAfter drive the brief
	// reminder job and when a manager may mark an unanswered question an
	// assumption (design §6b).
	QuestionReminderAfter   = 3 * 24 * time.Hour
	QuestionAssumptionAfter = 5 * 24 * time.Hour
	// DocReviewReminderAfter / DocReviewEscalateAfter drive the doc-review job.
	DocReviewReminderAfter = 3 * 24 * time.Hour
	DocReviewEscalateAfter = 5 * 24 * time.Hour
	// FeatureSpecTemplateTitle / ProjectBriefTemplateTitle name the wiki
	// templates seeded into each project space.
	FeatureSpecTemplateTitle  = "Feature Spec"
	ProjectBriefTemplateTitle = "Project Brief"
)

// Meeting kinds (038 CHECK).
var MeetingKinds = []string{"kickoff", "sprint_planning", "standup", "design_review", "retro", "demo"}

// Review targets/verdicts (038 CHECK).
const (
	ReviewTargetDoc  = "doc"
	ReviewTargetCode = "code"

	VerdictApproved         = "approved"
	VerdictChangesRequested = "changes_requested"
	VerdictCommented        = "commented"
)

// Bug triage decisions.
const (
	TriageDuplicate = "duplicate"
	TriageNotABug   = "not_a_bug"
	TriageConfirmed = "confirmed"
)

var (
	ErrStaleDocVersion  = errors.New("the spec changed since you opened it — review the latest version")
	ErrNoReviewers      = errors.New("assign at least one reviewer before submitting the spec")
	ErrBriefMissing     = errors.New("write the project brief page first")
	ErrQuestionAnswered = errors.New("this question is already answered")
	ErrTooEarly         = errors.New("a manager may mark a question as an assumption only after it is unanswered for 5 days")
)

// RequirementQuestion is one requirement_questions row.
type RequirementQuestion struct {
	ID                 string     `json:"id"`
	RequirementVersion int        `json:"requirement_version"`
	AskedBy            *string    `json:"asked_by"`
	AskerName          string     `json:"asker_name"`
	Question           string     `json:"question"`
	Answer             *string    `json:"answer"`
	AnsweredBy         *string    `json:"answered_by"`
	AnsweredAt         *time.Time `json:"answered_at"`
	IsAssumption       bool       `json:"is_assumption"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
	CommentCount       int        `json:"comment_count"`
}

// AskQuestionResult: Duplicate=true means an existing near-identical thread
// was returned instead of inserting (the asker is pointed at it).
type AskQuestionResult struct {
	Question  RequirementQuestion `json:"question"`
	Duplicate bool                `json:"duplicate"`
}

type AskQuestionRequest struct {
	Question string `json:"question"`
}

// AnswerQuestionRequest: owner answers (IsAssumption=true for "you decide"
// → the team writes the assumption as the answer); a manager may record an
// assumption after QuestionAssumptionAfter.
type AnswerQuestionRequest struct {
	Answer       string `json:"answer"`
	IsAssumption bool   `json:"is_assumption"`
}

// RequirementGaps is the cached AI gap list for one requirement version.
type RequirementGaps struct {
	Gaps []string `json:"gaps"`
}

// BriefApproval is one brief_approvals row.
type BriefApproval struct {
	ApproverID   string    `json:"approver_id"`
	ApproverName string    `json:"approver_name"`
	ApproverRole string    `json:"approver_role"`
	WikiVersion  int       `json:"wiki_version"`
	CreatedAt    time.Time `json:"created_at"`
}

// BriefView is GET …/brief.
type BriefView struct {
	BriefStatus        string          `json:"brief_status"`
	RequirementVersion int             `json:"requirement_version"`
	PageID             *string         `json:"page_id"`
	PageSlug           *string         `json:"page_slug"`
	PageVersion        int             `json:"page_version"`
	Approvals          []BriefApproval `json:"approvals"`
	CanApprove         bool            `json:"can_approve"`
	ApproveBlocker     string          `json:"approve_blocker,omitempty"`
}

// ItemReview is one work_item_reviews row.
type ItemReview struct {
	ID             string    `json:"id"`
	ItemID         string    `json:"item_id"`
	ReviewerID     *string   `json:"reviewer_id"`
	ReviewerName   string    `json:"reviewer_name"`
	Target         string    `json:"target"`
	Verdict        string    `json:"verdict"`
	Comment        *string   `json:"comment"`
	WikiVersion    *int      `json:"wiki_version"`
	MergeRequestID *string   `json:"merge_request_id"`
	CreatedAt      time.Time `json:"created_at"`
}

type ReviewDocRequest struct {
	Verdict     string  `json:"verdict"`
	Comment     *string `json:"comment"`
	WikiVersion int     `json:"wiki_version"`
}

// DocView is GET …/items/{itemID}/doc for a feature.
type DocView struct {
	ItemID               string       `json:"item_id"`
	DocStatus            *string      `json:"doc_status"`
	PageID               *string      `json:"page_id"`
	PageSlug             *string      `json:"page_slug"`
	SpaceSlug            *string      `json:"space_slug"`
	PageVersion          int          `json:"page_version"`
	ApprovedDocVersion   *int         `json:"approved_doc_version"`
	ChangedSinceApproval bool         `json:"changed_since_approval"`
	Reviews              []ItemReview `json:"reviews"`
	Reviewers            []Assignee   `json:"reviewers"`
}

type TriageBugRequest struct {
	Decision      string  `json:"decision"`
	Severity      *string `json:"severity"`
	DuplicateOfID *string `json:"duplicate_of_id"`
	Reason        *string `json:"reason"`
	OwnerUserID   *string `json:"owner_user_id"`
	IsRegression  *bool   `json:"is_regression"`
	ParentID      *string `json:"parent_id"`
}

// Meeting is one project_meetings row joined to its calendar event.
type Meeting struct {
	CalendarEventID string     `json:"calendar_event_id"`
	Kind            string     `json:"kind"`
	Title           string     `json:"title"`
	StartsAt        time.Time  `json:"starts_at"`
	EndsAt          *time.Time `json:"ends_at"`
	RecurrenceRule  *string    `json:"recurrence_rule"`
	MeetingURL      *string    `json:"meeting_url"`
	ItemID          *string    `json:"item_id"`
	NotesWikiPageID *string    `json:"notes_wiki_page_id"`
	CreatedBy       *string    `json:"created_by"`
	CreatedAt       time.Time  `json:"created_at"`
}

type ScheduleMeetingRequest struct {
	Kind           string     `json:"kind"`
	Title          string     `json:"title"`
	StartsAt       time.Time  `json:"starts_at"`
	EndsAt         *time.Time `json:"ends_at"`
	RecurrenceRule *string    `json:"recurrence_rule"`
	MeetingURL     *string    `json:"meeting_url"`
	ItemID         *string    `json:"item_id"`
	AttendeeIDs    []string   `json:"attendee_ids"`
}

type AttendanceEntry struct {
	UserID string `json:"user_id"`
	Status string `json:"status"` // attended | missed
}

type RecordAttendanceRequest struct {
	OccurrenceAt time.Time         `json:"occurrence_at"`
	Entries      []AttendanceEntry `json:"entries"`
}

// ActionItemRequest turns a meeting action item into a ticket (dup-checked).
type ActionItemRequest struct {
	CreateWorkItemRequest
	// Force creates even when similar open items exist.
	Force bool `json:"force"`
}

type Standup struct {
	UserID    string  `json:"user_id"`
	Name      string  `json:"name"`
	StandupOn string  `json:"standup_on"` // YYYY-MM-DD
	Yesterday string  `json:"yesterday"`
	Today     string  `json:"today"`
	Blockers  *string `json:"blockers"`
	// BlockerKeys are ticket keys (e.g. PAY-12) found in Blockers, resolved
	// against this project; shown on the dashboard, no status change (D12).
	BlockerKeys []ItemRef `json:"blocker_keys"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type PostStandupRequest struct {
	Yesterday string  `json:"yesterday"`
	Today     string  `json:"today"`
	Blockers  *string `json:"blockers"`
}

// Comment is one comments row against a requirement_question or work_item
// subject (contract-phase3.md's comments section reusing the shared table).
type Comment struct {
	ID         string    `json:"id"`
	SubjectID  string    `json:"subject_id"`
	ParentID   *string   `json:"parent_id"`
	AuthorID   *string   `json:"author_id"`
	AuthorName string    `json:"author_name"`
	Content    string    `json:"content"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// CommentMinLen/CommentMaxLen are the shared bounds for both comment threads
// (contract-phase3.md: "content 1-5000 chars").
const (
	CommentMinLen = 1
	CommentMaxLen = 5000
)

type CreateCommentRequest struct {
	Content  string  `json:"content"`
	ParentID *string `json:"parent_id"`
}

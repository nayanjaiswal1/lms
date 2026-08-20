// Package projectmarket implements the project marketplace: staff post a
// requirement, students browse an open board and apply, staff reviews and
// shortlists/selects. This is Phase A, Slice 1 of docs/project-marketplace.md
// — it deliberately stops at selection. Turning a selection into a real
// project_assignment/project_team is a staff action through the existing
// internal/gitlab provisioning flow, not something this package writes to,
// since project_assignments.batch_id is a required, provisioning-coupled
// column this package has no reason to own.
package projectmarket

import "time"

// Requirement statuses.
const (
	RequirementStatusDraft    = "draft"
	RequirementStatusOpen     = "open"
	RequirementStatusClosed   = "closed"
	RequirementStatusArchived = "archived"
)

// Application statuses.
const (
	ApplicationStatusSubmitted   = "submitted"
	ApplicationStatusShortlisted = "shortlisted"
	ApplicationStatusSelected    = "selected"
	ApplicationStatusRejected    = "rejected"
)

// ProjectRequirement is one staff-posted project brief on the open board.
type ProjectRequirement struct {
	ID                  string    `json:"id"`
	OrgID               string    `json:"org_id"`
	Title               string    `json:"title"`
	Brief               string    `json:"brief"`
	RequiredSkills      []string  `json:"required_skills"`
	TeamSizeMin         int       `json:"team_size_min"`
	TeamSizeMax         int       `json:"team_size_max"`
	ApplicationDeadline time.Time `json:"application_deadline"`
	Status              string    `json:"status"`
	CreatedBy           string    `json:"created_by"`
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`
}

// RequirementPatch is PATCH .../requirements/{id}'s editable field set — a
// nil field leaves the current value untouched.
type RequirementPatch struct {
	Title               *string    `json:"title"`
	Brief               *string    `json:"brief"`
	RequiredSkills      *[]string  `json:"required_skills"`
	TeamSizeMin         *int       `json:"team_size_min"`
	TeamSizeMax         *int       `json:"team_size_max"`
	ApplicationDeadline *time.Time `json:"application_deadline"`
}

// RequirementBoardRow is one row of GET /board — the open-board listing any
// org member sees, with ApplicationCount (how many students have applied so
// far) and, for the authenticated caller, whether they've already applied.
type RequirementBoardRow struct {
	ProjectRequirement
	ApplicationCount int     `json:"application_count"`
	MyStatus         *string `json:"my_status,omitempty"`
}

// ProjectApplication is one student's application against one requirement.
type ProjectApplication struct {
	ID            string     `json:"id"`
	OrgID         string     `json:"org_id"`
	RequirementID string     `json:"requirement_id"`
	UserID        string     `json:"user_id"`
	Motivation    *string    `json:"motivation,omitempty"`
	ResumeText    *string    `json:"resume_text,omitempty"`
	Status        string     `json:"status"`
	ReviewedBy    *string    `json:"reviewed_by,omitempty"`
	ReviewedAt    *time.Time `json:"reviewed_at,omitempty"`
	AppliedAt     time.Time  `json:"applied_at"`
	// AIScore/AIRationale are set once by ScoreRequirement (see
	// service_score.go) and never overwritten on a re-run — staff still make
	// the actual shortlist/select/reject call, the AI only ranks.
	AIScore     *float64   `json:"ai_score,omitempty"`
	AIRationale *string    `json:"ai_rationale,omitempty"`
	AIScoredAt  *time.Time `json:"ai_scored_at,omitempty"`
	// Name/Email are populated only by ListApplicationsForStaff's joined
	// query — zero-valued on rows returned by CreateApplication/scanApplication
	// alone, same convention as gitlab.ProjectTeamMember's Name/Email.
	Name  string `json:"name,omitempty"`
	Email string `json:"email,omitempty"`
}

// ApplicationReview is PATCH .../applications/{id}'s request body — staff
// moving an application through shortlisted/selected/rejected.
type ApplicationReview struct {
	Status string `json:"status"`
}

// ApplyRequest is POST /board/{id}/apply's request body.
type ApplyRequest struct {
	Motivation string `json:"motivation"`
	ResumeText string `json:"resume_text"`
}

// TeamFromSelectionRequest is POST
// .../requirements/{id}/create-team's request body — staff points an
// already-created (see internal/gitlab's own assignment flow) assignment at
// this requirement's "selected" applicants, and every one of them is added
// to a new team under it.
type TeamFromSelectionRequest struct {
	AssignmentID string `json:"assignment_id"`
	TeamName     string `json:"team_name"`
	TeamSlug     string `json:"team_slug"`
}

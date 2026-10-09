package workspace

import "time"

// DiscoverProject is one row of GET /api/workspaces/discover: a recruiting
// workspace in the caller's org they can apply to. Summary is a short excerpt
// of the requirement, never the full text.
type DiscoverProject struct {
	ID               string     `json:"id"`
	Title            string     `json:"title"`
	Summary          string     `json:"summary"`
	Skills           []string   `json:"skills"`
	TeamSizeMin      int        `json:"team_size_min"`
	TeamSizeMax      int        `json:"team_size_max"`
	InterestDeadline *time.Time `json:"interest_deadline"`
	HasApplied       bool       `json:"has_applied"`
	CreatedAt        time.Time  `json:"created_at"`
}

// MyInterest is one row of GET /api/my/workspace-interests.
type MyInterest struct {
	ID             string    `json:"id"`
	WorkspaceID    string    `json:"workspace_id"`
	WorkspaceTitle string    `json:"workspace_title"`
	WorkspaceState string    `json:"workspace_status"`
	Status         string    `json:"status"`
	CreatedAt      time.Time `json:"created_at"`
}

// DiscoverSummaryLen caps the requirement excerpt shown in discover.
const DiscoverSummaryLen = 300

// MyInterestsMax caps GET /api/my/workspace-interests.
const MyInterestsMax = 200

package gitlab

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// MyProjectDetailView is GET /api/my/projects/{teamID}/detail's response
// body — the caller's own team plus its assignment context, contribution
// breakdown, and checkpoint list, embedded in one response so the team
// detail page needs a single round trip instead of four separate ones
// (GetMyProject + ListMyProjects + GetMyProjectContributions +
// GetMyProjectCheckpoints).
type MyProjectDetailView struct {
	ProjectTeam
	AssignmentTitle string `json:"assignment_title"`
	// RequiredApprovals mirrors ProjectAssignment.RequiredApprovals (the same
	// field the staff-facing checkpoint views read for their "n/required"
	// display) — joined in here so the student-scoped checkpoint list can
	// show the same denominator instead of a bare approvals count.
	RequiredApprovals int               `json:"required_approvals"`
	Role              string            `json:"role"`
	Contributions     []ContributionRow `json:"contributions"`
	Checkpoints       []MyCheckpointRow `json:"checkpoints"`
}

// GetMyProjectDetail returns teamID's full team row plus its assignment
// title and the caller's role on it, scoped to (org, user, team) via the
// same project_team_members join GetMyProject uses (repo_dashboard.go) — a
// non-member gets ErrNotFound, identical to a team that doesn't exist,
// never a 403 that would leak the team's existence.
func (r *Repo) GetMyProjectDetail(ctx context.Context, orgID, userID, teamID string) (*MyProjectDetailView, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT t.id, t.org_id, t.assignment_id, t.name, t.slug, t.gitlab_project_id, t.gitlab_project_path,
		        t.gitlab_web_url, t.gitlab_hook_id, t.pages_url, t.provision_status, t.provision_error,
		        t.provisioned_at, t.created_by, t.created_at, t.updated_at, a.title, a.required_approvals, m.role
		 FROM project_teams t
		 JOIN project_team_members m ON m.team_id = t.id
		 JOIN project_assignments a ON a.id = t.assignment_id
		 WHERE t.id = $1 AND m.user_id = $2 AND t.org_id = $3`,
		teamID, userID, orgID,
	)
	var v MyProjectDetailView
	err := row.Scan(
		&v.ID, &v.OrgID, &v.AssignmentID, &v.Name, &v.Slug, &v.GitlabProjectID, &v.GitlabProjectPath,
		&v.GitlabWebURL, &v.GitlabHookID, &v.PagesURL, &v.ProvisionStatus, &v.ProvisionError,
		&v.ProvisionedAt, &v.CreatedBy, &v.CreatedAt, &v.UpdatedAt, &v.AssignmentTitle, &v.RequiredApprovals, &v.Role,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: get my project detail: %w", err)
	}
	return &v, nil
}

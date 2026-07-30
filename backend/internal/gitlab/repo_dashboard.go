package gitlab

import (
	"context"
	"fmt"
)

// Batch 4: contribution tracking & dashboards. Every query here reads
// directly off the Batch 3 activity-mirror tables (gitlab_commits,
// gitlab_merge_requests, gitlab_pipelines, gitlab_issues) — no rollup table,
// per kind-herding-cookie.md §0.6's explicit ponytail deferral.

// GetTeamContributions returns every member of teamID with their aggregated
// commit count/additions/deletions, LEFT JOINed against gitlab_commits so a
// member with zero commits still appears as a zero-row rather than being
// absent — that absence-vs-zero distinction is what lets IsFreeRider be
// computed as a plain CommitCount == 0 check below, with no separate query.
func (r *Repo) GetTeamContributions(ctx context.Context, teamID string) ([]ContributionRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT m.user_id, u.name, u.email,
		        COALESCE(c.commit_count, 0), COALESCE(c.additions, 0), COALESCE(c.deletions, 0),
		        c.last_commit_at
		 FROM project_team_members m
		 JOIN users u ON u.id = m.user_id
		 LEFT JOIN (
		   SELECT user_id,
		          COUNT(*) AS commit_count,
		          SUM(COALESCE(additions, 0)) AS additions,
		          SUM(COALESCE(deletions, 0)) AS deletions,
		          MAX(committed_at) AS last_commit_at
		   FROM gitlab_commits
		   WHERE team_id = $1 AND user_id IS NOT NULL
		   GROUP BY user_id
		 ) c ON c.user_id = m.user_id
		 WHERE m.team_id = $1
		 ORDER BY COALESCE(c.commit_count, 0) DESC, u.name`,
		teamID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get team contributions: %w", err)
	}
	defer rows.Close()

	out := []ContributionRow{}
	for rows.Next() {
		var row ContributionRow
		if err := rows.Scan(&row.UserID, &row.Name, &row.Email, &row.CommitCount, &row.Additions, &row.Deletions, &row.LastCommitAt); err != nil {
			return nil, fmt.Errorf("gitlab: scan team contribution: %w", err)
		}
		row.IsFreeRider = row.CommitCount == 0
		out = append(out, row)
	}
	return out, rows.Err()
}

// GetAssignmentLeaderboard ranks every student across every team under
// assignmentID by total commit count — the same LEFT JOIN shape as
// GetTeamContributions, widened from one team to every team on the
// assignment via gitlab_commits joined through project_teams.
func (r *Repo) GetAssignmentLeaderboard(ctx context.Context, assignmentID string) ([]LeaderboardRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT m.user_id, u.name, u.email, t.id, t.name,
		        COALESCE(c.commit_count, 0), COALESCE(c.additions, 0), COALESCE(c.deletions, 0)
		 FROM project_team_members m
		 JOIN project_teams t ON t.id = m.team_id
		 JOIN users u ON u.id = m.user_id
		 LEFT JOIN (
		   SELECT gc.user_id,
		          COUNT(*) AS commit_count,
		          SUM(COALESCE(gc.additions, 0)) AS additions,
		          SUM(COALESCE(gc.deletions, 0)) AS deletions
		   FROM gitlab_commits gc
		   JOIN project_teams pt ON pt.id = gc.team_id
		   WHERE pt.assignment_id = $1 AND gc.user_id IS NOT NULL
		   GROUP BY gc.user_id
		 ) c ON c.user_id = m.user_id
		 WHERE m.assignment_id = $1
		 ORDER BY COALESCE(c.commit_count, 0) DESC, u.name`,
		assignmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get assignment leaderboard: %w", err)
	}
	defer rows.Close()

	out := []LeaderboardRow{}
	rank := 0
	for rows.Next() {
		rank++
		var row LeaderboardRow
		if err := rows.Scan(&row.UserID, &row.Name, &row.Email, &row.TeamID, &row.TeamName,
			&row.CommitCount, &row.Additions, &row.Deletions); err != nil {
			return nil, fmt.Errorf("gitlab: scan leaderboard row: %w", err)
		}
		row.Rank = rank
		out = append(out, row)
	}
	return out, rows.Err()
}

// GetAssignmentBurndown returns every checkpoint under assignmentID with its
// issue open/closed tally, via gitlab_issues.checkpoint_id — the exact join
// migration 023's idx_gitlab_issues_burndown was built for. Correctly
// returns an empty slice today: project_checkpoints has no rows until
// Batch 5 ships checkpoint CRUD, and gitlab_issues.checkpoint_id is only
// ever set by that same later batch's milestone->checkpoint mapping. Not a
// stub — the query is right, there's nothing to match yet.
func (r *Repo) GetAssignmentBurndown(ctx context.Context, assignmentID string) ([]BurndownCheckpoint, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT pc.id, pc.title, pc.position, pc.due_at,
		        COUNT(gi.id) AS total_issues,
		        COUNT(gi.id) FILTER (WHERE gi.state = 'opened') AS open_issues,
		        COUNT(gi.id) FILTER (WHERE gi.state = 'closed') AS closed_issues
		 FROM project_checkpoints pc
		 LEFT JOIN gitlab_issues gi ON gi.checkpoint_id = pc.id
		 WHERE pc.assignment_id = $1
		 GROUP BY pc.id, pc.title, pc.position, pc.due_at
		 ORDER BY pc.position`,
		assignmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get assignment burndown: %w", err)
	}
	defer rows.Close()

	out := []BurndownCheckpoint{}
	for rows.Next() {
		var c BurndownCheckpoint
		if err := rows.Scan(&c.CheckpointID, &c.Title, &c.Position, &c.DueAt, &c.TotalIssues, &c.OpenIssues, &c.ClosedIssues); err != nil {
			return nil, fmt.Errorf("gitlab: scan burndown checkpoint: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// GetAssignmentDashboard returns every team under assignmentID with its
// rolled-up commit/MR/latest-pipeline/free-rider summary — the
// assignment-wide counterpart to Batch 3's per-team, unaggregated
// TeamActivityView. free_rider_count reuses the same "zero commits on this
// team" signal as ContributionRow.IsFreeRider, counted via NOT EXISTS
// rather than re-running GetTeamContributions per team.
func (r *Repo) GetAssignmentDashboard(ctx context.Context, assignmentID string) ([]TeamDashboardSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT t.id, t.name,
		        (SELECT COUNT(*) FROM project_team_members m WHERE m.team_id = t.id) AS member_count,
		        COALESCE(cs.commit_count, 0) AS commit_count,
		        COALESCE(mrs.open_count, 0) AS open_mr_count,
		        COALESCE(mrs.merged_count, 0) AS merged_mr_count,
		        lp.status AS latest_pipeline_status,
		        COALESCE(fr.free_rider_count, 0) AS free_rider_count
		 FROM project_teams t
		 LEFT JOIN (
		   SELECT team_id, COUNT(*) AS commit_count FROM gitlab_commits GROUP BY team_id
		 ) cs ON cs.team_id = t.id
		 LEFT JOIN (
		   SELECT team_id,
		          COUNT(*) FILTER (WHERE state = 'opened') AS open_count,
		          COUNT(*) FILTER (WHERE state = 'merged') AS merged_count
		   FROM gitlab_merge_requests GROUP BY team_id
		 ) mrs ON mrs.team_id = t.id
		 LEFT JOIN LATERAL (
		   SELECT status FROM gitlab_pipelines gp WHERE gp.team_id = t.id ORDER BY gp.updated_at DESC LIMIT 1
		 ) lp ON true
		 LEFT JOIN (
		   SELECT m.team_id, COUNT(*) AS free_rider_count
		   FROM project_team_members m
		   WHERE NOT EXISTS (
		     SELECT 1 FROM gitlab_commits gc WHERE gc.team_id = m.team_id AND gc.user_id = m.user_id
		   )
		   GROUP BY m.team_id
		 ) fr ON fr.team_id = t.id
		 WHERE t.assignment_id = $1
		 ORDER BY t.name`,
		assignmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get assignment dashboard: %w", err)
	}
	defer rows.Close()

	out := []TeamDashboardSummary{}
	for rows.Next() {
		var s TeamDashboardSummary
		if err := rows.Scan(&s.TeamID, &s.TeamName, &s.MemberCount, &s.CommitCount,
			&s.OpenMRCount, &s.MergedMRCount, &s.LatestPipelineStatus, &s.FreeRiderCount); err != nil {
			return nil, fmt.Errorf("gitlab: scan team dashboard summary: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ─── student-facing "my projects" (row-scoped) ─────────────────────────────

// ListMyProjects returns every team userID belongs to in orgID — scoped by
// a real WHERE-clause join on project_team_members.user_id, never an
// application-layer filter applied after fetching every team.
func (r *Repo) ListMyProjects(ctx context.Context, orgID, userID string) ([]MyProjectSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT t.id, t.name, t.assignment_id, a.title, m.role, t.provision_status, t.gitlab_web_url, t.pages_url
		 FROM project_team_members m
		 JOIN project_teams t ON t.id = m.team_id
		 JOIN project_assignments a ON a.id = t.assignment_id
		 WHERE m.user_id = $1 AND t.org_id = $2
		 ORDER BY t.created_at DESC`,
		userID, orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list my projects: %w", err)
	}
	defer rows.Close()

	out := []MyProjectSummary{}
	for rows.Next() {
		var p MyProjectSummary
		if err := rows.Scan(&p.TeamID, &p.TeamName, &p.AssignmentID, &p.AssignmentTitle, &p.Role,
			&p.ProvisionStatus, &p.GitlabWebURL, &p.PagesURL); err != nil {
			return nil, fmt.Errorf("gitlab: scan my project summary: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetMyProject returns teamID only if userID actually belongs to it — the
// join against project_team_members (not just project_teams.org_id) is the
// row-scoping itself, so a student can never fetch a teammate-only or
// another team's row by guessing its ID. Returns ErrNotFound (via scanTeam)
// otherwise, identical to a team that doesn't exist at all from the
// caller's point of view.
func (r *Repo) GetMyProject(ctx context.Context, orgID, userID, teamID string) (*ProjectTeam, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT t.id, t.org_id, t.assignment_id, t.name, t.slug, t.gitlab_project_id, t.gitlab_project_path,
		        t.gitlab_web_url, t.gitlab_hook_id, t.pages_url, t.provision_status, t.provision_error,
		        t.provisioned_at, t.created_by, t.created_at, t.updated_at
		 FROM project_teams t
		 JOIN project_team_members m ON m.team_id = t.id
		 WHERE t.id = $1 AND m.user_id = $2 AND t.org_id = $3`,
		teamID, userID, orgID,
	)
	return scanTeam(row)
}

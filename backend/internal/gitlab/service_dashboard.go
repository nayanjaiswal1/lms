package gitlab

import (
	"context"
	"fmt"
)

// Batch 4: contribution tracking & dashboards. Every method here is a thin,
// org-scoped (or membership-scoped, for the student-facing ones) wrapper
// over repo_dashboard.go's direct aggregation queries — mirrors
// GetTeamActivity's own org-scope-then-read shape from service_roster.go.

// GetAssignmentDashboard returns the assignment-wide, per-team
// commit/MR/pipeline/free-rider summary for the staff+mentor dashboard,
// with each team's member roster and recent-activity feed embedded (see
// Repo.GetTeamMembersByAssignment/GetTeamActivityByAssignment's own doc
// comments) — two extra queries for the whole assignment, never one per
// team, so the frontend detail page no longer needs to fan out
// getProjectTeamMembers/getTeamActivity across every team itself.
func (s *Service) GetAssignmentDashboard(ctx context.Context, orgID, assignmentID string) (*AssignmentDashboardView, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, err
	}
	teams, err := s.repo.GetAssignmentDashboard(ctx, assignmentID)
	if err != nil {
		return nil, err
	}
	membersByTeam, err := s.repo.GetTeamMembersByAssignment(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get assignment dashboard: %w", err)
	}
	activityByTeam, err := s.repo.GetTeamActivityByAssignment(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get assignment dashboard: %w", err)
	}
	for i := range teams {
		members := membersByTeam[teams[i].TeamID]
		if members == nil {
			members = []ProjectTeamMember{}
		}
		teams[i].Members = members
		teams[i].Activity = activityByTeam[teams[i].TeamID]
	}
	return &AssignmentDashboardView{AssignmentID: assignmentID, Teams: teams}, nil
}

// GetTeamContributions returns one team's per-student contribution
// aggregation (including free-rider flags) for the staff+mentor view.
func (s *Service) GetTeamContributions(ctx context.Context, orgID, teamID string) (*TeamContributionsView, error) {
	if _, err := s.repo.GetTeam(ctx, orgID, teamID); err != nil {
		return nil, err
	}
	contributions, err := s.repo.GetTeamContributions(ctx, teamID)
	if err != nil {
		return nil, err
	}
	return &TeamContributionsView{TeamID: teamID, Contributions: contributions}, nil
}

// GetAssignmentBurndown returns an assignment's checkpoint-linked issue
// burndown — empty until Batch 5 seeds project_checkpoints and maps issues
// to them (see Repo.GetAssignmentBurndown's own doc comment).
func (s *Service) GetAssignmentBurndown(ctx context.Context, orgID, assignmentID string) (*AssignmentBurndownView, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, err
	}
	checkpoints, err := s.repo.GetAssignmentBurndown(ctx, assignmentID)
	if err != nil {
		return nil, err
	}
	return &AssignmentBurndownView{AssignmentID: assignmentID, Checkpoints: checkpoints}, nil
}

// GetAssignmentLeaderboard returns every student's ranked commit totals
// across every team under an assignment.
func (s *Service) GetAssignmentLeaderboard(ctx context.Context, orgID, assignmentID string) (*AssignmentLeaderboardView, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, err
	}
	leaderboard, err := s.repo.GetAssignmentLeaderboard(ctx, assignmentID)
	if err != nil {
		return nil, err
	}
	return &AssignmentLeaderboardView{AssignmentID: assignmentID, Leaderboard: leaderboard}, nil
}

// ─── student-facing "my projects" (row-scoped to the caller's own user_id) ─

// ListMyProjects returns every team the authenticated user belongs to —
// never a client-supplied user filter, always the caller's own claims.UserID
// (see Repo.ListMyProjects's WHERE-clause join).
func (s *Service) ListMyProjects(ctx context.Context, orgID, userID string) ([]MyProjectSummary, error) {
	return s.repo.ListMyProjects(ctx, orgID, userID)
}

// GetMyProject returns one of the caller's own teams, or ErrNotFound if
// teamID isn't one of theirs.
func (s *Service) GetMyProject(ctx context.Context, orgID, userID, teamID string) (*ProjectTeam, error) {
	return s.repo.GetMyProject(ctx, orgID, userID, teamID)
}

// GetMyProjectContributions returns a team's contribution breakdown for a
// student who must themselves belong to that team — GetMyProject's
// membership-scoped lookup gates the read before delegating to the same
// aggregation query the staff dashboard uses, so a student can never pull
// another team's contribution rows by guessing a teamID.
func (s *Service) GetMyProjectContributions(ctx context.Context, orgID, userID, teamID string) (*TeamContributionsView, error) {
	if _, err := s.repo.GetMyProject(ctx, orgID, userID, teamID); err != nil {
		return nil, err
	}
	contributions, err := s.repo.GetTeamContributions(ctx, teamID)
	if err != nil {
		return nil, err
	}
	return &TeamContributionsView{TeamID: teamID, Contributions: contributions}, nil
}

// GetMyProjectCheckpoints returns every checkpoint under the caller's team's
// assignment, joined against that team's own submission row — the
// student-scoped view of a gap staff-only routes.go leaves: a student has no
// other way to see their team's MR/approval/CI/grade progress. Same
// membership guard as GetMyProjectContributions: GetMyProject's
// project_team_members join gates the read before delegating to the
// aggregation query, so a student can never pull another team's checkpoint
// rows by guessing a teamID.
func (s *Service) GetMyProjectCheckpoints(ctx context.Context, orgID, userID, teamID string) (*MyProjectCheckpointsView, error) {
	team, err := s.repo.GetMyProject(ctx, orgID, userID, teamID)
	if err != nil {
		return nil, err
	}
	checkpoints, err := s.repo.ListCheckpointsForTeam(ctx, team.AssignmentID, teamID)
	if err != nil {
		return nil, err
	}
	return &MyProjectCheckpointsView{TeamID: teamID, Checkpoints: checkpoints}, nil
}

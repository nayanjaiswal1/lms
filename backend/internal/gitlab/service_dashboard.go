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
		return nil, fmt.Errorf("gitlab.GetAssignmentDashboard: %w", err)
	}
	teams, err := s.repo.GetAssignmentDashboard(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetAssignmentDashboard: %w", err)
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
		return nil, fmt.Errorf("gitlab.GetTeamContributions: %w", err)
	}
	contributions, err := s.repo.GetTeamContributions(ctx, teamID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetTeamContributions: %w", err)
	}
	return &TeamContributionsView{TeamID: teamID, Contributions: contributions}, nil
}

// GetTeamOwnership returns the staff view of a team's per-file ownership —
// same existence guard as GetTeamContributions.
func (s *Service) GetTeamOwnership(ctx context.Context, orgID, teamID string) (*TeamOwnershipView, error) {
	if _, err := s.repo.GetTeam(ctx, orgID, teamID); err != nil {
		return nil, fmt.Errorf("gitlab.GetTeamOwnership: %w", err)
	}
	files, err := s.repo.ListFileOwnership(ctx, teamID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetTeamOwnership: %w", err)
	}
	return &TeamOwnershipView{TeamID: teamID, Files: files}, nil
}

// GetAssignmentBurndown returns an assignment's checkpoint-linked issue
// burndown — empty until Batch 5 seeds project_checkpoints and maps issues
// to them (see Repo.GetAssignmentBurndown's own doc comment).
func (s *Service) GetAssignmentBurndown(ctx context.Context, orgID, assignmentID string) (*AssignmentBurndownView, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, fmt.Errorf("gitlab.GetAssignmentBurndown: %w", err)
	}
	checkpoints, err := s.repo.GetAssignmentBurndown(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetAssignmentBurndown: %w", err)
	}
	return &AssignmentBurndownView{AssignmentID: assignmentID, Checkpoints: checkpoints}, nil
}

// GetAssignmentLeaderboard returns every student's ranked commit totals
// across every team under an assignment.
func (s *Service) GetAssignmentLeaderboard(ctx context.Context, orgID, assignmentID string) (*AssignmentLeaderboardView, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, fmt.Errorf("gitlab.GetAssignmentLeaderboard: %w", err)
	}
	leaderboard, err := s.repo.GetAssignmentLeaderboard(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetAssignmentLeaderboard: %w", err)
	}
	return &AssignmentLeaderboardView{AssignmentID: assignmentID, Leaderboard: leaderboard}, nil
}

// ─── student-facing "my projects" (row-scoped to the caller's own user_id) ─

// GetAssignmentOwnership returns every team's per-file ownership under an
// assignment (staff view).
func (s *Service) GetAssignmentOwnership(ctx context.Context, orgID, assignmentID string) (*AssignmentOwnershipView, error) {
	teams, err := s.repo.ListTeams(ctx, orgID, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetAssignmentOwnership: %w", err)
	}
	view := &AssignmentOwnershipView{AssignmentID: assignmentID, Teams: make([]TeamOwnershipView, 0, len(teams))}
	for _, t := range teams {
		files, err := s.repo.ListFileOwnership(ctx, t.ID)
		if err != nil {
			return nil, fmt.Errorf("gitlab.GetAssignmentOwnership: %w", err)
		}
		view.Teams = append(view.Teams, TeamOwnershipView{TeamID: t.ID, Files: files})
	}
	return view, nil
}

// GetTeamCheckpoints is GetMyProjectCheckpoints without the per-user
// membership check — for callers (workspace) that already authorised the
// caller against the owning project.
func (s *Service) GetTeamCheckpoints(ctx context.Context, orgID, teamID string) (*MyProjectCheckpointsView, error) {
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetTeamCheckpoints: %w", err)
	}
	return s.teamCheckpoints(ctx, team, "gitlab.GetTeamCheckpoints")
}

func (s *Service) teamCheckpoints(ctx context.Context, team *ProjectTeam, op string) (*MyProjectCheckpointsView, error) {
	checkpoints, err := s.repo.ListCheckpointsForTeam(ctx, team.AssignmentID, team.ID)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", op, err)
	}
	return &MyProjectCheckpointsView{TeamID: team.ID, Checkpoints: checkpoints}, nil
}

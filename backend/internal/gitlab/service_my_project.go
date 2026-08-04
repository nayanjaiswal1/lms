package gitlab

import "context"

// GetMyProjectDetail returns the caller's own team (with assignment title
// and role embedded) plus its contribution breakdown and checkpoint list —
// the team detail page's full data need in one call instead of four
// (GetMyProject + ListMyProjects + GetMyProjectContributions +
// GetMyProjectCheckpoints). Row-scoped to (org, user, team) throughout, the
// same membership guard GetMyProjectContributions/GetMyProjectCheckpoints
// use, just consolidated into a single query up front instead of repeating
// the membership check per section.
func (s *Service) GetMyProjectDetail(ctx context.Context, orgID, userID, teamID string) (*MyProjectDetailView, error) {
	view, err := s.repo.GetMyProjectDetail(ctx, orgID, userID, teamID)
	if err != nil {
		return nil, err
	}
	contributions, err := s.repo.GetTeamContributions(ctx, teamID)
	if err != nil {
		return nil, err
	}
	checkpoints, err := s.repo.ListCheckpointsForTeam(ctx, view.AssignmentID, teamID)
	if err != nil {
		return nil, err
	}
	view.Contributions = contributions
	view.Checkpoints = checkpoints
	return view, nil
}

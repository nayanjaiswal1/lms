package gitlab

import (
	"context"
	"fmt"
)

// MyProjectIncludes selects the related collections GetMyProject embeds.
type MyProjectIncludes struct {
	Contributions bool
	Checkpoints   bool
}

// GetMyProject returns the caller's own team (with assignment title and
// role embedded) plus the requested related collections. Row-scoped to
// (org, user, team): the one membership-guarded query up front gates every
// section.
func (s *Service) GetMyProject(ctx context.Context, orgID, userID, teamID string, inc MyProjectIncludes) (*MyProjectDetailView, error) {
	view, err := s.repo.GetMyProjectDetail(ctx, orgID, userID, teamID)
	if err != nil {
		return nil, fmt.Errorf("gitlab.GetMyProject: %w", err)
	}
	if inc.Contributions {
		if view.Contributions, err = s.repo.GetTeamContributions(ctx, teamID); err != nil {
			return nil, fmt.Errorf("gitlab.GetMyProject: %w", err)
		}
	}
	if inc.Checkpoints {
		if view.Checkpoints, err = s.repo.ListCheckpointsForTeam(ctx, view.AssignmentID, teamID); err != nil {
			return nil, fmt.Errorf("gitlab.GetMyProject: %w", err)
		}
	}
	return view, nil
}

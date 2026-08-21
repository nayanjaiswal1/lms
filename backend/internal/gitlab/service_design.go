package gitlab

import (
	"context"
	"fmt"

	"github.com/mindforge/backend/internal/notifications"
)

// ─── Batch 7: design proposals & voting ────────────────────────────────────
// Submitting/listing/voting is any team member (membership verified via
// Repo.GetMyProject, same guard GetMyProjectContributions/
// GetMyProjectCheckpoints already use). Accepting a proposal is staff-only —
// same split as GradeSubmission/MergeSubmission (routes.go's Batch 5
// section): staff makes the final call, students propose and vote.

// SubmitDesignProposal lets a team member propose a design/architecture for
// a checkpoint. Verifies the caller belongs to teamID and that checkpointID
// actually belongs to that team's assignment, so a proposal can never be
// filed against a checkpoint from an unrelated assignment.
func (s *Service) SubmitDesignProposal(ctx context.Context, orgID, userID, checkpointID, teamID, title string, description, link *string) (*ProjectDesignProposal, error) {
	team, err := s.repo.GetMyProject(ctx, orgID, userID, teamID)
	if err != nil {
		return nil, err
	}
	checkpoint, err := s.repo.GetCheckpoint(ctx, orgID, checkpointID)
	if err != nil {
		return nil, err
	}
	if checkpoint.AssignmentID != team.AssignmentID {
		return nil, ErrNotFound
	}
	return s.repo.CreateDesignProposal(ctx, ProjectDesignProposal{
		OrgID: orgID, CheckpointID: checkpointID, TeamID: teamID, SubmittedBy: userID,
		Title: title, Description: description, Link: link,
	})
}

// ListDesignProposals returns a team's proposals against a checkpoint,
// ranked by vote count — same membership guard as SubmitDesignProposal.
func (s *Service) ListDesignProposals(ctx context.Context, orgID, userID, checkpointID, teamID string) ([]DesignProposalView, error) {
	if _, err := s.repo.GetMyProject(ctx, orgID, userID, teamID); err != nil {
		return nil, err
	}
	return s.repo.ListDesignProposals(ctx, checkpointID, teamID, userID)
}

// ListDesignProposalsForCheckpoint is the staff view of every team's
// proposals against a checkpoint — no membership guard needed, this is
// called from a staff-only route (routes.go's Batch 7 section).
func (s *Service) ListDesignProposalsForCheckpoint(ctx context.Context, orgID, checkpointID, callerUserID string) ([]DesignProposalView, error) {
	if _, err := s.repo.GetCheckpoint(ctx, orgID, checkpointID); err != nil {
		return nil, err
	}
	return s.repo.ListAllDesignProposalsForCheckpoint(ctx, checkpointID, callerUserID)
}

// VoteForProposal casts the caller's vote — verifies they belong to the
// proposal's own team before recording it.
func (s *Service) VoteForProposal(ctx context.Context, orgID, userID, proposalID string) error {
	proposal, err := s.repo.GetDesignProposal(ctx, orgID, proposalID)
	if err != nil {
		return err
	}
	if _, err := s.repo.GetMyProject(ctx, orgID, userID, proposal.TeamID); err != nil {
		return err
	}
	return s.repo.VoteForProposal(ctx, proposalID, userID)
}

// RemoveVote retracts the caller's vote — same membership guard.
func (s *Service) RemoveVote(ctx context.Context, orgID, userID, proposalID string) error {
	proposal, err := s.repo.GetDesignProposal(ctx, orgID, proposalID)
	if err != nil {
		return err
	}
	if _, err := s.repo.GetMyProject(ctx, orgID, userID, proposal.TeamID); err != nil {
		return err
	}
	return s.repo.RemoveVote(ctx, proposalID, userID)
}

// AcceptDesignProposal is the staff-only call that settles a design/
// architecture review checkpoint on one team's winning proposal — notifies
// the whole team, best-effort, same treatment notifyTeam's other call sites
// give a notification failure (never blocks the accept itself).
func (s *Service) AcceptDesignProposal(ctx context.Context, orgID, proposalID string) (*ProjectDesignProposal, error) {
	accepted, err := s.repo.AcceptDesignProposal(ctx, orgID, proposalID)
	if err != nil {
		return nil, err
	}
	if team, err := s.repo.GetTeamByID(ctx, accepted.TeamID); err == nil {
		s.notifyTeam(ctx, team, notifications.New{
			Type:       "gitlab.design_proposal_accepted",
			Title:      fmt.Sprintf("%q was accepted", accepted.Title),
			EntityType: strPtr("project_design_proposal"),
			EntityID:   &accepted.ID,
			Priority:   notifications.PriorityNormal,
			DedupeKey:  fmt.Sprintf("gitlab.design_proposal_accepted:%s", accepted.ID),
		})
	}
	return accepted, nil
}

// DeleteDesignProposal lets a team member withdraw their own proposal.
func (s *Service) DeleteDesignProposal(ctx context.Context, orgID, userID, id string) error {
	return s.repo.DeleteDesignProposal(ctx, orgID, id, userID)
}

package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/mindforge/backend/internal/jobs"
)

// syncMembersTimeoutMS bounds one sync_members job run.
const syncMembersTimeoutMS = 60000

// ListTeamMembers lists a team's roster.
func (s *Service) ListTeamMembers(ctx context.Context, orgID, teamID string) ([]ProjectTeamMember, error) {
	if _, err := s.repo.GetTeam(ctx, orgID, teamID); err != nil {
		return nil, err
	}
	return s.repo.ListTeamMembers(ctx, teamID)
}

// teamActivityLimit bounds each of GetTeamActivity's three reads — matches
// the "simple ORDER BY ... LIMIT 20" scope in kind-herding-cookie.md §7;
// no pagination, since this is a detail-view feed, not a list page.
const teamActivityLimit = 20

// GetTeamActivity returns a team's recent commit/MR/pipeline mirror for the
// read-only activity feed on the team detail view — org-scoped through the
// same GetTeam check ListTeamMembers uses above. Three independent reads,
// no aggregation: contribution scoring/leaderboards are Batch 4's dashboard
// scope, not this one.
func (s *Service) GetTeamActivity(ctx context.Context, orgID, teamID string) (*TeamActivityView, error) {
	if _, err := s.repo.GetTeam(ctx, orgID, teamID); err != nil {
		return nil, err
	}
	commits, err := s.repo.ListRecentCommits(ctx, teamID, teamActivityLimit)
	if err != nil {
		return nil, err
	}
	mergeRequests, err := s.repo.ListRecentMergeRequests(ctx, teamID, teamActivityLimit)
	if err != nil {
		return nil, err
	}
	pipeline, err := s.repo.GetLatestPipeline(ctx, teamID)
	if err != nil {
		return nil, err
	}
	return &TeamActivityView{Commits: commits, MergeRequests: mergeRequests, Pipeline: pipeline}, nil
}

// AddTeamMember adds userID to team as role/accessLevel, sync_status='pending'.
// If the team already has a forked GitLab project, a sync_members job is
// enqueued right away; otherwise the member just accumulates pending until
// ProvisionTeam's own final SyncTeamMembers call picks up everyone at once.
func (s *Service) AddTeamMember(ctx context.Context, orgID, teamID, userID, role string, accessLevel int, addedBy string) (*ProjectTeamMember, error) {
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return nil, err
	}
	added := addedBy
	member, err := s.repo.AddTeamMember(ctx, ProjectTeamMember{
		TeamID:            teamID,
		UserID:            userID,
		AssignmentID:      team.AssignmentID,
		Role:              role,
		GitlabAccessLevel: accessLevel,
		AddedBy:           &added,
	})
	if err != nil {
		return nil, err
	}
	if team.GitlabProjectID != nil {
		if err := s.enqueueSyncMembers(ctx, orgID, teamID); err != nil {
			slog.ErrorContext(ctx, "gitlab: enqueue sync_members on member add failed", "team_id", teamID, "error", err)
		}
	}
	return member, nil
}

// RemoveTeamMember removes userID from team. If the team's project hasn't
// been forked yet there's nothing on GitLab to reconcile, so the row is
// deleted outright; otherwise it's flagged sync_status='removing' and a
// sync_members job actually revokes GitLab access before the row is deleted
// (see SyncTeamMembers) — the local record is never removed before GitLab
// access is confirmed gone.
func (s *Service) RemoveTeamMember(ctx context.Context, orgID, teamID, userID string) error {
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return err
	}
	if team.GitlabProjectID == nil {
		return s.repo.DeleteTeamMember(ctx, teamID, userID)
	}
	if err := s.repo.MarkMemberRemoving(ctx, teamID, userID); err != nil {
		return err
	}
	return s.enqueueSyncMembers(ctx, orgID, teamID)
}

// RequestSync enqueues an on-demand roster sync for a provisioned team —
// the same job the 30-min cron sweep and every add/remove-member call
// already trigger automatically.
func (s *Service) RequestSync(ctx context.Context, orgID, teamID string) error {
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return err
	}
	if team.GitlabProjectID == nil {
		return ErrConflict
	}
	return s.enqueueSyncMembers(ctx, orgID, teamID)
}

// enqueueSyncMembers deliberately carries no idempotency key: unlike
// provisioning (a one-time-per-team operation, safe to key permanently on
// "gl-prov-"+teamID), roster sync is meant to run repeatedly over a team's
// whole lifetime — a fixed key would let only the very first sync job ever
// run. SyncTeamMembers is idempotent to call repeatedly, so stacking a few
// redundant jobs for the same team is harmless.
func (s *Service) enqueueSyncMembers(ctx context.Context, orgID, teamID string) error {
	timeout := syncMembersTimeoutMS
	_, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler:   jobSyncMembers,
		Priority:  jobs.PriorityNormal,
		Payload:   map[string]string{"team_id": teamID},
		OrgID:     &orgID,
		TimeoutMS: &timeout,
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("gitlab: enqueue sync_members: %w", err)
	}
	return nil
}

// SyncTeamMembers reconciles project_team_members against a team's actual
// GitLab project membership: adds/edits members not yet synced, and removes
// (both on GitLab and locally) members flagged sync_status='removing'.
// Members whose MindForge user has no gitlab_connections row are marked
// sync_status='failed' — there's no GitLab identity to add them with, and no
// notifications package exists yet (that's Batch 5) to prompt them to
// connect, so the failure just sits visible on the roster for now.
func (s *Service) SyncTeamMembers(ctx context.Context, teamID string) error {
	team, err := s.repo.GetTeamByID(ctx, teamID)
	if err != nil {
		return fmt.Errorf("gitlab: sync members: get team: %w", err)
	}
	if team.GitlabProjectID == nil {
		return nil // nothing to reconcile until the team's fork exists
	}
	client, err := s.clientForTeam(ctx, team.OrgID, team.AssignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: sync members: resolve client: %w", err)
	}

	glMembers, err := client.ListProjectMembers(ctx, *team.GitlabProjectID)
	if err != nil {
		return fmt.Errorf("gitlab: sync members: list gitlab members: %w", err)
	}
	byGitlabUserID := make(map[int64]ProjectMember, len(glMembers))
	for _, m := range glMembers {
		byGitlabUserID[m.ID] = m
	}

	// Removals first, so a member removed then immediately re-added within
	// the same sweep ends up correctly present rather than removed after.
	removing, err := s.repo.ListMembersRemoving(ctx, teamID)
	if err != nil {
		return fmt.Errorf("gitlab: sync members: list removing: %w", err)
	}
	for _, m := range removing {
		conn, connErr := s.repo.GetConnection(ctx, team.OrgID, m.UserID)
		if connErr == nil {
			if err := client.RemoveProjectMember(ctx, *team.GitlabProjectID, conn.GitlabUserID); err != nil {
				msg := err.Error()
				_ = s.repo.UpdateMemberSyncResult(ctx, teamID, m.UserID, SyncStatusFailed, &msg)
				slog.ErrorContext(ctx, "gitlab: remove project member failed", "team_id", teamID, "user_id", m.UserID, "error", err)
				continue
			}
		}
		// No connection on file means there was never a GitLab identity to
		// remove in the first place — the local row can go regardless.
		if err := s.repo.DeleteTeamMember(ctx, teamID, m.UserID); err != nil {
			slog.ErrorContext(ctx, "gitlab: delete removed team member row failed", "team_id", teamID, "user_id", m.UserID, "error", err)
		}
	}

	pending, err := s.repo.ListMembersNeedingSync(ctx, teamID)
	if err != nil {
		return fmt.Errorf("gitlab: sync members: list pending: %w", err)
	}
	for _, m := range pending {
		conn, connErr := s.repo.GetConnection(ctx, team.OrgID, m.UserID)
		if connErr != nil {
			msg := "member has not connected their GitLab account yet"
			_ = s.repo.UpdateMemberSyncResult(ctx, teamID, m.UserID, SyncStatusFailed, &msg)
			continue
		}

		var syncErr error
		if existing, isMember := byGitlabUserID[conn.GitlabUserID]; !isMember {
			syncErr = client.AddProjectMember(ctx, *team.GitlabProjectID, conn.GitlabUserID, m.GitlabAccessLevel)
		} else if existing.AccessLevel != m.GitlabAccessLevel {
			syncErr = client.EditProjectMember(ctx, *team.GitlabProjectID, conn.GitlabUserID, m.GitlabAccessLevel)
		}
		if syncErr != nil {
			msg := syncErr.Error()
			_ = s.repo.UpdateMemberSyncResult(ctx, teamID, m.UserID, SyncStatusFailed, &msg)
			continue
		}
		_ = s.repo.UpdateMemberSyncResult(ctx, teamID, m.UserID, SyncStatusSynced, nil)
	}
	return nil
}

// SyncAllPendingTeams is the gitlab.sync_members cron sweep's entry point:
// every provisioned team with at least one member row not yet reconciled.
// Per-team failures are logged and skipped rather than aborting the whole
// sweep, so one org's installation hiccup doesn't block every other org's
// roster reconciliation.
func (s *Service) SyncAllPendingTeams(ctx context.Context) error {
	teams, err := s.repo.ListTeamsNeedingSync(ctx)
	if err != nil {
		return fmt.Errorf("gitlab: sync all pending teams: %w", err)
	}
	for _, t := range teams {
		if err := s.SyncTeamMembers(ctx, t.ID); err != nil {
			slog.ErrorContext(ctx, "gitlab: sync team members failed during sweep", "team_id", t.ID, "error", err)
		}
	}
	return nil
}

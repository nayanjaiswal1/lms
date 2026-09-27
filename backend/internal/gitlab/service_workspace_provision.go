package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
)

// service_workspace_provision.go — Phase 4 (contract-phase4.md D8): giving a
// Project Workspace its own GitLab repo. Reuses the course-assignment
// provisioning machinery's underlying pieces (project_assignments,
// project_teams, AddTeamMember/SyncTeamMembers roster sync, the Batch 3
// activity webhook) rather than inventing a parallel table set — but a
// workspace project has no template repo to fork (00-decisions D8), so this
// file creates a brand-new blank project (Client.CreateProject) instead of
// running provisionTeamSteps' fork-then-poll-import flow. ProvisionTeam /
// provisionTeamSteps (course assignments) are untouched.

// WorkspaceBatchName is the one hidden per-org batch every workspace project's
// project_assignments row hangs off (project_assignments.batch_id is
// NOT NULL, and workspaces have no real "batch" concept of their own).
// 00-decisions D8: "revisit only if that batch shows up in batch UIs (filter
// it by a kind flag then)" — batches has no such flag today (verified against
// migration 001/008), so it is left as a plain active batch. It will appear
// in ordinary batch listings until a future migration adds one; documented
// as this decision's own follow-up rather than worked around here.
const WorkspaceBatchName = "Project Workspaces"

// workspaceBatchSlug is deterministic (not random) so EnsureWorkspaceBatch
// can look it up again without a dedicated "kind" column.
const workspaceBatchSlug = "project-workspaces"

// EnsureWorkspaceBatch returns the org's hidden workspace batch id, creating
// it on first use. A benign race (two concurrent first-ever calls) can create
// two rows — acceptable for an internal, invisible-to-instructors batch
// (ponytail: no advisory lock; add one if a duplicate is ever actually seen).
func (s *Service) EnsureWorkspaceBatch(ctx context.Context, orgID, createdBy string) (string, error) {
	return s.repo.EnsureWorkspaceBatch(ctx, orgID, createdBy, WorkspaceBatchName, workspaceBatchSlug)
}

// WorkspaceTeamMember is one active project member to seed the freshly
// provisioned GitLab project's roster with.
type WorkspaceTeamMember struct {
	UserID string
	// Lead marks the project's owner/manager(s) — provisioned as Maintainer
	// and team-role "lead"; everyone else is Developer / team-role "member".
	Lead bool
}

// ProvisionWorkspaceProject creates a project_assignments + project_teams
// pair for a Project Workspace, a brand-new (non-forked) private GitLab
// repository under the org's installation, registers the Batch 3 activity
// webhook, and adds every given member to the roster. Returns the team id —
// the caller (workspace.Service) persists it onto workspace_projects.team_id.
// Idempotent per call site's own guard (workspace only calls this once, when
// team_id is still nil); a second call would create a second team, which the
// caller must not do.
func (s *Service) ProvisionWorkspaceProject(ctx context.Context, orgID, userID, title, slug string, members []WorkspaceTeamMember) (*ProjectTeam, error) {
	batchID, err := s.EnsureWorkspaceBatch(ctx, orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: provision workspace project: ensure batch: %w", err)
	}

	assignment, err := s.repo.CreateAssignment(ctx, ProjectAssignment{
		OrgID: orgID, BatchID: batchID, Title: title, Slug: slug,
		Visibility: VisibilityPrivate, RequiredApprovals: 1, DefaultBranch: "main",
		CreatedBy: userID,
	})
	if err != nil {
		return nil, fmt.Errorf("gitlab: provision workspace project: create assignment: %w", err)
	}

	// CreateTeam auto-enqueues gitlab.provision_team only when the parent
	// assignment is already 'active' — assignment is left 'draft' here
	// deliberately, since that job's ProvisionTeam/provisionTeamSteps assumes
	// a template to fork and would just fail forever for a workspace project.
	team, err := s.repo.CreateTeam(ctx, ProjectTeam{OrgID: orgID, AssignmentID: assignment.ID, Name: title, Slug: slug, CreatedBy: &userID})
	if err != nil {
		return nil, fmt.Errorf("gitlab: provision workspace project: create team: %w", err)
	}

	if err := s.provisionWorkspaceTeamSteps(ctx, team, assignment); err != nil {
		msg := err.Error()
		_ = s.repo.SetTeamProvisionStatus(ctx, team.ID, ProvisionFailed, &msg)
		return nil, fmt.Errorf("gitlab: provision workspace project: %w", err)
	}
	if err := s.repo.MarkTeamReady(ctx, team.ID); err != nil {
		return nil, fmt.Errorf("gitlab: provision workspace project: mark ready: %w", err)
	}

	for _, m := range members {
		role, accessLevel := MemberRoleMember, AccessLevelDeveloper
		if m.Lead {
			role, accessLevel = MemberRoleLead, AccessLevelMaintainer
		}
		if _, err := s.AddTeamMember(ctx, orgID, team.ID, m.UserID, role, accessLevel, userID); err != nil {
			// Best-effort per member — one missing/duplicate roster row must
			// not abort provisioning the repo itself.
			slog.ErrorContext(ctx, "gitlab: provision workspace project: add member failed", "team_id", team.ID, "user_id", m.UserID, "error", err)
		}
	}

	return s.repo.GetTeamByID(ctx, team.ID)
}

// provisionWorkspaceTeamSteps is provisionTeamSteps' workspace counterpart —
// create the subgroup (once per org, mirroring "once per assignment" since
// every workspace project gets its own hidden assignment) and a blank
// project, register the webhook. No fork, no import poll, no branch
// protection (a workspace project isn't a graded submission with a merge
// gate) — reprovisioning/reprovision-team's staff-facing retry flow doesn't
// apply here either, since ProvisionWorkspaceProject is a one-shot call from
// the workspace settings page, not a job.
func (s *Service) provisionWorkspaceTeamSteps(ctx context.Context, team *ProjectTeam, assignment *ProjectAssignment) error {
	client, err := s.clientFor(ctx, assignment.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("resolve installation client: %w", err)
	}
	inst, err := s.resolveInstallation(ctx, assignment.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("get installation: %w", err)
	}
	if inst.RootGroupID == nil {
		return errors.New("installation has no root_group_id configured")
	}

	groupPath := "ws-" + assignment.ID
	group, err := client.CreateGroup(ctx, WorkspaceBatchName, groupPath, *inst.RootGroupID, assignment.Visibility)
	if err != nil {
		return fmt.Errorf("create workspace subgroup: %w", err)
	}
	if err := s.repo.SetAssignmentGroup(ctx, assignment.ID, group.ID, group.FullPath); err != nil {
		return fmt.Errorf("persist workspace subgroup: %w", err)
	}

	project, err := client.CreateProject(ctx, group.ID, team.Name, team.Slug, assignment.Visibility)
	if err != nil {
		return fmt.Errorf("create workspace project: %w", err)
	}
	if err := s.repo.SetTeamForkResult(ctx, team.ID, project.ID, project.PathWithNamespace, project.WebURL); err != nil {
		return fmt.Errorf("persist workspace project: %w", err)
	}

	if err := s.registerTeamWebhook(ctx, client, team, project.ID, assignment.InstallationID); err != nil {
		return fmt.Errorf("register webhook: %w", err)
	}
	return nil
}

// GetTeam returns an org-scoped team by id — exposed so workspace's Phase 4
// MR-reviewer sync (service_gitlab.go) can resolve a linked project's numeric
// GitLab project id without reaching into gitlab's repo layer directly.
func (s *Service) GetTeam(ctx context.Context, orgID, teamID string) (*ProjectTeam, error) {
	return s.repo.GetTeam(ctx, orgID, teamID)
}

// ResolveGitlabUserID returns userID's own connected GitLab numeric id, if
// any — workspace's Phase 4 MR-reviewer sync (service_gitlab.go) uses this to
// translate an item's reviewer assignees into GitLab reviewer_ids before
// calling Client.SetMergeRequestReviewers.
func (s *Service) ResolveGitlabUserID(ctx context.Context, orgID, userID string) (int64, bool, error) {
	conn, err := s.repo.GetConnection(ctx, orgID, userID)
	if errors.Is(err, ErrNotFound) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, fmt.Errorf("gitlab: resolve gitlab user id: %w", err)
	}
	return conn.GitlabUserID, true, nil
}

// GrantWorkspaceAccess adds userID to a workspace project's GitLab roster —
// best-effort, called after a member is added/reactivated (contract-phase4.md
// 4c: "Member add/remove ... grants/revokes GitLab access best-effort after
// commit"). No-op if the team has no GitLab project yet.
func (s *Service) GrantWorkspaceAccess(ctx context.Context, orgID, teamID, userID string, lead bool) error {
	role, accessLevel := MemberRoleMember, AccessLevelDeveloper
	if lead {
		role, accessLevel = MemberRoleLead, AccessLevelMaintainer
	}
	if _, err := s.AddTeamMember(ctx, orgID, teamID, userID, role, accessLevel, userID); err != nil {
		return fmt.Errorf("gitlab: grant workspace access: %w", err)
	}
	return nil
}

// RevokeWorkspaceAccess removes userID from a workspace project's GitLab
// roster — best-effort, mirrors GrantWorkspaceAccess.
func (s *Service) RevokeWorkspaceAccess(ctx context.Context, orgID, teamID, userID string) error {
	if err := s.RemoveTeamMember(ctx, orgID, teamID, userID); err != nil {
		return fmt.Errorf("gitlab: revoke workspace access: %w", err)
	}
	return nil
}

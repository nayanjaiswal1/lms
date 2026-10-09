package workspace

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strconv"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
)

// jobWorkspaceGitlabSync must stay in sync with
// handlers.HandlerWorkspaceGitlabSync (internal/jobs/handlers/constants.go) —
// a plain string literal for the same reason jobWorkspaceProjectInviteEmail
// is (service_recruiting.go): internal/jobs/handlers imports this package to
// build its handler, so this package can't import handlers back.
const jobWorkspaceGitlabSync = "workspace.gitlab_sync"

const gitlabSyncTimeoutMS = 30000

// service_gitlab.go — Phase 4 (contract-phase4.md 4a): implements
// gitlab.WorkItemLinker (LinkGitlabRef), the GitLab provisioning trigger
// (ProvisionGitlab, D8), and the best-effort member-add/remove access
// grant/revoke gitlab's own roster sync backs.

// LinkGitlabRef implements gitlab.WorkItemLinker — called by the gitlab
// package's webhook ingest (never by an HTTP request), so there is no
// ProjectCtx: it builds its own minimal one for transitionTx, with
// SkipRoleCheck true (the actor/ownership checks don't apply to a
// system-observed event) — SoD checks below still always run
// (agent-hard-rules.md; see the automation section's own note on ErrSoD).
func (s *Service) LinkGitlabRef(ctx context.Context, orgID, teamID, ticketKey string, info gitlab.GitlabRefInfo) error {
	m := TicketKeyPattern.FindStringSubmatch(ticketKey)
	if m == nil {
		return nil
	}
	prefix := m[1]
	keyNum, err := strconv.Atoi(m[2])
	if err != nil {
		return nil
	}

	project, err := s.repo.GetProjectByTeamID(ctx, s.pool, orgID, teamID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil
		}
		return fmt.Errorf("workspace: link gitlab ref: resolve project: %w", err)
	}
	if project.KeyPrefix != prefix {
		slog.InfoContext(ctx, "workspace: gitlab link ignored: foreign key", "team_id", teamID, "ticket_key", ticketKey, "project_prefix", project.KeyPrefix)
		return nil
	}
	if project.ProjectStatus == ProjectArchived {
		return nil
	}

	item, err := s.repo.GetWorkItemByKeyNum(ctx, s.pool, project.ID, keyNum)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil
		}
		return fmt.Errorf("workspace: link gitlab ref: resolve item: %w", err)
	}
	if item.ArchivedAt != nil {
		return nil
	}

	if info.AuthorUserID == nil {
		slog.InfoContext(ctx, "workspace: gitlab link ignored: no mapped author", "item", item.Key)
		return nil
	}
	author, err := s.repo.GetMember(ctx, s.pool, project.ID, *info.AuthorUserID)
	if err != nil || author.Status != MemberActive {
		slog.InfoContext(ctx, "workspace: gitlab link ignored: author not an active member", "item", item.Key, "user_id", *info.AuthorUserID)
		return nil
	}

	if err := s.repo.UpsertWorkItemGitlab(ctx, s.pool, project.ID, item.ID, info.Kind, info.Ref, info.MergeRequestID); err != nil {
		return fmt.Errorf("workspace: link gitlab ref: upsert link: %w", err)
	}

	if err := s.runGitlabAutomation(ctx, project, item, info); err != nil {
		return err
	}

	if info.Kind == gitlab.GitlabRefKindMR && info.MRState == "opened" {
		s.syncMRReviewers(ctx, orgID, teamID, item.ID, info.Ref)
	}
	return nil
}

// runGitlabAutomation applies contract-phase4.md 4a step 4's forward-only
// status automation. Every "gate" error the normal transition path can
// return (brief not agreed, doc not approved, WIP limit, blocked-by-open,
// missing-owner precondition, and — see this function's own note — SoD) is
// swallowed: automation "skips silently when blocked by a gate" rather than
// failing the webhook ingest that triggered it.
func (s *Service) runGitlabAutomation(ctx context.Context, project *Project, item *WorkItem, info gitlab.GitlabRefInfo) error {
	if project.ProjectStatus != ProjectActive {
		return nil
	}
	assignees, err := s.repo.ListAssigneesByItem(ctx, s.pool, item.ID)
	if err != nil {
		return fmt.Errorf("workspace: gitlab automation: list assignees: %w", err)
	}
	isOwnerOrDeveloper := false
	for _, a := range assignees {
		if a.UserID == *info.AuthorUserID && (a.Role == AssigneeOwner || a.Role == AssigneeDeveloper) {
			isOwnerOrDeveloper = true
			break
		}
	}
	if !isOwnerOrDeveloper {
		return nil
	}

	to := ""
	switch info.Kind {
	case gitlab.GitlabRefKindCommit, gitlab.GitlabRefKindBranch:
		if item.Status == ItemTodo {
			to = ItemInProgress
		}
	case gitlab.GitlabRefKindMR:
		switch info.MRState {
		case gitlab.MRStateOpened:
			if item.Status == ItemInProgress {
				to = ItemInReview
			}
		case gitlab.MRStateMerged:
			if item.Status == ItemInReview {
				allMerged, latestGreen, err := s.repo.GitlabAutomationReadiness(ctx, s.pool, item.ID)
				if err != nil {
					return fmt.Errorf("workspace: gitlab automation: readiness: %w", err)
				}
				if allMerged && latestGreen {
					to = ItemTesting
				}
			}
		case gitlab.MRStateClosed:
			if item.Status == ItemInReview {
				to = ItemInProgress
			}
		}
	}
	if to == "" {
		return nil
	}

	pc := &ProjectCtx{ProjectID: project.ID, OrgID: project.OrgID, UserID: *info.AuthorUserID, ProjectStatus: project.ProjectStatus, BriefStatus: project.BriefStatus}
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		_, err := s.transitionTx(ctx, tx, transitionInput{PC: pc, ItemID: item.ID, Source: SourceGitlab, To: to, SkipRoleCheck: true})
		return err
	})
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, ErrIllegalTransition), errors.Is(err, ErrBriefNotAgreed), errors.Is(err, ErrDocNotApproved),
		errors.Is(err, ErrWipLimit), errors.Is(err, ErrBlockedByOpen), errors.Is(err, ErrPreconditionFail),
		errors.Is(err, ErrSoD), errors.Is(err, ErrInvalidState):
		// Never touches done/wont_do/blocked (not reachable from the switch
		// above) and respects every other gate by skipping silently — see
		// this function's own doc comment. ErrSoD included deliberately:
		// sod.Check is never bypassed (agent-hard-rules.md), so when the
		// commit/MR author doesn't also hold the item's reviewer role, the
		// in_review->testing rollup simply doesn't fire from automation alone
		// — the same gate a human's own attempt would hit.
		slog.InfoContext(ctx, "workspace: gitlab automation skipped: blocked by a gate", "item", item.Key, "to", to, "error", err)
		return nil
	default:
		return fmt.Errorf("workspace: gitlab automation: transition: %w", err)
	}
}

// syncMRReviewers mirrors an item's reviewer assignees onto the MR once it's
// opened (contract-phase4.md 4a step 5). Best-effort: any failure (no gitlab
// dep wired, no client, the GitLab API call itself) marks the link
// sync_status='pending' and enqueues workspace.gitlab_sync to retry — never
// fails the webhook ingest that triggered it.
func (s *Service) syncMRReviewers(ctx context.Context, orgID, teamID, itemID, mrRef string) {
	if s.gitlab == nil {
		return
	}
	if err := s.attemptMRReviewerSync(ctx, orgID, teamID, itemID, mrRef); err != nil {
		slog.WarnContext(ctx, "workspace: sync mr reviewers failed, queuing retry", "item_id", itemID, "mr_ref", mrRef, "error", err)
		if setErr := s.repo.SetGitlabLinkSyncStatus(ctx, s.pool, itemID, GitlabRefMR, mrRef, "pending"); setErr != nil {
			slog.ErrorContext(ctx, "workspace: mark gitlab link pending failed", "item_id", itemID, "error", setErr)
		}
		if err := s.enqueueGitlabSync(ctx, orgID, teamID, itemID, mrRef); err != nil {
			slog.ErrorContext(ctx, "workspace: enqueue gitlab_sync failed", "item_id", itemID, "error", err)
		}
		return
	}
	if err := s.repo.SetGitlabLinkSyncStatus(ctx, s.pool, itemID, GitlabRefMR, mrRef, "synced"); err != nil {
		slog.ErrorContext(ctx, "workspace: mark gitlab link synced failed", "item_id", itemID, "error", err)
	}
}

// enqueueGitlabSync queues one retry attempt for a pending MR reviewer sync.
// No idempotency key: unlike provisioning, this is meant to be re-enqueued
// each time a fresh sync attempt is warranted (a later MR update could retry
// the same ref again); duplicate queued attempts are harmless since
// SyncGitlabReviewers is itself idempotent (SetMergeRequestReviewers replaces
// the full reviewer set every call).
func (s *Service) enqueueGitlabSync(ctx context.Context, orgID, teamID, itemID, mrRef string) error {
	if s.jobs == nil {
		return nil
	}
	timeout := gitlabSyncTimeoutMS
	_, err := jobs.Enqueue(ctx, s.pool, s.jobs, jobs.EnqueueParams{
		Handler:   jobWorkspaceGitlabSync,
		Priority:  jobs.PriorityNormal,
		Payload:   map[string]string{"org_id": orgID, "team_id": teamID, "item_id": itemID, "mr_ref": mrRef},
		OrgID:     &orgID,
		TimeoutMS: &timeout,
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("workspace: enqueue gitlab_sync: %w", err)
	}
	return nil
}

// attemptMRReviewerSync is the one real attempt syncMRReviewers and the
// workspace.gitlab_sync job handler both make.
func (s *Service) attemptMRReviewerSync(ctx context.Context, orgID, teamID, itemID, mrRef string) error {
	team, err := s.gitlab.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return fmt.Errorf("resolve team: %w", err)
	}
	if team.GitlabProjectID == nil {
		return errors.New("team has no gitlab project yet")
	}
	mrIID, err := strconv.ParseInt(mrRef, 10, 64)
	if err != nil {
		return fmt.Errorf("parse mr iid: %w", err)
	}
	reviewerUserIDs, err := s.repo.ListReviewerUserIDs(ctx, s.pool, itemID)
	if err != nil {
		return fmt.Errorf("list reviewers: %w", err)
	}
	reviewerGitlabIDs := make([]int64, 0, len(reviewerUserIDs))
	for _, userID := range reviewerUserIDs {
		glID, ok, err := s.gitlab.ResolveGitlabUserID(ctx, orgID, userID)
		if err != nil {
			return fmt.Errorf("resolve reviewer gitlab id: %w", err)
		}
		if ok {
			reviewerGitlabIDs = append(reviewerGitlabIDs, glID)
		}
	}
	client, err := s.gitlab.ClientForTeam(ctx, orgID, teamID)
	if err != nil {
		return fmt.Errorf("resolve client: %w", err)
	}
	if err := client.SetMergeRequestReviewers(ctx, *team.GitlabProjectID, mrIID, reviewerGitlabIDs); err != nil {
		return fmt.Errorf("set reviewers: %w", err)
	}
	return nil
}

// ─── GitLab provisioning (D8) ───────────────────────────────────────────────

// ProvisionGitlab is POST …/gitlab/provision (owner, StatusesPlanning,
// gitlab_enabled): gives the project its own GitLab repo the first time,
// reusing gitlab.Service's existing team-provisioning machinery.
func (s *Service) ProvisionGitlab(ctx context.Context, pc *ProjectCtx, installationID *string) (*Project, error) {
	if s.gitlab == nil {
		return nil, fmt.Errorf("%w: gitlab integration is not configured for this deployment", ErrInvalidState)
	}
	project, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if !project.GitlabEnabled {
		return nil, fmt.Errorf("%w: enable GitLab for this project first", ErrInvalidState)
	}
	if project.TeamID != nil {
		return nil, ErrConflict
	}
	if installationID != nil {
		if _, err := uuid.Parse(*installationID); err != nil {
			return nil, &FieldError{Fields: map[string]string{"installation_id": "installation_id must be a valid id."}}
		}
		if err := s.gitlab.InstallationExists(ctx, pc.OrgID, *installationID); err != nil {
			if errors.Is(err, gitlab.ErrNotFound) {
				return nil, &FieldError{Fields: map[string]string{"installation_id": "Unknown GitLab installation."}}
			}
			return nil, fmt.Errorf("workspace: provision gitlab: check installation: %w", err)
		}
	}

	members, err := s.repo.ListMembers(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	teamMembers := make([]gitlab.WorkspaceTeamMember, 0, len(members))
	for _, m := range members {
		if m.Status != MemberActive {
			continue
		}
		teamMembers = append(teamMembers, gitlab.WorkspaceTeamMember{UserID: m.UserID, Lead: m.Role == RoleOwner || m.Role == RoleManager})
	}

	slug := generateGitlabSlug(project.KeyPrefix, project.ID)
	team, err := s.gitlab.ProvisionWorkspaceProject(ctx, pc.OrgID, pc.UserID, project.Title, slug, installationID, teamMembers)
	if err != nil {
		return nil, fmt.Errorf("workspace: provision gitlab: %w", err)
	}
	if err := s.repo.SetProjectTeamID(ctx, s.pool, pc.ProjectID, team.ID); err != nil {
		return nil, fmt.Errorf("workspace: provision gitlab: persist team id: %w", err)
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.gitlab_provisioned", "workspace_project", pc.ProjectID, map[string]string{"team_id": team.ID})
	return s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
}

// generateGitlabSlug builds a URL-safe, reasonably unique GitLab project
// path from the workspace's key prefix — lowercased, plus the first 8 chars
// of the project's own id so two same-prefix orgs (key prefixes aren't
// globally unique, only per-org — see D7) never collide inside GitLab's own
// (also-global, per-namespace) path requirement.
func generateGitlabSlug(keyPrefix, projectID string) string {
	suffix := projectID
	if len(suffix) > 8 {
		suffix = suffix[:8]
	}
	return fmt.Sprintf("%s-%s", toLowerASCII(keyPrefix), suffix)
}

func toLowerASCII(s string) string {
	b := []byte(s)
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			b[i] = c + ('a' - 'A')
		}
	}
	return string(b)
}

// ─── best-effort GitLab access grant/revoke (4c) ───────────────────────────

// grantGitlabAccess adds userID to the project's GitLab roster after they're
// added/reactivated — best-effort, never fails the member-add/re-add call
// that triggered it. No-op if the project has no GitLab team yet.
func (s *Service) grantGitlabAccess(ctx context.Context, orgID, teamID, userID string, lead bool) {
	if s.gitlab == nil {
		return
	}
	if err := s.gitlab.GrantWorkspaceAccess(ctx, orgID, teamID, userID, lead); err != nil {
		slog.ErrorContext(ctx, "workspace: grant gitlab access failed", "team_id", teamID, "user_id", userID, "error", err)
	}
}

// revokeGitlabAccess removes userID from the project's GitLab roster after
// they leave/are removed — best-effort, same shape as grantGitlabAccess.
func (s *Service) revokeGitlabAccess(ctx context.Context, orgID, teamID, userID string) {
	if s.gitlab == nil {
		return
	}
	if err := s.gitlab.RevokeWorkspaceAccess(ctx, orgID, teamID, userID); err != nil {
		slog.ErrorContext(ctx, "workspace: revoke gitlab access failed", "team_id", teamID, "user_id", userID, "error", err)
	}
}

// SyncGitlabReviewers is the workspace.gitlab_sync job body — retries one
// pending reviewer-sync (contract-phase4.md 4a step 5's "retry with backoff
// via jobs MaxRetries"); the job system's own retry/backoff handles repeated
// failures, so this makes exactly one attempt per invocation.
func (s *Service) SyncGitlabReviewers(ctx context.Context, orgID, teamID, itemID, mrRef string) error {
	if s.gitlab == nil {
		return errors.New("workspace: gitlab dependency not configured")
	}
	if err := s.attemptMRReviewerSync(ctx, orgID, teamID, itemID, mrRef); err != nil {
		return fmt.Errorf("workspace: sync gitlab reviewers: %w", err)
	}
	return s.repo.SetGitlabLinkSyncStatus(ctx, s.pool, itemID, GitlabRefMR, mrRef, "synced")
}

// ListItemGitlabLinks is GET …/items/{itemID}/gitlab (viewer).
func (s *Service) ListItemGitlabLinks(ctx context.Context, pc *ProjectCtx, itemID string) ([]GitlabLink, error) {
	item, err := s.repo.GetWorkItemByID(ctx, s.pool, pc.ProjectID, itemID)
	if err != nil {
		return nil, err
	}
	return s.repo.ListItemGitlabLinks(ctx, s.pool, item.ID)
}

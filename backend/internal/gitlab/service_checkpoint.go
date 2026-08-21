package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/notifications"
)

// ─── Checkpoint CRUD (staff) ────────────────────────────────────────────────

// CreateCheckpoint inserts a new checkpoint under an assignment. A
// non-positive Position auto-assigns the next free position (append to the
// end) so callers building a simple "add checkpoint" UI don't need to
// compute it themselves. Best-effort creates a matching GitLab group
// milestone (see maybeCreateGitlabMilestone) so issues tagged with it map
// back to this checkpoint via the Issue Hook (ingestIssueEvent) — this is
// what actually closes the checkpoint -> milestone -> issue -> burndown
// chain; a failure here (assignment not provisioned yet, no installation,
// API error) never blocks checkpoint creation itself.
func (s *Service) CreateCheckpoint(ctx context.Context, orgID, assignmentID string, cp ProjectCheckpoint) (*ProjectCheckpoint, error) {
	if cp.Position <= 0 {
		pos, err := s.repo.NextCheckpointPosition(ctx, assignmentID)
		if err != nil {
			return nil, fmt.Errorf("gitlab: create checkpoint: %w", err)
		}
		cp.Position = pos
	}
	// The HTTP handler already defaults an omitted kind to
	// CheckpointKindMilestone, but that default belongs here too: the
	// column has no bare NOT NULL default fallback once a value is supplied
	// at all (migration 022's CHECK constraint rejects "" outright), so any
	// non-HTTP caller — a test, a future internal call — that leaves Kind
	// unset would otherwise fail the CHECK instead of getting the sane
	// default the handler gives every real request.
	if cp.Kind == "" {
		cp.Kind = CheckpointKindMilestone
	}
	cp.OrgID = orgID
	cp.AssignmentID = assignmentID
	created, err := s.repo.CreateCheckpoint(ctx, cp)
	if err != nil {
		return nil, fmt.Errorf("gitlab: create checkpoint: %w", err)
	}
	s.maybeCreateGitlabMilestone(ctx, orgID, created)
	return created, nil
}

// maybeCreateGitlabMilestone creates a GitLab group milestone for a
// newly-created checkpoint and stores its ID on gitlab_milestone_id — the
// write side of the milestone<->checkpoint mapping FindCheckpointByMilestone
// reads back on the Issue Hook. Best-effort only, same treatment as
// maybeCreateEEApprovalRule: no installation, no client, the assignment's
// GitLab subgroup not provisioned yet (GitlabGroupID nil — happens whenever
// a checkpoint is created before the assignment's first team is
// provisioned), or any API error all just log and leave gitlab_milestone_id
// NULL, which is the correct, expected state until this succeeds.
func (s *Service) maybeCreateGitlabMilestone(ctx context.Context, orgID string, cp *ProjectCheckpoint) {
	assignment, err := s.repo.GetAssignment(ctx, orgID, cp.AssignmentID)
	if err != nil || assignment.GitlabGroupID == nil {
		return
	}
	client, err := s.clientFor(ctx, orgID, assignment.InstallationID)
	if err != nil {
		return
	}
	var dueDate *string
	if cp.DueAt != nil {
		d := cp.DueAt.Format("2006-01-02")
		dueDate = &d
	}
	milestone, err := client.CreateGroupMilestone(ctx, *assignment.GitlabGroupID, cp.Title, dueDate)
	if err != nil {
		slog.WarnContext(ctx, "gitlab: create group milestone failed (continuing without it — burndown/issue mapping stays unset for this checkpoint)",
			"checkpoint_id", cp.ID, "assignment_id", cp.AssignmentID, "error", err)
		return
	}
	if err := s.repo.SetCheckpointMilestoneID(ctx, cp.ID, milestone.ID); err != nil {
		slog.ErrorContext(ctx, "gitlab: set checkpoint milestone id failed", "checkpoint_id", cp.ID, "milestone_id", milestone.ID, "error", err)
		return
	}
	cp.GitlabMilestoneID = &milestone.ID
}

// ListCheckpoints lists an assignment's checkpoints in position order, each
// with every team's submission row against it embedded (see
// Repo.ListCheckpoints's own doc comment).
func (s *Service) ListCheckpoints(ctx context.Context, orgID, assignmentID string) ([]CheckpointWithSubmissions, error) {
	list, err := s.repo.ListCheckpoints(ctx, orgID, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list checkpoints: %w", err)
	}
	return list, nil
}

// GetCheckpoint returns a single org-scoped checkpoint.
func (s *Service) GetCheckpoint(ctx context.Context, orgID, id string) (*ProjectCheckpoint, error) {
	return s.repo.GetCheckpoint(ctx, orgID, id)
}

// UpdateCheckpoint applies a partial patch to a checkpoint.
func (s *Service) UpdateCheckpoint(ctx context.Context, orgID, id string, patch CheckpointPatch) (*ProjectCheckpoint, error) {
	return s.repo.UpdateCheckpoint(ctx, orgID, id, patch)
}

// DeleteCheckpoint removes a checkpoint (cascades its submission rows).
func (s *Service) DeleteCheckpoint(ctx context.Context, orgID, id string) error {
	return s.repo.DeleteCheckpoint(ctx, orgID, id)
}

// ─── Submissions (staff) ─────────────────────────────────────────────────────

// ListSubmissions lists every team's submission row for a checkpoint.
func (s *Service) ListSubmissions(ctx context.Context, orgID, checkpointID string) ([]ProjectTeamCheckpoint, error) {
	if _, err := s.repo.GetCheckpoint(ctx, orgID, checkpointID); err != nil {
		return nil, err
	}
	return s.repo.ListTeamCheckpointsByCheckpoint(ctx, checkpointID)
}

// GradeSubmission records an instructor's score/feedback for one team's
// checkpoint submission, transitioning it to 'graded'. Grading intentionally
// fires no notification in this batch (kind-herding-cookie.md §0.6's own
// spirit — add one when a user actually asks for "notify me when graded",
// not speculatively; getting a re-grade's dedupe_key right — a fresh
// notification per grade change, not just per checkpoint — is a real design
// question this batch doesn't need to answer yet).
func (s *Service) GradeSubmission(ctx context.Context, orgID, teamID, checkpointID string, gradedBy string, patch GradePatch) (*ProjectTeamCheckpoint, error) {
	if _, err := s.repo.GetTeam(ctx, orgID, teamID); err != nil {
		return nil, err
	}
	if _, err := s.repo.GetCheckpoint(ctx, orgID, checkpointID); err != nil {
		return nil, err
	}
	updated, err := s.repo.GradeTeamCheckpoint(ctx, teamID, checkpointID, patch.Score, patch.Feedback, gradedBy)
	if err != nil {
		return nil, fmt.Errorf("gitlab: grade submission: %w", err)
	}
	return updated, nil
}

// PostCheckpointComment posts a staff comment directly onto the team's bound
// merge request via GitLab's own notes API.
func (s *Service) PostCheckpointComment(ctx context.Context, orgID, teamID, checkpointID, body string) error {
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return err
	}
	if team.GitlabProjectID == nil {
		return fmt.Errorf("gitlab: post checkpoint comment: %w: team has no provisioned GitLab project", ErrConflict)
	}
	ptc, err := s.repo.GetTeamCheckpoint(ctx, teamID, checkpointID)
	if err != nil {
		return err
	}
	if ptc.MRIID == nil {
		return fmt.Errorf("gitlab: post checkpoint comment: %w: no merge request submitted for this checkpoint yet", ErrConflict)
	}
	assignment, err := s.repo.GetAssignmentByID(ctx, team.AssignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: post checkpoint comment: get assignment: %w", err)
	}
	client, err := s.clientFor(ctx, orgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("gitlab: post checkpoint comment: %w", err)
	}
	if _, err := client.CreateMRNote(ctx, *team.GitlabProjectID, *ptc.MRIID, body); err != nil {
		return fmt.Errorf("gitlab: post checkpoint comment: %w", err)
	}
	return nil
}

// ─── Merge gate (§0.4 — money/security-adjacent) ───────────────────────────

// TryMergeCheckpoint is the merge gate: the one piece of logic in this whole
// batch that actually approves a real code merge, so it is written
// defensively. required_approvals lives on the checkpoint's parent
// ProjectAssignment, not on ProjectCheckpoint itself — migration 023 gives
// project_checkpoints no such column (confirmed by reading the migration
// directly; a prior assumption that it lived there was wrong).
//
// The approvals_count check happens entirely from a fresh DB read, before
// any GitLab API call — never a stale in-memory value, and structured this
// way (gate first, network call only after the gate passes) so the
// rejection path is unit-testable with zero network/mock dependency: if
// approvals_count is insufficient, this returns before ever touching
// s.clientFor or client.MergeMergeRequest.
//
// Ordering, reasoned through explicitly: the DB write that marks a
// checkpoint 'merged' happens strictly AFTER a successful GitLab merge call,
// never before and never concurrently with it.
//   - If GitLab's merge call fails after a premature DB write, MindForge
//     would show "merged" for a team whose code never actually merged — a
//     false-positive state with no natural correction path.
//   - Doing it the other way (GitLab merges, then the process crashes before
//     the DB write lands) is self-healing instead: GitLab always fires a
//     Merge Request webhook event on a real merge, and that event's normal
//     ingest path (bindMRToCheckpoint -> UpsertTeamCheckpointMR) re-syncs
//     mr_state='merged' the next time it's processed, independent of this
//     function ever completing.
//
// A false-positive "merged" with no recovery path is strictly worse than a
// missed DB write with an automatic recovery path, so GitLab-call-first,
// DB-write-second is the deliberate choice here.
func (s *Service) TryMergeCheckpoint(ctx context.Context, orgID, teamID, checkpointID string) (*ProjectTeamCheckpoint, error) {
	team, err := s.repo.GetTeam(ctx, orgID, teamID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: get team: %w", err)
	}
	if team.GitlabProjectID == nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: %w: team has no provisioned GitLab project", ErrConflict)
	}

	cp, err := s.repo.GetCheckpoint(ctx, orgID, checkpointID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: get checkpoint: %w", err)
	}
	assignment, err := s.repo.GetAssignment(ctx, orgID, cp.AssignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: get assignment: %w", err)
	}

	// Fresh read, immediately before the decision — never a value the caller
	// might have loaded earlier in the request.
	ptc, err := s.repo.GetTeamCheckpoint(ctx, teamID, checkpointID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: get team checkpoint: %w", err)
	}
	if ptc.Status == CheckpointStatusMerged || ptc.Status == CheckpointStatusGraded {
		// Already merged (or graded past it) — nothing to do, and definitely
		// not a second merge call.
		return ptc, nil
	}
	if ptc.MRIID == nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: %w: no merge request submitted for this checkpoint yet", ErrConflict)
	}
	if ptc.ApprovalsCount < assignment.RequiredApprovals {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: %w: %d of %d required approvals",
			ErrInsufficientApprovals, ptc.ApprovalsCount, assignment.RequiredApprovals)
	}
	if cp.RequiresCIPass && ptc.CIStatus != CIStatusSuccess {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: %w: CI status is %q, not %q", ErrConflict, ptc.CIStatus, CIStatusSuccess)
	}

	client, err := s.clientFor(ctx, orgID, assignment.InstallationID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: resolve client: %w", err)
	}
	if _, err := client.MergeMergeRequest(ctx, *team.GitlabProjectID, *ptc.MRIID); err != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: gitlab merge call: %w", err)
	}

	// Only now, after GitLab confirms the merge: record the status
	// transition AND notify the team, together in one transaction — either
	// both land or neither does (see this function's own doc comment for the
	// full ordering reasoning; this is the "multi-table write in a
	// transaction" this batch's own rules call for).
	members, listErr := s.repo.ListTeamMembers(ctx, teamID)
	if listErr != nil {
		slog.ErrorContext(ctx, "gitlab: try merge checkpoint: list team members for notification failed", "team_id", teamID, "error", listErr)
	}
	var updated *ProjectTeamCheckpoint
	txErr := s.repo.tx(ctx, func(tx pgx.Tx) error {
		var setErr error
		updated, setErr = s.repo.SetTeamCheckpointStatus(ctx, tx, teamID, checkpointID, CheckpointStatusMerged)
		if setErr != nil {
			return setErr
		}
		if len(members) == 0 || s.notifications == nil {
			return nil
		}
		recipients := make([]string, 0, len(members))
		for _, m := range members {
			recipients = append(recipients, m.UserID)
		}
		return s.notifications.NotifyMany(ctx, tx, notifications.New{
			OrgID:      orgID,
			Type:       "gitlab.mr_merged",
			Title:      fmt.Sprintf("Checkpoint %q was merged", cp.Title),
			LinkURL:    updated.MRWebURL,
			EntityType: strPtr("project_team_checkpoint"),
			EntityID:   &updated.ID,
			Priority:   notifications.PriorityNormal,
			DedupeKey:  fmt.Sprintf("gitlab.checkpoint_merged:%s", updated.ID),
		}, recipients)
	})
	if txErr != nil {
		return nil, fmt.Errorf("gitlab: try merge checkpoint: record merged status: %w", txErr)
	}
	return updated, nil
}

// ─── MR-as-submission binding + approval enforcement (§0.4) ────────────────

// mrStateToCheckpointStatus maps a GitLab MR state to the checkpoint status
// transition it should cause (nil = leave the existing status untouched) —
// per this batch's own scope decision, only opened->submitted and
// merged->merged are modeled; closed/locked MRs don't move a checkpoint's
// status (an instructor can still see the MR itself closed via mr_state).
func mrStateToCheckpointStatus(state string) *string {
	var status string
	switch state {
	case MRStateOpened:
		status = CheckpointStatusSubmitted
	case MRStateMerged:
		status = CheckpointStatusMerged
	default:
		return nil
	}
	return &status
}

// bindMRToCheckpoint is Batch 5's MR-as-submission binding, called from
// service_webhook.go's ingestMergeRequestEvent after the MR mirror upsert.
// Binding rule (deliberately simple, per kind-herding-cookie.md's "bind to
// open checkpoint" — no branch-name parsing or other cleverness): bind to
// the lowest-position checkpoint under the team's assignment whose team-row
// isn't already graded (Repo.FindOpenCheckpointForTeam). An assignment with
// no checkpoints configured yet is correctly a no-op.
func (s *Service) bindMRToCheckpoint(ctx context.Context, team *ProjectTeam, mr *GitlabMergeRequest, state string) error {
	cp, err := s.repo.FindOpenCheckpointForTeam(ctx, team.AssignmentID, team.ID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil
		}
		return fmt.Errorf("find open checkpoint for mr bind: %w", err)
	}

	_, getErr := s.repo.GetTeamCheckpoint(ctx, team.ID, cp.ID)
	firstActivation := errors.Is(getErr, ErrNotFound)
	if getErr != nil && !firstActivation {
		return fmt.Errorf("get team checkpoint before bind: %w", getErr)
	}

	var mrID int64
	if mr.MRID != nil {
		mrID = *mr.MRID
	}
	var webURL string
	if mr.WebURL != nil {
		webURL = *mr.WebURL
	}
	newStatus := mrStateToCheckpointStatus(state)

	updated, err := s.repo.UpsertTeamCheckpointMR(ctx, team.OrgID, team.ID, cp.ID, mr.MRIID, mrID, webURL, state, newStatus)
	if err != nil {
		return fmt.Errorf("upsert team checkpoint mr: %w", err)
	}

	if firstActivation {
		s.maybeCreateEEApprovalRule(ctx, team, cp)
	}

	// Recompute in case approval notes already exist against this MR (e.g.
	// it's reopening after prior review activity) — self-contained, cheap,
	// and idempotent, so it's safe to call unconditionally here too.
	if err := s.repo.RecomputeCheckpointApprovals(ctx, mr.ID); err != nil {
		slog.ErrorContext(ctx, "gitlab: recompute checkpoint approvals after mr bind failed", "mr_id", mr.ID, "error", err)
	}

	switch state {
	case MRStateOpened:
		s.notifyTeam(ctx, team, notifications.New{
			Type:       "gitlab.review_requested",
			Title:      fmt.Sprintf("Merge request opened for %q — review requested", cp.Title),
			LinkURL:    mr.WebURL,
			EntityType: strPtr("project_team_checkpoint"),
			EntityID:   &updated.ID,
			Priority:   notifications.PriorityNormal,
			DedupeKey:  fmt.Sprintf("gitlab.review_requested:%s:%d", team.ID, mr.MRIID),
		})
	case MRStateMerged:
		s.notifyTeam(ctx, team, notifications.New{
			Type:       "gitlab.mr_merged",
			Title:      fmt.Sprintf("Merge request for %q was merged", cp.Title),
			LinkURL:    mr.WebURL,
			EntityType: strPtr("project_team_checkpoint"),
			EntityID:   &updated.ID,
			Priority:   notifications.PriorityNormal,
			DedupeKey:  fmt.Sprintf("gitlab.mr_merged:%s:%d", team.ID, mr.MRIID),
		})
	}
	return nil
}

// maybeCreateEEApprovalRule implements kind-herding-cookie.md §0.4's layer-2
// dual approval enforcement: when the org's GitLab tier is premium/ultimate,
// also create a real GitLab approval rule on the team's project so GitLab
// itself enforces the same requirement server-side. Fired once, at the
// simpler of the two trigger points the plan allows ("checkpoint creation"
// vs. "a checkpoint's MR-binding first activates") — first activation was
// chosen because it already has the team's real GitlabProjectID in hand with
// no extra lookups, whereas firing at checkpoint-creation time would need to
// loop over every currently-provisioned team under the assignment (and still
// miss any team provisioned later). Best-effort only: a Free/CE
// installation, or any API error (rate limit, transient failure), must never
// block anything — this is a nice-to-have server-side mirror, not the real
// gate (TryMergeCheckpoint is).
func (s *Service) maybeCreateEEApprovalRule(ctx context.Context, team *ProjectTeam, cp *ProjectCheckpoint) {
	if team.GitlabProjectID == nil {
		return
	}
	assignment, err := s.repo.GetAssignmentByID(ctx, cp.AssignmentID)
	if err != nil {
		slog.WarnContext(ctx, "gitlab: ee approval rule: resolve assignment failed", "checkpoint_id", cp.ID, "error", err)
		return
	}
	inst, err := s.resolveInstallation(ctx, team.OrgID, assignment.InstallationID)
	if err != nil {
		return
	}
	if inst.Tier != TierPremium && inst.Tier != TierUltimate {
		return
	}
	client, err := s.clientFor(ctx, team.OrgID, assignment.InstallationID)
	if err != nil {
		slog.WarnContext(ctx, "gitlab: ee approval rule: resolve client failed", "team_id", team.ID, "error", err)
		return
	}
	name := fmt.Sprintf("MindForge: %s", cp.Title)
	if _, err := client.CreateApprovalRule(ctx, *team.GitlabProjectID, name, assignment.RequiredApprovals); err != nil {
		slog.WarnContext(ctx, "gitlab: ee approval rule creation failed (continuing without it — MindForge's own gate still enforces the requirement)",
			"team_id", team.ID, "checkpoint_id", cp.ID, "error", err)
	}
}

// ─── Pipeline -> ci_status mirror ───────────────────────────────────────────

// mirrorPipelineToCheckpoint updates the relevant project_team_checkpoints
// row's ci_status/ci_pipeline_id for an incoming pipeline event, called from
// service_webhook.go's ingestPipelineEvent. Simplest correct join, per this
// batch's own scope decision: a pipeline webhook payload carries only a
// sha/ref, not an MR reference, so rather than matching sha against every
// checkpoint's snapshot_sha (not populated until Batch 6's deadline-snapshot
// job exists), this mirrors onto the team's currently-open checkpoint — the
// same FindOpenCheckpointForTeam rule MR-binding uses — since that's the one
// row actually "in flight" for this team right now. A team with no open
// checkpoint, or no submission row yet for it, simply has nothing to mirror
// onto; neither case is an error.
func (s *Service) mirrorPipelineToCheckpoint(ctx context.Context, team *ProjectTeam, pipelineID int64, status string, webURL *string) error {
	cp, err := s.repo.FindOpenCheckpointForTeam(ctx, team.AssignmentID, team.ID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil
		}
		return fmt.Errorf("find open checkpoint for pipeline mirror: %w", err)
	}

	updated, err := s.repo.UpdateTeamCheckpointCIStatus(ctx, team.ID, cp.ID, status, pipelineID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil
		}
		return fmt.Errorf("update checkpoint ci status: %w", err)
	}

	if status == CIStatusFailed {
		s.notifyTeam(ctx, team, notifications.New{
			Type:       "gitlab.ci_failed",
			Title:      fmt.Sprintf("CI failed on %s", team.Name),
			Body:       strPtr(fmt.Sprintf("The pipeline for checkpoint %q failed.", cp.Title)),
			LinkURL:    webURL,
			EntityType: strPtr("project_team_checkpoint"),
			EntityID:   &updated.ID,
			Priority:   notifications.PriorityHigh,
			DedupeKey:  fmt.Sprintf("gitlab.ci_failed:%s:%d", team.ID, pipelineID),
			AlsoEmail:  true,
		})
	}
	return nil
}

// ─── notification helpers ───────────────────────────────────────────────────

// notifyTeam fires one notification to every member of team, best-effort —
// failures are logged, never propagated, since a notification miss must
// never fail webhook ingest (same "log and continue" treatment Batch 3 gives
// FlagLateCommits/enqueueCommitStats errors).
func (s *Service) notifyTeam(ctx context.Context, team *ProjectTeam, n notifications.New) {
	if s.notifications == nil {
		return
	}
	members, err := s.repo.ListTeamMembers(ctx, team.ID)
	if err != nil {
		slog.ErrorContext(ctx, "gitlab: notify team: list members failed", "team_id", team.ID, "type", n.Type, "error", err)
		return
	}
	recipients := make([]string, 0, len(members))
	for _, m := range members {
		recipients = append(recipients, m.UserID)
	}
	if len(recipients) == 0 {
		return
	}
	n.OrgID = team.OrgID
	if err := s.repo.tx(ctx, func(tx pgx.Tx) error {
		return s.notifications.NotifyMany(ctx, tx, n, recipients)
	}); err != nil {
		slog.ErrorContext(ctx, "gitlab: notify team failed", "team_id", team.ID, "type", n.Type, "error", err)
	}
}

// notifyUser fires one notification to a single user, best-effort (see
// notifyTeam's own doc comment for why failures are only logged).
func (s *Service) notifyUser(ctx context.Context, orgID, userID string, n notifications.New) {
	if s.notifications == nil {
		return
	}
	n.OrgID = orgID
	n.UserID = userID
	if err := s.repo.tx(ctx, func(tx pgx.Tx) error {
		return s.notifications.Notify(ctx, tx, n)
	}); err != nil {
		slog.ErrorContext(ctx, "gitlab: notify user failed", "user_id", userID, "type", n.Type, "error", err)
	}
}

// strPtr is a tiny local helper for taking the address of a string literal
// inline (Go has no way to do this without a named variable) — used
// throughout this file's notification construction.
func strPtr(s string) *string { return &s }

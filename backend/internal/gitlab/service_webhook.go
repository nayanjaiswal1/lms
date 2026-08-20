package gitlab

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
)

// Job handler keys for this file's jobs — see service_provision.go's own
// jobProvisionTeam/jobSyncMembers doc comment for why these are plain string
// literals rather than a shared constants import (internal/jobs/handlers
// imports this package, so this package cannot import it back). MUST stay in
// sync with handlers.HandlerGitlabIngestEvent/HandlerGitlabCommitStats/
// HandlerGitlabPollSync in internal/jobs/handlers/constants.go.
const (
	jobIngestEvent = "gitlab.ingest_event"
	jobCommitStats = "gitlab.commit_stats"
)

const (
	ingestEventTimeoutMS = 30000
	commitStatsTimeoutMS = 60000
)

// GitLab's webhook event-type header values (X-Gitlab-Event) — the exact
// strings GitLab sends, not this app's own naming.
const (
	glEventPush         = "Push Hook"
	glEventMergeRequest = "Merge Request Hook"
	glEventNote         = "Note Hook"
	glEventPipeline     = "Pipeline Hook"
	glEventIssue        = "Issue Hook"
)

// HandleWebhook is the synchronous half of the GitLab webhook flow (see
// handler_webhook.go's Webhook for the "return 200 fast" rationale): resolve
// which org's installation owns gitlabProjectID, verify X-Gitlab-Token in
// constant time against that installation's decrypted webhook secret,
// dedupe-insert the raw event keyed on eventUUID, and — only on an actual
// fresh insert, never on a redelivery conflict — enqueue gitlab.ingest_event
// to do the real dispatching off the request path. Returns
// ErrInvalidWebhookToken (mapped to 401 by the handler) when the token
// doesn't match; any other returned error is logged and still answered 200,
// per kind-herding-cookie.md §4 ("never trust payload as authoritative...
// GitLab disables hooks that time out").
func (s *Service) HandleWebhook(ctx context.Context, gitlabProjectID int64, eventType, eventUUID, token string, payload []byte) error {
	team, err := s.repo.GetTeamByGitlabProjectID(ctx, gitlabProjectID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			// Not a project this installation provisioned (or the team row
			// was since deleted) — nothing to verify against, nothing to record.
			return nil
		}
		return fmt.Errorf("gitlab: handle webhook: resolve team: %w", err)
	}

	// Resolved through the team's own assignment, not just "the org's"
	// installation — an org with multiple pool entries may have provisioned
	// this specific project against a non-default one, and only that one's
	// webhook secret will actually match what GitLab sent.
	assignment, err := s.repo.GetAssignmentByID(ctx, team.AssignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: handle webhook: get assignment: %w", err)
	}
	inst, err := s.resolveInstallation(ctx, team.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("gitlab: handle webhook: get installation: %w", err)
	}
	if inst.WebhookSecretEnc == nil {
		return ErrInvalidWebhookToken
	}
	secret, err := s.vault.Decrypt(inst.WebhookSecretEnc)
	if err != nil {
		return fmt.Errorf("gitlab: handle webhook: decrypt webhook secret: %w", err)
	}
	if subtle.ConstantTimeCompare([]byte(token), secret) != 1 {
		return ErrInvalidWebhookToken
	}

	eventID := uuid.NewString()
	inserted, err := s.repo.InsertWebhookEvent(ctx, eventID, team.OrgID, gitlabProjectID, eventType, eventUUID, payload)
	if err != nil {
		return fmt.Errorf("gitlab: handle webhook: insert event: %w", err)
	}
	if !inserted {
		// Redelivery of an event already recorded — GitLab retries on
		// timeout/5xx, so this is the expected common case, not an error.
		return nil
	}

	timeout := ingestEventTimeoutMS
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler:   jobIngestEvent,
		Priority:  jobs.PriorityHigh,
		Payload:   map[string]string{"event_id": eventID},
		OrgID:     &team.OrgID,
		TimeoutMS: &timeout,
	}); err != nil {
		return fmt.Errorf("gitlab: handle webhook: enqueue ingest_event: %w", err)
	}
	return nil
}

// IngestEvent is the gitlab.ingest_event job body: loads webhook event
// eventID and dispatches by event_type per kind-herding-cookie.md §4's
// table, marking the row dispatched/ignored/failed. MR/Pipeline/Issue
// checkpoint-binding steps that table also lists are Batch 5/6's concern
// (project_team_checkpoints has no CRUD to create real rows until then) —
// each ingest* helper below upserts its own activity-mirror row correctly
// and simply omits the checkpoint cross-reference, noted inline.
func (s *Service) IngestEvent(ctx context.Context, eventID string) error {
	event, err := s.repo.GetWebhookEvent(ctx, eventID)
	if err != nil {
		return fmt.Errorf("gitlab: ingest event: get event: %w", err)
	}
	if event.ProjectID == nil {
		return s.repo.MarkWebhookEventStatus(ctx, eventID, WebhookEventIgnored, nil)
	}

	team, err := s.repo.GetTeamByGitlabProjectID(ctx, *event.ProjectID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			msg := "no project_teams row for this project_id"
			return s.repo.MarkWebhookEventStatus(ctx, eventID, WebhookEventIgnored, &msg)
		}
		return fmt.Errorf("gitlab: ingest event: resolve team: %w", err)
	}

	var dispatchErr error
	switch event.EventType {
	case glEventPush:
		dispatchErr = s.ingestPushEvent(ctx, team, event.Payload)
	case glEventMergeRequest:
		dispatchErr = s.ingestMergeRequestEvent(ctx, team, event.Payload)
	case glEventNote:
		dispatchErr = s.ingestNoteEvent(ctx, team, event.Payload)
	case glEventPipeline:
		dispatchErr = s.ingestPipelineEvent(ctx, team, event.Payload)
	case glEventIssue:
		dispatchErr = s.ingestIssueEvent(ctx, team, event.Payload)
	default:
		return s.repo.MarkWebhookEventStatus(ctx, eventID, WebhookEventIgnored, nil)
	}

	if dispatchErr != nil {
		msg := dispatchErr.Error()
		if markErr := s.repo.MarkWebhookEventStatus(ctx, eventID, WebhookEventFailed, &msg); markErr != nil {
			slog.ErrorContext(ctx, "gitlab: mark webhook event failed", "event_id", eventID, "error", markErr)
		}
		return fmt.Errorf("gitlab: ingest event %s (%s): %w", eventID, event.EventType, dispatchErr)
	}
	return s.repo.MarkWebhookEventStatus(ctx, eventID, WebhookEventDispatched, nil)
}

// ─── Push ───────────────────────────────────────────────────────────────────

type pushEventPayload struct {
	Ref     string `json:"ref"`
	UserID  *int64 `json:"user_id"`
	Commits []struct {
		ID        string `json:"id"`
		Message   string `json:"message"`
		Timestamp string `json:"timestamp"`
		Author    struct {
			Name  string `json:"name"`
			Email string `json:"email"`
		} `json:"author"`
		// Added/Modified/Removed are GitLab's own per-commit changed-file
		// lists — Batch 8's feature-ownership aggregation reads these
		// straight off the push payload (see UpsertCommitFiles), no extra
		// GitLab API call needed.
		Added    []string `json:"added"`
		Modified []string `json:"modified"`
		Removed  []string `json:"removed"`
	} `json:"commits"`
}

// ingestPushEvent upserts one gitlab_commits row per commit in the push,
// flags any already-snapshotted checkpoint as late per commit landing after
// its snapshot (FlagLateCommits — a no-op until Batch 5 creates checkpoint
// rows), and enqueues gitlab.commit_stats once if the push carried any
// commits at all. ponytail: a push webhook's per-commit author has no GitLab
// numeric user ID (only name/email) — the whole push's top-level user_id
// (the pusher) is used for every commit in it, which is exactly right for
// the common single-author push and only approximate for a multi-author
// push (e.g. after a rebase); refine via a follow-up GetCommit-derived
// author lookup if Batch 4's contribution tracking needs per-commit
// precision.
func (s *Service) ingestPushEvent(ctx context.Context, team *ProjectTeam, raw []byte) error {
	var p pushEventPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("decode push event: %w", err)
	}
	branch := strings.TrimPrefix(p.Ref, "refs/heads/")

	var userID *string
	if p.UserID != nil {
		if id, err := s.repo.FindUserIDByGitlabUserID(ctx, team.OrgID, *p.UserID); err == nil {
			userID = id
		}
	}

	for _, c := range p.Commits {
		committedAt := parseGitlabTime(c.Timestamp)
		name, email, msg := c.Author.Name, c.Author.Email, c.Message
		if err := s.repo.UpsertCommit(ctx, GitlabCommit{
			OrgID: team.OrgID, TeamID: team.ID, SHA: c.ID, Branch: &branch,
			AuthorGitlabUserID: p.UserID, UserID: userID,
			AuthorEmail: &email, AuthorName: &name, Message: &msg,
			CommittedAt: committedAt,
		}); err != nil {
			return fmt.Errorf("upsert commit %s: %w", c.ID, err)
		}
		if len(c.Added) > 0 || len(c.Modified) > 0 || len(c.Removed) > 0 {
			if err := s.repo.UpsertCommitFiles(ctx, team.OrgID, team.ID, c.ID, p.UserID, userID, committedAt, c.Added, c.Modified, c.Removed); err != nil {
				slog.ErrorContext(ctx, "gitlab: upsert commit files failed", "team_id", team.ID, "sha", c.ID, "error", err)
			}
		}
		if committedAt != nil {
			if err := s.repo.FlagLateCommits(ctx, team.ID, *committedAt); err != nil {
				slog.ErrorContext(ctx, "gitlab: flag late commits failed", "team_id", team.ID, "sha", c.ID, "error", err)
			}
		}
	}

	if len(p.Commits) > 0 {
		if err := s.enqueueCommitStats(ctx, team.OrgID); err != nil {
			slog.ErrorContext(ctx, "gitlab: enqueue commit_stats failed", "team_id", team.ID, "error", err)
		}
	}
	return nil
}

func (s *Service) enqueueCommitStats(ctx context.Context, orgID string) error {
	timeout := commitStatsTimeoutMS
	_, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler: jobCommitStats, Priority: jobs.PriorityNormal, Payload: map[string]string{}, OrgID: &orgID, TimeoutMS: &timeout,
	})
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("gitlab: enqueue commit_stats: %w", err)
	}
	return nil
}

// FetchPendingCommitStats is the gitlab.commit_stats job body: fetches
// per-sha diff stats (additions/deletions) for up to limit commits still
// missing them, batched so one job run never has to walk an unbounded
// backlog.
func (s *Service) FetchPendingCommitStats(ctx context.Context, limit int) error {
	pending, err := s.repo.ListCommitsPendingStats(ctx, limit)
	if err != nil {
		return fmt.Errorf("gitlab: fetch pending commit stats: %w", err)
	}

	teamCache := map[string]*ProjectTeam{}
	clientCache := map[string]*Client{}

	for _, c := range pending {
		team, ok := teamCache[c.TeamID]
		if !ok {
			t, err := s.repo.GetTeamByID(ctx, c.TeamID)
			if err != nil {
				slog.ErrorContext(ctx, "gitlab: commit_stats: resolve team failed", "team_id", c.TeamID, "error", err)
				continue
			}
			teamCache[c.TeamID] = t
			team = t
		}
		if team.GitlabProjectID == nil {
			continue
		}

		client, ok := clientCache[team.AssignmentID]
		if !ok {
			cl, err := s.clientForTeam(ctx, team.OrgID, team.AssignmentID)
			if err != nil {
				slog.ErrorContext(ctx, "gitlab: commit_stats: resolve client failed", "org_id", team.OrgID, "error", err)
				continue
			}
			clientCache[team.AssignmentID] = cl
			client = cl
		}

		commit, err := client.GetCommit(ctx, *team.GitlabProjectID, c.SHA)
		if err != nil {
			slog.ErrorContext(ctx, "gitlab: commit_stats: get commit failed", "team_id", c.TeamID, "sha", c.SHA, "error", err)
			continue
		}
		additions, deletions := 0, 0
		if commit.Stats != nil {
			additions, deletions = commit.Stats.Additions, commit.Stats.Deletions
		}
		if err := s.repo.UpdateCommitStats(ctx, c.ID, additions, deletions); err != nil {
			slog.ErrorContext(ctx, "gitlab: commit_stats: update stats failed", "commit_id", c.ID, "error", err)
		}
	}
	return nil
}

// ─── Merge Request ──────────────────────────────────────────────────────────

type mrEventPayload struct {
	ObjectAttributes struct {
		IID          int64  `json:"iid"`
		ID           int64  `json:"id"`
		Title        string `json:"title"`
		Description  string `json:"description"`
		State        string `json:"state"`
		SourceBranch string `json:"source_branch"`
		TargetBranch string `json:"target_branch"`
		URL          string `json:"url"`
		CreatedAt    string `json:"created_at"`
	} `json:"object_attributes"`
	User struct {
		ID int64 `json:"id"`
	} `json:"user"`
}

// ingestMergeRequestEvent upserts the MR's activity-mirror row, then (Batch
// 5) binds it to the team's currently-open checkpoint via
// Service.bindMRToCheckpoint — see that function's own doc comment for the
// binding rule and why it also drives the approval-count recompute and
// review_requested/mr_merged notifications. ponytail: GitLab's MR webhook
// payload has no merged_at/closed_at timestamp field in object_attributes,
// only the current state — merged_at/closed_at are approximated with
// time.Now() (when MindForge learned about it) rather than GitLab's own
// event time; refine via a follow-up GetMergeRequest call if exact
// timestamps are needed later.
func (s *Service) ingestMergeRequestEvent(ctx context.Context, team *ProjectTeam, raw []byte) error {
	var p mrEventPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("decode merge request event: %w", err)
	}
	oa := p.ObjectAttributes

	var authorUserID *string
	if id, err := s.repo.FindUserIDByGitlabUserID(ctx, team.OrgID, p.User.ID); err == nil {
		authorUserID = id
	}

	mrID := oa.ID
	desc := oa.Description
	source := oa.SourceBranch
	target := oa.TargetBranch
	webURL := oa.URL
	authorGLID := p.User.ID

	mr := GitlabMergeRequest{
		OrgID: team.OrgID, TeamID: team.ID, MRIID: oa.IID, MRID: &mrID,
		Title: oa.Title, Description: &desc, State: oa.State,
		SourceBranch: &source, TargetBranch: &target,
		AuthorGitlabUserID: &authorGLID, AuthorUserID: authorUserID,
		WebURL:   &webURL,
		OpenedAt: parseGitlabTime(oa.CreatedAt),
	}
	now := time.Now()
	switch oa.State {
	case MRStateMerged:
		mr.MergedAt = &now
	case MRStateClosed:
		mr.ClosedAt = &now
	}

	upserted, err := s.repo.UpsertMergeRequest(ctx, mr)
	if err != nil {
		return fmt.Errorf("upsert merge request: %w", err)
	}

	if err := s.bindMRToCheckpoint(ctx, team, upserted, oa.State); err != nil {
		return fmt.Errorf("bind mr to checkpoint: %w", err)
	}

	// Phase C: one AI code-quality comment per MR, triggered off the first
	// "opened" webhook — AIReviewedAt is the cache guard (see
	// service_ai_review.go), checked again inside the job itself since a
	// redelivered webhook can enqueue before the first run has finished.
	if oa.State == MRStateOpened && upserted.AIReviewedAt == nil {
		if err := s.enqueueAIReview(ctx, team.OrgID, upserted.ID); err != nil {
			slog.ErrorContext(ctx, "gitlab: enqueue ai_review_mr failed", "team_id", team.ID, "mr_iid", oa.IID, "error", err)
		}
	}
	return nil
}

// ─── Note (MR review/approval) ──────────────────────────────────────────────

type noteEventPayload struct {
	ObjectAttributes struct {
		ID           int64  `json:"id"`
		Note         string `json:"note"`
		NoteableType string `json:"noteable_type"`
	} `json:"object_attributes"`
	MergeRequest *struct {
		IID int64 `json:"iid"`
	} `json:"merge_request"`
	User struct {
		ID int64 `json:"id"`
	} `json:"user"`
}

// ingestNoteEvent inserts a gitlab_mr_reviews row, recomputes the MR's
// approvals_count, then (Batch 5) also recomputes whichever checkpoint this
// MR is bound to (Repo.RecomputeCheckpointApprovals — a no-op if it isn't
// bound to one yet) and notifies the MR's author of a non-self comment
// ("inline-review-as-notification", kind-herding-cookie.md §4). Only notes
// attached to a merge request feed the review/approval mirror — issue/
// commit/snippet notes aren't part of this batch's peer-review tracking.
func (s *Service) ingestNoteEvent(ctx context.Context, team *ProjectTeam, raw []byte) error {
	var p noteEventPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("decode note event: %w", err)
	}
	if p.ObjectAttributes.NoteableType != "MergeRequest" || p.MergeRequest == nil {
		return nil
	}

	mr, err := s.repo.GetMergeRequestByTeamAndIID(ctx, team.ID, p.MergeRequest.IID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			// The note arrived before we'd mirrored the MR itself (e.g. the
			// hook was registered mid-review) — nothing to attach it to yet.
			return nil
		}
		return fmt.Errorf("resolve merge request for note: %w", err)
	}

	var reviewerUserID *string
	if id, err := s.repo.FindUserIDByGitlabUserID(ctx, team.OrgID, p.User.ID); err == nil {
		reviewerUserID = id
	}

	kind := ReviewKindComment
	if isApprovalNote(p.ObjectAttributes.Note) {
		kind = ReviewKindApproval
	}
	reviewerGLID := p.User.ID
	body := p.ObjectAttributes.Note

	if err := s.repo.UpsertMRReview(ctx, GitlabMRReview{
		MergeRequestID: mr.ID, ReviewerGitlabUserID: &reviewerGLID, ReviewerUserID: reviewerUserID,
		Kind: kind, NoteID: p.ObjectAttributes.ID, Body: &body,
	}); err != nil {
		return fmt.Errorf("upsert mr review: %w", err)
	}
	if err := s.repo.RecomputeMRApprovals(ctx, mr.ID); err != nil {
		return fmt.Errorf("recompute mr approvals: %w", err)
	}
	if err := s.repo.RecomputeCheckpointApprovals(ctx, mr.ID); err != nil {
		slog.ErrorContext(ctx, "gitlab: recompute checkpoint approvals failed", "mr_id", mr.ID, "error", err)
	}

	if mr.AuthorUserID != nil && reviewerUserID != nil && *reviewerUserID != *mr.AuthorUserID {
		s.notifyUser(ctx, team.OrgID, *mr.AuthorUserID, notifications.New{
			Type:        "gitlab.mr_comment",
			Title:       fmt.Sprintf("New comment on your merge request %q", mr.Title),
			Body:        &body,
			LinkURL:     mr.WebURL,
			EntityType:  strPtr("gitlab_merge_request"),
			EntityID:    &mr.ID,
			ActorUserID: reviewerUserID,
			DedupeKey:   fmt.Sprintf("gitlab.mr_comment:%d", p.ObjectAttributes.ID),
		})
	}
	return nil
}

// isApprovalNote implements kind-herding-cookie.md §0 decision #4's
// MindForge-side approval detection: a note matching the approval phrase
// counts as an approval on Free/CE alike. GitLab EE's own "approved this
// merge request" system note (generated when a reviewer clicks Approve)
// matches the same phrase, so this one check covers both tiers without
// depending on GitLab's approvals API.
func isApprovalNote(note string) bool {
	n := strings.ToLower(strings.TrimSpace(note))
	return n == "approved this merge request" || n == "approve" || n == "lgtm" || strings.HasPrefix(n, "/approve")
}

// ─── Pipeline ────────────────────────────────────────────────────────────────

type pipelineEventPayload struct {
	ObjectAttributes struct {
		ID         int64  `json:"id"`
		SHA        string `json:"sha"`
		Ref        string `json:"ref"`
		Status     string `json:"status"`
		Duration   *int   `json:"duration"`
		FinishedAt string `json:"finished_at"`
	} `json:"object_attributes"`
	// Builds is the Pipeline Hook's per-job array — used only by Batch 6's
	// maybeRefreshPagesURL to find a "pages" job precisely, without
	// depending on object_attributes (which carries no per-job detail).
	Builds []struct {
		Name   string `json:"name"`
		Stage  string `json:"stage"`
		Status string `json:"status"`
	} `json:"builds"`
}

// ingestPipelineEvent upserts the pipeline's activity-mirror row, then
// (Batch 5) mirrors its status onto project_team_checkpoints via
// Service.mirrorPipelineToCheckpoint — see that function's own doc comment
// for the join rule and the CI-failure notification it fires — and (Batch 6)
// refreshes pages_url on a Pages deployment success via maybeRefreshPagesURL.
func (s *Service) ingestPipelineEvent(ctx context.Context, team *ProjectTeam, raw []byte) error {
	var p pipelineEventPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("decode pipeline event: %w", err)
	}
	oa := p.ObjectAttributes
	sha, ref := oa.SHA, oa.Ref
	var webURL *string
	if team.GitlabWebURL != nil {
		u := fmt.Sprintf("%s/-/pipelines/%d", *team.GitlabWebURL, oa.ID)
		webURL = &u
	}

	if err := s.repo.UpsertPipeline(ctx, GitlabPipeline{
		OrgID: team.OrgID, TeamID: team.ID, PipelineID: oa.ID,
		SHA: &sha, Ref: &ref, Status: oa.Status, WebURL: webURL,
		DurationSeconds: oa.Duration,
		FinishedAt:      parseGitlabTime(oa.FinishedAt),
	}); err != nil {
		return fmt.Errorf("upsert pipeline: %w", err)
	}

	if err := s.mirrorPipelineToCheckpoint(ctx, team, oa.ID, oa.Status, webURL); err != nil {
		return fmt.Errorf("mirror pipeline to checkpoint: %w", err)
	}

	s.maybeRefreshPagesURL(ctx, team, oa.Status, p.Builds)
	return nil
}

// maybeRefreshPagesURL implements kind-herding-cookie.md §4/§5's Pages-URL
// refresh: after a pipeline succeeds, check GitLab's own Pages deployment
// endpoint and update project_teams.pages_url if it changed. Best-effort
// only — never fails webhook ingest.
//
// Signal used: the Pipeline Hook payload's builds[] array (present on
// GitLab's pipeline webhook alongside object_attributes) is checked for a
// job named "pages" — GitLab's own convention for the job that deploys
// Pages. When such a job exists and didn't itself succeed, this is not a
// Pages deployment worth refreshing for, even if the pipeline overall
// succeeded (some other job could have failed after Pages deployed, or
// Pages could still be building). When no "pages"-named job appears in the
// payload at all (some GitLab configs/versions omit builds[], or the
// project simply has no Pages job), this falls back to "any pipeline
// success" and asks GitLab directly via GetPages — better to make one extra,
// cheap API call on every green pipeline than to silently never pick up a
// Pages deployment MindForge has no more precise signal for.
func (s *Service) maybeRefreshPagesURL(ctx context.Context, team *ProjectTeam, pipelineStatus string, builds []struct {
	Name   string `json:"name"`
	Stage  string `json:"stage"`
	Status string `json:"status"`
}) {
	if pipelineStatus != CIStatusSuccess || team.GitlabProjectID == nil {
		return
	}

	sawPagesJob, pagesJobSucceeded := false, false
	for _, b := range builds {
		if strings.EqualFold(b.Name, "pages") {
			sawPagesJob = true
			if b.Status == CIStatusSuccess {
				pagesJobSucceeded = true
			}
		}
	}
	if sawPagesJob && !pagesJobSucceeded {
		return
	}

	client, err := s.clientForTeam(ctx, team.OrgID, team.AssignmentID)
	if err != nil {
		slog.WarnContext(ctx, "gitlab: refresh pages url: resolve client failed", "team_id", team.ID, "error", err)
		return
	}
	pages, err := client.GetPages(ctx, *team.GitlabProjectID)
	if err != nil {
		var apiErr *APIError
		if errors.As(err, &apiErr) && apiErr.StatusCode == http.StatusNotFound {
			return // Pages not deployed for this project (yet) — expected, not an error
		}
		slog.WarnContext(ctx, "gitlab: refresh pages url: get pages failed", "team_id", team.ID, "error", err)
		return
	}
	if pages.URL == "" || (team.PagesURL != nil && *team.PagesURL == pages.URL) {
		return
	}
	if err := s.repo.UpdateTeamPagesURL(ctx, team.ID, pages.URL); err != nil {
		slog.ErrorContext(ctx, "gitlab: refresh pages url: persist failed", "team_id", team.ID, "error", err)
	}
}

// ─── Issue ───────────────────────────────────────────────────────────────────

type issueEventPayload struct {
	ObjectAttributes struct {
		IID         int64   `json:"iid"`
		ID          int64   `json:"id"`
		Title       string  `json:"title"`
		State       string  `json:"state"`
		MilestoneID *int64  `json:"milestone_id"`
		Weight      *int    `json:"weight"`
		CreatedAt   string  `json:"created_at"`
		ClosedAt    *string `json:"closed_at"`
	} `json:"object_attributes"`
	Assignees []struct {
		ID int64 `json:"id"`
	} `json:"assignees"`
	Labels []struct {
		Title string `json:"title"`
	} `json:"labels"`
}

// ingestIssueEvent upserts the issue's activity-mirror row, resolving
// milestone_id to a project_checkpoints row first (kind-herding-cookie.md
// §4) via Repo.FindCheckpointByMilestone, scoped to the team's own
// assignment. Nil MilestoneID, or no checkpoint whose gitlab_milestone_id
// matches yet, both correctly leave checkpoint_id unset — see
// GitlabIssue.CheckpointID's own doc comment for why that's the expected
// state, not a bug, for most checkpoints today.
func (s *Service) ingestIssueEvent(ctx context.Context, team *ProjectTeam, raw []byte) error {
	var p issueEventPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return fmt.Errorf("decode issue event: %w", err)
	}
	oa := p.ObjectAttributes

	issueID := oa.ID
	var assigneeGLID *int64
	if len(p.Assignees) > 0 {
		id := p.Assignees[0].ID
		assigneeGLID = &id
	}
	var assigneeUserID *string
	if assigneeGLID != nil {
		if id, err := s.repo.FindUserIDByGitlabUserID(ctx, team.OrgID, *assigneeGLID); err == nil {
			assigneeUserID = id
		}
	}
	labels := make([]string, 0, len(p.Labels))
	for _, l := range p.Labels {
		labels = append(labels, l.Title)
	}

	var checkpointID *string
	if oa.MilestoneID != nil {
		if cp, err := s.repo.FindCheckpointByMilestone(ctx, team.AssignmentID, *oa.MilestoneID); err == nil {
			checkpointID = &cp.ID
		} else if !errors.Is(err, ErrNotFound) {
			slog.ErrorContext(ctx, "gitlab: resolve checkpoint by milestone failed", "team_id", team.ID, "milestone_id", *oa.MilestoneID, "error", err)
		}
	}

	issue := GitlabIssue{
		OrgID: team.OrgID, TeamID: team.ID, IssueIID: oa.IID, IssueID: &issueID,
		Title: oa.Title, State: oa.State, MilestoneID: oa.MilestoneID, CheckpointID: checkpointID,
		AssigneeGitlabUserID: assigneeGLID, AssigneeUserID: assigneeUserID,
		Weight: oa.Weight, Labels: labels,
		GLCreatedAt: parseGitlabTime(oa.CreatedAt),
	}
	if oa.ClosedAt != nil {
		issue.GLClosedAt = parseGitlabTime(*oa.ClosedAt)
	}
	if err := s.repo.UpsertIssue(ctx, issue); err != nil {
		return fmt.Errorf("upsert issue: %w", err)
	}
	return nil
}

// ─── shared helpers ──────────────────────────────────────────────────────────

// parseGitlabTime tries every timestamp layout GitLab's webhook payloads and
// REST API have used (ISO8601 in the API, "2006-01-02 15:04:05 MST" in older
// webhook payloads), returning nil rather than an error for an empty or
// unrecognized string — a missing timestamp on a mirrored row is far less
// harmful than failing the whole ingest over a formatting quirk.
func parseGitlabTime(s string) *time.Time {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	layouts := []string{
		time.RFC3339,
		"2006-01-02T15:04:05.000Z",
		"2006-01-02 15:04:05 MST",
		"2006-01-02 15:04:05 -0700",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return &t
		}
	}
	return nil
}

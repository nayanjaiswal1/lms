package gitlab

import (
	"context"
	"fmt"
	"log/slog"
	"time"
)

// pollStaleThreshold is how long a provisioned team can go without a
// received webhook event before poll_sync treats its hook as possibly
// broken and re-lists activity directly from the API. Set above the cron's
// own 10-minute cadence (kind-herding-cookie.md §3) so a healthy team with a
// working hook isn't re-polled on every tick.
const pollStaleThreshold = 20 * time.Minute

// PollSync is the gitlab.poll_sync cron job body — a self-healing pull for
// installations running webhook_mode='poll' (no webhook reachable at all,
// e.g. the GitLab instance can't reach this app) or any provisioned team
// that hasn't received a webhook event recently despite being ready (a
// silently broken hook). It re-lists commits/merge requests/pipelines/issues
// straight from the GitLab API and upserts them through the exact same repo
// methods the webhook path uses, so a team never sees different data
// depending on which path happens to be working.
func (s *Service) PollSync(ctx context.Context) error {
	teams, err := s.repo.ListTeamsNeedingPoll(ctx, pollStaleThreshold)
	if err != nil {
		return fmt.Errorf("gitlab: poll sync: list teams: %w", err)
	}
	for _, team := range teams {
		if err := s.pollSyncTeam(ctx, team); err != nil {
			slog.ErrorContext(ctx, "gitlab: poll sync team failed", "team_id", team.ID, "error", err)
		}
	}
	return nil
}

func (s *Service) pollSyncTeam(ctx context.Context, team ProjectTeam) error {
	if team.GitlabProjectID == nil {
		return nil
	}
	client, err := s.clientForTeam(ctx, team.OrgID, team.AssignmentID)
	if err != nil {
		return fmt.Errorf("resolve client: %w", err)
	}
	projectID := *team.GitlabProjectID

	commits, err := client.ListCommits(ctx, projectID, "", "")
	if err != nil {
		return fmt.Errorf("list commits: %w", err)
	}
	for _, c := range commits {
		name, email, msg := c.AuthorName, c.AuthorEmail, c.Title
		if msg == "" {
			msg = c.Message
		}
		if err := s.repo.UpsertCommit(ctx, GitlabCommit{
			OrgID: team.OrgID, TeamID: team.ID, SHA: c.ID,
			AuthorEmail: &email, AuthorName: &name, Message: &msg,
			CommittedAt: parseGitlabTime(c.AuthoredDate),
		}); err != nil {
			slog.ErrorContext(ctx, "gitlab: poll sync upsert commit failed", "team_id", team.ID, "sha", c.ID, "error", err)
		}
	}

	mrs, err := client.ListMergeRequests(ctx, projectID, "all")
	if err != nil {
		return fmt.Errorf("list merge requests: %w", err)
	}
	for _, mr := range mrs {
		if err := s.pollUpsertMergeRequest(ctx, &team, mr); err != nil {
			slog.ErrorContext(ctx, "gitlab: poll sync upsert mr failed", "team_id", team.ID, "mr_iid", mr.IID, "error", err)
		}
	}

	pipelines, err := client.ListPipelines(ctx, projectID)
	if err != nil {
		return fmt.Errorf("list pipelines: %w", err)
	}
	for _, p := range pipelines {
		if err := s.repo.UpsertPipeline(ctx, GitlabPipeline{
			OrgID: team.OrgID, TeamID: team.ID, PipelineID: p.ID,
			SHA: &p.SHA, Ref: &p.Ref, Status: p.Status, WebURL: &p.WebURL,
			DurationSeconds: p.Duration, StartedAt: p.StartedAt, FinishedAt: p.FinishedAt,
		}); err != nil {
			slog.ErrorContext(ctx, "gitlab: poll sync upsert pipeline failed", "team_id", team.ID, "pipeline_id", p.ID, "error", err)
		}
	}

	issues, err := client.ListIssues(ctx, projectID, "all")
	if err != nil {
		return fmt.Errorf("list issues: %w", err)
	}
	for _, iss := range issues {
		if err := s.pollUpsertIssue(ctx, &team, iss); err != nil {
			slog.ErrorContext(ctx, "gitlab: poll sync upsert issue failed", "team_id", team.ID, "issue_iid", iss.IID, "error", err)
		}
	}

	return nil
}

func (s *Service) pollUpsertMergeRequest(ctx context.Context, team *ProjectTeam, mr MergeRequest) error {
	var authorUserID *string
	if id, err := s.repo.FindUserIDByGitlabUserID(ctx, team.OrgID, mr.Author.ID); err == nil {
		authorUserID = id
	}
	mrID, desc, source, target, webURL, authorGLID := mr.ID, mr.Description, mr.SourceBranch, mr.TargetBranch, mr.WebURL, mr.Author.ID
	openedAt := mr.CreatedAt
	_, err := s.repo.UpsertMergeRequest(ctx, GitlabMergeRequest{
		OrgID: team.OrgID, TeamID: team.ID, MRIID: mr.IID, MRID: &mrID,
		Title: mr.Title, Description: &desc, State: mr.State,
		SourceBranch: &source, TargetBranch: &target,
		AuthorGitlabUserID: &authorGLID, AuthorUserID: authorUserID,
		WebURL: &webURL, OpenedAt: &openedAt, MergedAt: mr.MergedAt, ClosedAt: mr.ClosedAt,
	})
	return err
}

func (s *Service) pollUpsertIssue(ctx context.Context, team *ProjectTeam, iss Issue) error {
	issueID := iss.ID
	var milestoneID *int64
	if iss.Milestone != nil {
		milestoneID = &iss.Milestone.ID
	}
	var assigneeGLID *int64
	var assigneeUserID *string
	if iss.Assignee != nil {
		assigneeGLID = &iss.Assignee.ID
		if id, err := s.repo.FindUserIDByGitlabUserID(ctx, team.OrgID, iss.Assignee.ID); err == nil {
			assigneeUserID = id
		}
	}
	createdAt := iss.CreatedAt
	return s.repo.UpsertIssue(ctx, GitlabIssue{
		OrgID: team.OrgID, TeamID: team.ID, IssueIID: iss.IID, IssueID: &issueID,
		Title: iss.Title, State: iss.State, MilestoneID: milestoneID,
		AssigneeGitlabUserID: assigneeGLID, AssigneeUserID: assigneeUserID,
		Weight: iss.Weight, Labels: iss.Labels,
		GLCreatedAt: &createdAt, GLClosedAt: iss.ClosedAt,
	})
}

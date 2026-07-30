package gitlab

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// ─── gitlab_commits ─────────────────────────────────────────────────────────

// UpsertCommit inserts (or refreshes) a mirrored commit, keyed
// UNIQUE(team_id, sha) — a redelivered push event for the same sha upserts
// rather than duplicates. additions/deletions/files_changed are left NULL on
// first insert (the push payload never carries them); the commit_stats job
// fills them in via a follow-up per-sha GetCommit call, and this upsert
// deliberately does not clobber already-fetched stats on a later redelivery
// (COALESCE keeps the existing non-null value).
func (r *Repo) UpsertCommit(ctx context.Context, c GitlabCommit) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO gitlab_commits
			(org_id, team_id, sha, branch, author_gitlab_user_id, user_id,
			 author_email, author_name, message, is_merge, committed_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		 ON CONFLICT (team_id, sha) DO UPDATE SET
			branch = EXCLUDED.branch,
			author_gitlab_user_id = EXCLUDED.author_gitlab_user_id,
			user_id = COALESCE(EXCLUDED.user_id, gitlab_commits.user_id),
			author_email = EXCLUDED.author_email,
			author_name = EXCLUDED.author_name,
			message = EXCLUDED.message,
			committed_at = COALESCE(EXCLUDED.committed_at, gitlab_commits.committed_at)`,
		c.OrgID, c.TeamID, c.SHA, c.Branch, c.AuthorGitlabUserID, c.UserID,
		c.AuthorEmail, c.AuthorName, c.Message, c.IsMerge, c.CommittedAt,
	)
	if err != nil {
		return fmt.Errorf("gitlab: upsert commit: %w", err)
	}
	return nil
}

// ListCommitsPendingStats returns up to limit commits whose diff stats
// haven't been fetched yet (additions IS NULL — see migration 023's own
// partial index for this exact predicate), oldest first, for the
// commit_stats job's batched 50/job sweep.
func (r *Repo) ListCommitsPendingStats(ctx context.Context, limit int) ([]GitlabCommit, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, org_id, team_id, sha FROM gitlab_commits
		 WHERE additions IS NULL
		 ORDER BY recorded_at
		 LIMIT $1`,
		limit,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list commits pending stats: %w", err)
	}
	defer rows.Close()

	out := []GitlabCommit{}
	for rows.Next() {
		var c GitlabCommit
		if err := rows.Scan(&c.ID, &c.OrgID, &c.TeamID, &c.SHA); err != nil {
			return nil, fmt.Errorf("gitlab: scan commit pending stats: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// UpdateCommitStats records a fetched commit's diff stats. files_changed is
// left NULL — ponytail: GitLab's stats=true commit response only returns
// additions/deletions/total, not a changed-file count; getting that needs a
// second per-commit diff call. Add it if a later batch's dashboards need it.
func (r *Repo) UpdateCommitStats(ctx context.Context, id string, additions, deletions int) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_commits SET additions = $2, deletions = $3 WHERE id = $1`,
		id, additions, deletions,
	)
	if err != nil {
		return fmt.Errorf("gitlab: update commit stats: %w", err)
	}
	return nil
}

// FlagLateCommits marks every checkpoint of teamID whose deadline snapshot
// has already been taken (snapshot_at IS NOT NULL) as late when committedAt
// falls after that snapshot, incrementing late_commit_count once per call.
// In Batch 3 this runs against a table with no real rows yet — checkpoint
// CRUD lands in Batch 5 — so it is a correctly-wired no-op until then, not a
// stub: the query is right, there's simply nothing to match against yet.
func (r *Repo) FlagLateCommits(ctx context.Context, teamID string, committedAt time.Time) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_team_checkpoints
		 SET is_late = true, late_commit_count = late_commit_count + 1, updated_at = now()
		 WHERE team_id = $1 AND snapshot_at IS NOT NULL AND $2 > snapshot_at`,
		teamID, committedAt,
	)
	if err != nil {
		return fmt.Errorf("gitlab: flag late commits: %w", err)
	}
	return nil
}

// ─── gitlab_merge_requests ──────────────────────────────────────────────────

const mergeRequestColumns = `
	id, org_id, team_id, mr_iid, mr_id, title, description, state, source_branch,
	target_branch, author_gitlab_user_id, author_user_id, web_url, approvals_count,
	changes_count, opened_at, merged_at, closed_at, updated_at`

func scanMergeRequest(row pgx.Row) (*GitlabMergeRequest, error) {
	var mr GitlabMergeRequest
	err := row.Scan(
		&mr.ID, &mr.OrgID, &mr.TeamID, &mr.MRIID, &mr.MRID, &mr.Title, &mr.Description, &mr.State, &mr.SourceBranch,
		&mr.TargetBranch, &mr.AuthorGitlabUserID, &mr.AuthorUserID, &mr.WebURL, &mr.ApprovalsCount,
		&mr.ChangesCount, &mr.OpenedAt, &mr.MergedAt, &mr.ClosedAt, &mr.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan merge request: %w", err)
	}
	return &mr, nil
}

// UpsertMergeRequest inserts (or refreshes) a mirrored MR, keyed
// UNIQUE(team_id, mr_iid). approvals_count is deliberately never written
// here — it's owned by RecomputeMRApprovals, driven off gitlab_mr_reviews,
// so a plain MR-hook redelivery can't stomp on it.
func (r *Repo) UpsertMergeRequest(ctx context.Context, mr GitlabMergeRequest) (*GitlabMergeRequest, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO gitlab_merge_requests
			(org_id, team_id, mr_iid, mr_id, title, description, state, source_branch,
			 target_branch, author_gitlab_user_id, author_user_id, web_url,
			 opened_at, merged_at, closed_at, updated_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,now())
		 ON CONFLICT (team_id, mr_iid) DO UPDATE SET
			mr_id = EXCLUDED.mr_id,
			title = EXCLUDED.title,
			description = EXCLUDED.description,
			state = EXCLUDED.state,
			source_branch = EXCLUDED.source_branch,
			target_branch = EXCLUDED.target_branch,
			author_gitlab_user_id = EXCLUDED.author_gitlab_user_id,
			author_user_id = COALESCE(EXCLUDED.author_user_id, gitlab_merge_requests.author_user_id),
			web_url = EXCLUDED.web_url,
			opened_at = COALESCE(gitlab_merge_requests.opened_at, EXCLUDED.opened_at),
			merged_at = COALESCE(EXCLUDED.merged_at, gitlab_merge_requests.merged_at),
			closed_at = COALESCE(EXCLUDED.closed_at, gitlab_merge_requests.closed_at),
			updated_at = now()
		 RETURNING `+mergeRequestColumns,
		mr.OrgID, mr.TeamID, mr.MRIID, mr.MRID, mr.Title, mr.Description, mr.State, mr.SourceBranch,
		mr.TargetBranch, mr.AuthorGitlabUserID, mr.AuthorUserID, mr.WebURL,
		mr.OpenedAt, mr.MergedAt, mr.ClosedAt,
	)
	return scanMergeRequest(row)
}

// GetMergeRequestByTeamAndIID resolves the mirrored MR row a Note Hook's
// merge_request.iid refers to.
func (r *Repo) GetMergeRequestByTeamAndIID(ctx context.Context, teamID string, mrIID int64) (*GitlabMergeRequest, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+mergeRequestColumns+` FROM gitlab_merge_requests WHERE team_id = $1 AND mr_iid = $2`, teamID, mrIID)
	return scanMergeRequest(row)
}

// ─── gitlab_mr_reviews ──────────────────────────────────────────────────────

// UpsertMRReview inserts (or refreshes) a mirrored MR note, keyed
// UNIQUE(merge_request_id, note_id) — a redelivered Note Hook for the same
// note_id upserts rather than duplicates.
func (r *Repo) UpsertMRReview(ctx context.Context, rev GitlabMRReview) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO gitlab_mr_reviews
			(merge_request_id, reviewer_gitlab_user_id, reviewer_user_id, kind, note_id, body, file_path)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)
		 ON CONFLICT (merge_request_id, note_id) DO UPDATE SET
			reviewer_gitlab_user_id = EXCLUDED.reviewer_gitlab_user_id,
			reviewer_user_id = COALESCE(EXCLUDED.reviewer_user_id, gitlab_mr_reviews.reviewer_user_id),
			kind = EXCLUDED.kind,
			body = EXCLUDED.body,
			file_path = EXCLUDED.file_path`,
		rev.MergeRequestID, rev.ReviewerGitlabUserID, rev.ReviewerUserID, rev.Kind, rev.NoteID, rev.Body, rev.FilePath,
	)
	if err != nil {
		return fmt.Errorf("gitlab: upsert mr review: %w", err)
	}
	return nil
}

// RecomputeMRApprovals recounts gitlab_merge_requests.approvals_count from
// distinct approving reviewers on gitlab_mr_reviews — called after every
// Note Hook that might have added or changed an approval note.
func (r *Repo) RecomputeMRApprovals(ctx context.Context, mrID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_merge_requests
		 SET approvals_count = (
		   SELECT COUNT(DISTINCT reviewer_gitlab_user_id)
		   FROM gitlab_mr_reviews
		   WHERE merge_request_id = $1 AND kind = 'approval' AND reviewer_gitlab_user_id IS NOT NULL
		 ), updated_at = now()
		 WHERE id = $1`,
		mrID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: recompute mr approvals: %w", err)
	}
	return nil
}

// ─── gitlab_pipelines ───────────────────────────────────────────────────────

// UpsertPipeline inserts (or refreshes) a mirrored pipeline, keyed
// UNIQUE(team_id, pipeline_id). Mirroring ci_status onto
// project_team_checkpoints is Batch 5's concern (see service_webhook.go's
// ingestPipelineEvent) — not done here.
func (r *Repo) UpsertPipeline(ctx context.Context, p GitlabPipeline) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO gitlab_pipelines
			(org_id, team_id, pipeline_id, sha, ref, status, web_url, duration_seconds, started_at, finished_at, updated_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,now())
		 ON CONFLICT (team_id, pipeline_id) DO UPDATE SET
			sha = EXCLUDED.sha,
			ref = EXCLUDED.ref,
			status = EXCLUDED.status,
			web_url = EXCLUDED.web_url,
			duration_seconds = COALESCE(EXCLUDED.duration_seconds, gitlab_pipelines.duration_seconds),
			started_at = COALESCE(gitlab_pipelines.started_at, EXCLUDED.started_at),
			finished_at = COALESCE(EXCLUDED.finished_at, gitlab_pipelines.finished_at),
			updated_at = now()`,
		p.OrgID, p.TeamID, p.PipelineID, p.SHA, p.Ref, p.Status, p.WebURL, p.DurationSeconds, p.StartedAt, p.FinishedAt,
	)
	if err != nil {
		return fmt.Errorf("gitlab: upsert pipeline: %w", err)
	}
	return nil
}

// ─── gitlab_issues ──────────────────────────────────────────────────────────

// UpsertIssue inserts (or refreshes) a mirrored issue, keyed
// UNIQUE(team_id, issue_iid). checkpoint_id is resolved by the caller
// (service_webhook.go's ingestIssueEvent, via Repo.FindCheckpointByMilestone)
// and written here with COALESCE — a later re-ingest of the same issue with
// no resolvable checkpoint this time (e.g. the milestone lookup found
// nothing, or the issue no longer carries a milestone) never clobbers an
// already-resolved checkpoint_id back to NULL.
func (r *Repo) UpsertIssue(ctx context.Context, iss GitlabIssue) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO gitlab_issues
			(org_id, team_id, issue_iid, issue_id, title, state, milestone_id, checkpoint_id,
			 assignee_gitlab_user_id, assignee_user_id, weight, labels, gl_created_at, gl_closed_at, updated_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,now())
		 ON CONFLICT (team_id, issue_iid) DO UPDATE SET
			issue_id = EXCLUDED.issue_id,
			title = EXCLUDED.title,
			state = EXCLUDED.state,
			milestone_id = EXCLUDED.milestone_id,
			checkpoint_id = COALESCE(EXCLUDED.checkpoint_id, gitlab_issues.checkpoint_id),
			assignee_gitlab_user_id = EXCLUDED.assignee_gitlab_user_id,
			assignee_user_id = COALESCE(EXCLUDED.assignee_user_id, gitlab_issues.assignee_user_id),
			weight = EXCLUDED.weight,
			labels = EXCLUDED.labels,
			gl_closed_at = COALESCE(EXCLUDED.gl_closed_at, gitlab_issues.gl_closed_at),
			updated_at = now()`,
		iss.OrgID, iss.TeamID, iss.IssueIID, iss.IssueID, iss.Title, iss.State, iss.MilestoneID, iss.CheckpointID,
		iss.AssigneeGitlabUserID, iss.AssigneeUserID, iss.Weight, iss.Labels, iss.GLCreatedAt, iss.GLClosedAt,
	)
	if err != nil {
		return fmt.Errorf("gitlab: upsert issue: %w", err)
	}
	return nil
}

// ─── gitlab_webhook_events ──────────────────────────────────────────────────

const webhookEventColumns = `
	id, org_id, project_id, event_type, event_uuid, payload, status, error, received_at, processed_at`

func scanWebhookEvent(row pgx.Row) (*GitlabWebhookEvent, error) {
	var e GitlabWebhookEvent
	err := row.Scan(&e.ID, &e.OrgID, &e.ProjectID, &e.EventType, &e.EventUUID, &e.Payload, &e.Status, &e.Error, &e.ReceivedAt, &e.ProcessedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan webhook event: %w", err)
	}
	return &e, nil
}

// InsertWebhookEvent dedupe-inserts a raw webhook delivery keyed on
// (org_id, event_uuid) — GitLab redelivers on timeout/5xx, so a repeated
// event_uuid must never double-process. ON CONFLICT DO NOTHING (unlike every
// other activity-mirror upsert above) since the first delivery's row is
// authoritative; a conflict means "already recorded," not "refresh this
// row." id is generated by the caller (not gen_random_uuid() server-side) so
// it's known whether or not the insert actually happened — RowsAffected()
// tells the caller whether this was a fresh insert (and therefore whether to
// enqueue gitlab.ingest_event) rather than just "the INSERT didn't error."
func (r *Repo) InsertWebhookEvent(ctx context.Context, id, orgID string, projectID int64, eventType, eventUUID string, payload []byte) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO gitlab_webhook_events (id, org_id, project_id, event_type, event_uuid, payload)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (org_id, event_uuid) DO NOTHING`,
		id, orgID, projectID, eventType, eventUUID, payload,
	)
	if err != nil {
		return false, fmt.Errorf("gitlab: insert webhook event: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// GetWebhookEvent loads one webhook event row for the ingest_event job.
func (r *Repo) GetWebhookEvent(ctx context.Context, id string) (*GitlabWebhookEvent, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+webhookEventColumns+` FROM gitlab_webhook_events WHERE id = $1`, id)
	return scanWebhookEvent(row)
}

// MarkWebhookEventStatus records the ingest_event job's outcome for one
// webhook event row.
func (r *Repo) MarkWebhookEventStatus(ctx context.Context, id, status string, errMsg *string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE gitlab_webhook_events SET status = $2, error = $3, processed_at = now() WHERE id = $1`,
		id, status, errMsg,
	)
	if err != nil {
		return fmt.Errorf("gitlab: mark webhook event status: %w", err)
	}
	return nil
}

// ─── cross-domain: gitlab_connections lookup by GitLab identity ───────────

// ─── team activity feed (read-only projection, see models.go) ─────────────

// ListRecentCommits returns a team's most recently committed commits, newest
// first, for GET .../activity. A plain indexed read (idx_gitlab_commits_team_
// committed) — no aggregation.
func (r *Repo) ListRecentCommits(ctx context.Context, teamID string, limit int) ([]TeamActivityCommit, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT sha, message, author_name, committed_at
		 FROM gitlab_commits
		 WHERE team_id = $1
		 ORDER BY committed_at DESC NULLS LAST, recorded_at DESC
		 LIMIT $2`,
		teamID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list recent commits: %w", err)
	}
	defer rows.Close()

	out := []TeamActivityCommit{}
	for rows.Next() {
		var c TeamActivityCommit
		if err := rows.Scan(&c.SHA, &c.Message, &c.AuthorName, &c.CommittedAt); err != nil {
			return nil, fmt.Errorf("gitlab: scan recent commit: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// ListRecentMergeRequests returns a team's most recently updated merge
// requests (any state), newest first, for GET .../activity.
func (r *Repo) ListRecentMergeRequests(ctx context.Context, teamID string, limit int) ([]TeamActivityMergeRequest, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT title, state, web_url, approvals_count
		 FROM gitlab_merge_requests
		 WHERE team_id = $1
		 ORDER BY updated_at DESC
		 LIMIT $2`,
		teamID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list recent merge requests: %w", err)
	}
	defer rows.Close()

	out := []TeamActivityMergeRequest{}
	for rows.Next() {
		var mr TeamActivityMergeRequest
		if err := rows.Scan(&mr.Title, &mr.State, &mr.WebURL, &mr.ApprovalsCount); err != nil {
			return nil, fmt.Errorf("gitlab: scan recent merge request: %w", err)
		}
		out = append(out, mr)
	}
	return out, rows.Err()
}

// GetLatestPipeline returns a team's most recently updated pipeline, or nil
// (not an error) if the team has none yet — an empty activity feed is a
// valid state for a freshly provisioned team.
func (r *Repo) GetLatestPipeline(ctx context.Context, teamID string) (*TeamActivityPipeline, error) {
	var p TeamActivityPipeline
	err := r.pool.QueryRow(ctx,
		`SELECT status, web_url FROM gitlab_pipelines WHERE team_id = $1 ORDER BY updated_at DESC LIMIT 1`,
		teamID,
	).Scan(&p.Status, &p.WebURL)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("gitlab: get latest pipeline: %w", err)
	}
	return &p, nil
}

// FindUserIDByGitlabUserID resolves a GitLab numeric user ID (as seen in a
// webhook payload's author/user/assignee field) to the MindForge user_id who
// owns that connection, or ErrNotFound if no member has connected that
// identity. Used to attribute mirrored commits/MRs/issues to a real
// MindForge user rather than leaving them anonymous.
func (r *Repo) FindUserIDByGitlabUserID(ctx context.Context, orgID string, gitlabUserID int64) (*string, error) {
	var userID string
	err := r.pool.QueryRow(ctx,
		`SELECT user_id FROM gitlab_connections WHERE org_id = $1 AND gitlab_user_id = $2`,
		orgID, gitlabUserID,
	).Scan(&userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: find user by gitlab user id: %w", err)
	}
	return &userID, nil
}

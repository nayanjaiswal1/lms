package workspace

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// repo_gitlab.go — Phase 4 (contract-phase4.md 4a) data layer: resolving a
// gitlab team_id back to its workspace project, the work_item_gitlab link
// table, and the read-only joins against gitlab's own gitlab_merge_requests
// mirror this package needs for the pipeline/size badges and the
// merged-and-green automation check. Raw SQL against gitlab's tables rather
// than an import of that package's Repo — workspace already imports the
// gitlab package itself (for GitlabRefInfo/Service), but its Repo/DBTX layer
// is private, and this is the only gitlab-owned state workspace's own
// dashboard/automation reads (same "plain scoped SELECT" convention
// wiki/orgs already use for cross-package reads of workspace's own tables).

// GetProjectByTeamID resolves the workspace project a gitlab team_id
// belongs to — LinkGitlabRef's first resolve step. ErrNotFound means no
// workspace project (in this org) has ever been provisioned with this team.
func (r *Repo) GetProjectByTeamID(ctx context.Context, db DBTX, orgID, teamID string) (*Project, error) {
	return scanProject(db.QueryRow(ctx,
		`SELECT `+projectColumns+` FROM workspace_projects WHERE org_id = $1 AND team_id = $2`,
		orgID, teamID))
}

// SetProjectTeamID is the one-time write GitLab provisioning (D8) makes once
// the team is created — a dedicated method (not UpdateProject's general
// patch) since team_id is otherwise immutable after provisioning.
func (r *Repo) SetProjectTeamID(ctx context.Context, db DBTX, projectID, teamID string) error {
	tag, err := db.Exec(ctx, `UPDATE workspace_projects SET team_id = $2, updated_at = now() WHERE id = $1 AND team_id IS NULL`, projectID, teamID)
	if err != nil {
		return fmt.Errorf("workspace: set project team id: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrConflict
	}
	return nil
}

// UpsertWorkItemGitlab links one gitlab ref to an item, keyed
// UNIQUE(item_id, kind, gitlab_ref) — redelivery-safe (a re-sent webhook just
// refreshes updated_at/merge_request_id/state).
func (r *Repo) UpsertWorkItemGitlab(ctx context.Context, db DBTX, projectID, itemID, kind, ref string, mergeRequestID *string) error {
	if _, err := db.Exec(ctx,
		`INSERT INTO work_item_gitlab (project_id, item_id, kind, gitlab_ref, merge_request_id)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (item_id, kind, gitlab_ref) DO UPDATE SET
		   merge_request_id = COALESCE(EXCLUDED.merge_request_id, work_item_gitlab.merge_request_id),
		   updated_at = now()`,
		projectID, itemID, kind, ref, mergeRequestID,
	); err != nil {
		return fmt.Errorf("workspace: upsert work item gitlab link: %w", err)
	}
	return nil
}

// SetGitlabLinkSyncStatus records the outcome of a reviewer-sync attempt
// against one MR link (contract-phase4.md 4a step 5).
func (r *Repo) SetGitlabLinkSyncStatus(ctx context.Context, db DBTX, itemID, kind, ref, status string) error {
	if _, err := db.Exec(ctx,
		`UPDATE work_item_gitlab SET sync_status = $4, updated_at = now() WHERE item_id = $1 AND kind = $2 AND gitlab_ref = $3`,
		itemID, kind, ref, status,
	); err != nil {
		return fmt.Errorf("workspace: set gitlab link sync status: %w", err)
	}
	return nil
}

// GitlabAutomationReadiness reports whether every MR linked to itemID is
// merged, and the most-recently-updated one's mirrored pipeline finished
// green — the merged-and-green precondition for the in_review->testing
// automation step (contract-phase4.md 4a step 4).
func (r *Repo) GitlabAutomationReadiness(ctx context.Context, db DBTX, itemID string) (allMerged, latestPipelineGreen bool, err error) {
	var linkCount int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_item_gitlab wig JOIN gitlab_merge_requests mr ON mr.id = wig.merge_request_id
		  WHERE wig.item_id = $1 AND wig.kind = 'mr'`,
		itemID,
	).Scan(&linkCount); err != nil {
		return false, false, fmt.Errorf("workspace: gitlab automation readiness: count: %w", err)
	}
	if linkCount == 0 {
		return false, false, nil
	}
	var unmerged int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_item_gitlab wig JOIN gitlab_merge_requests mr ON mr.id = wig.merge_request_id
		  WHERE wig.item_id = $1 AND wig.kind = 'mr' AND mr.state <> 'merged'`,
		itemID,
	).Scan(&unmerged); err != nil {
		return false, false, fmt.Errorf("workspace: gitlab automation readiness: unmerged: %w", err)
	}
	var latestStatus *string
	if err := db.QueryRow(ctx,
		`SELECT mr.head_pipeline_status FROM work_item_gitlab wig JOIN gitlab_merge_requests mr ON mr.id = wig.merge_request_id
		  WHERE wig.item_id = $1 AND wig.kind = 'mr' ORDER BY mr.updated_at DESC LIMIT 1`,
		itemID,
	).Scan(&latestStatus); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return false, false, fmt.Errorf("workspace: gitlab automation readiness: latest pipeline: %w", err)
	}
	allMerged = unmerged == 0
	latestPipelineGreen = latestStatus != nil && *latestStatus == "success"
	return allMerged, latestPipelineGreen, nil
}

// ListItemGitlabLinks is GET .../items/{itemID}/gitlab — every ref linked to
// an item, joined to its MR mirror for state/pipeline/size when it's an MR.
func (r *Repo) ListItemGitlabLinks(ctx context.Context, db DBTX, itemID string) ([]GitlabLink, error) {
	rows, err := db.Query(ctx,
		`SELECT wig.id, wig.kind, wig.gitlab_ref, wig.sync_status,
		        mr.title, mr.state, mr.web_url, mr.head_pipeline_status, mr.additions, mr.deletions,
		        wig.first_seen_at, wig.updated_at, mr.merged_at
		   FROM work_item_gitlab wig LEFT JOIN gitlab_merge_requests mr ON mr.id = wig.merge_request_id
		  WHERE wig.item_id = $1
		  ORDER BY wig.updated_at DESC`,
		itemID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list item gitlab links: %w", err)
	}
	defer rows.Close()
	out := []GitlabLink{}
	for rows.Next() {
		var l GitlabLink
		if err := rows.Scan(&l.ID, &l.Kind, &l.Ref, &l.SyncStatus, &l.MRTitle, &l.MRState, &l.MRWebURL,
			&l.PipelineStatus, &l.Additions, &l.Deletions, &l.FirstSeenAt, &l.UpdatedAt, &l.MergedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan item gitlab link: %w", err)
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

// ListReviewerGitlabTargets returns (userID) for every current reviewer
// assignee of itemID — LinkGitlabRef's own reviewer-sync step resolves each
// one's GitLab identity separately via gitlab.Service.ResolveGitlabUserID.
func (r *Repo) ListReviewerUserIDs(ctx context.Context, db DBTX, itemID string) ([]string, error) {
	rows, err := db.Query(ctx, `SELECT user_id FROM work_item_assignees WHERE item_id = $1 AND role = 'reviewer'`, itemID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list reviewer user ids: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

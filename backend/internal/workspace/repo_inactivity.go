package workspace

import (
	"context"
	"fmt"
	"time"
)

// repo_inactivity.go — the workspace.inactivity_sweep daily job's read
// (contract-phase4.md 4c). last_active is the most recent of: a work item
// event actored by them, a time log, a standup update, or (best-effort,
// cross-package raw read — see repo_gitlab.go's own doc comment for why this
// package reads gitlab's tables directly) a GitLab commit on the project's
// team, floored at their own joined_at so a just-added member is never
// flagged before they've had a chance to do anything.

type inactiveMember struct {
	ProjectID  string
	OrgID      string
	UserID     string
	LastActive time.Time
}

// ListActiveMembersLastActivity returns every active member of every active
// project, with their computed last-activity time — the sweep's own code
// buckets these into the 7d/14d stages (service_reminders.go's
// RunInactivitySweep) rather than filtering in SQL, so one query serves both
// thresholds.
func (r *Repo) ListActiveMembersLastActivity(ctx context.Context) ([]inactiveMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT pm.project_id, p.org_id, pm.user_id,
		        GREATEST(
		          pm.joined_at,
		          COALESCE((SELECT max(e.created_at) FROM work_item_events e WHERE e.actor_id = pm.user_id AND e.project_id = pm.project_id), 'epoch'::timestamptz),
		          COALESCE((SELECT max(t.created_at) FROM work_item_time_logs t WHERE t.user_id = pm.user_id AND t.project_id = pm.project_id), 'epoch'::timestamptz),
		          COALESCE((SELECT max(su.created_at) FROM standup_updates su WHERE su.user_id = pm.user_id AND su.project_id = pm.project_id), 'epoch'::timestamptz),
		          COALESCE((SELECT max(c.committed_at) FROM gitlab_commits c WHERE c.user_id = pm.user_id AND c.team_id = p.team_id), 'epoch'::timestamptz)
		        ) AS last_active
		   FROM project_members pm JOIN workspace_projects p ON p.id = pm.project_id
		  WHERE pm.status = 'active' AND p.project_status = 'active'`)
	if err != nil {
		return nil, fmt.Errorf("workspace: list active members last activity: %w", err)
	}
	defer rows.Close()
	out := []inactiveMember{}
	for rows.Next() {
		var m inactiveMember
		if err := rows.Scan(&m.ProjectID, &m.OrgID, &m.UserID, &m.LastActive); err != nil {
			return nil, fmt.Errorf("workspace: scan active member last activity: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

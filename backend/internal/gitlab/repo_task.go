package gitlab

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// ─── project_tasks ──────────────────────────────────────────────────────────
// Batch 7 — see models.go's own "Batch 7" section.

const taskColumns = `
	id, org_id, team_id, checkpoint_id, title, description, assignee_user_id, status, due_at, created_by, created_at, updated_at`

func scanTask(row pgx.Row) (*ProjectTask, error) {
	var t ProjectTask
	err := row.Scan(&t.ID, &t.OrgID, &t.TeamID, &t.CheckpointID, &t.Title, &t.Description, &t.AssigneeUserID, &t.Status, &t.DueAt, &t.CreatedBy, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan task: %w", err)
	}
	return &t, nil
}

// CreateTask inserts a new task on a team's board.
func (r *Repo) CreateTask(ctx context.Context, t ProjectTask) (*ProjectTask, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_tasks (org_id, team_id, checkpoint_id, title, description, assignee_user_id, due_at, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 RETURNING `+taskColumns,
		t.OrgID, t.TeamID, t.CheckpointID, t.Title, t.Description, t.AssigneeUserID, t.DueAt, t.CreatedBy,
	)
	created, err := scanTask(row)
	if err != nil {
		return nil, fmt.Errorf("gitlab: create task: %w", err)
	}
	return created, nil
}

// GetTask returns a single org-scoped task.
func (r *Repo) GetTask(ctx context.Context, orgID, id string) (*ProjectTask, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+taskColumns+` FROM project_tasks WHERE id = $1 AND org_id = $2`, id, orgID)
	return scanTask(row)
}

// ListTasksForTeam returns every task on a team's board, grouped implicitly
// by the caller sorting client-side (status, then most-recently-updated) —
// small boards, no server-side pagination needed. LEFT JOINed against users
// for the assignee's display name — there is no other student-facing team
// roster endpoint (routes.go's /members is staff-only), so this join is the
// only way the board can show "assigned to X" instead of a bare user ID.
func (r *Repo) ListTasksForTeam(ctx context.Context, teamID string) ([]ProjectTask, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT t.id, t.org_id, t.team_id, t.checkpoint_id, t.title, t.description, t.assignee_user_id, t.status, t.due_at,
		        t.created_by, t.created_at, t.updated_at, COALESCE(u.name, '')
		 FROM project_tasks t
		 LEFT JOIN users u ON u.id = t.assignee_user_id
		 WHERE t.team_id = $1
		 ORDER BY t.updated_at DESC`,
		teamID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list tasks for team: %w", err)
	}
	defer rows.Close()

	out := []ProjectTask{}
	for rows.Next() {
		var t ProjectTask
		if err := rows.Scan(
			&t.ID, &t.OrgID, &t.TeamID, &t.CheckpointID, &t.Title, &t.Description, &t.AssigneeUserID, &t.Status, &t.DueAt,
			&t.CreatedBy, &t.CreatedAt, &t.UpdatedAt, &t.AssigneeName,
		); err != nil {
			return nil, fmt.Errorf("gitlab: scan task with assignee name: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// UpdateTask applies a partial patch (nil fields left untouched).
func (r *Repo) UpdateTask(ctx context.Context, orgID, id string, p TaskPatch) (*ProjectTask, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_tasks SET
			title = COALESCE($3, title),
			description = COALESCE($4, description),
			status = COALESCE($5, status),
			due_at = COALESCE($6, due_at),
			updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+taskColumns,
		id, orgID, p.Title, p.Description, p.Status, p.DueAt,
	)
	return scanTask(row)
}

// SetTaskAssignee always overwrites the assignee (nil clears it) — a
// dedicated call rather than folded into TaskPatch's COALESCE semantics, see
// TaskPatch's own doc comment for why.
func (r *Repo) SetTaskAssignee(ctx context.Context, orgID, id string, assigneeUserID *string) (*ProjectTask, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_tasks SET assignee_user_id = $3, updated_at = now() WHERE id = $1 AND org_id = $2 RETURNING `+taskColumns,
		id, orgID, assigneeUserID,
	)
	return scanTask(row)
}

// DeleteTask hard-deletes a task.
func (r *Repo) DeleteTask(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM project_tasks WHERE id = $1 AND org_id = $2`, id, orgID)
	if err != nil {
		return fmt.Errorf("gitlab: delete task: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

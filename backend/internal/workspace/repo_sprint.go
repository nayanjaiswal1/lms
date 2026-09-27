package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_sprint.go — Phase 5 (contract-phase5.md 5a) data layer for sprints and
// sprint_commitments (migration 040).

const sprintRollupSelect = `s.id, s.name, s.starts_on, s.ends_on, s.status, s.created_at,
	(SELECT count(*) FROM sprint_commitments sc WHERE sc.sprint_id = s.id),
	(SELECT count(*) FROM sprint_commitments sc JOIN work_items w ON w.id = sc.item_id
	  WHERE sc.sprint_id = s.id AND w.status = 'done')`

func scanSprint(row pgx.Row) (*Sprint, error) {
	var sp Sprint
	var startsOn, endsOn time.Time
	if err := row.Scan(&sp.ID, &sp.Name, &startsOn, &endsOn, &sp.Status, &sp.CreatedAt, &sp.Committed, &sp.Done); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan sprint: %w", err)
	}
	sp.StartsOn = startsOn.Format("2006-01-02")
	sp.EndsOn = endsOn.Format("2006-01-02")
	return &sp, nil
}

// ListSprints returns every sprint for a project, newest first, with
// commitment/done rollups.
func (r *Repo) ListSprints(ctx context.Context, db DBTX, projectID string) ([]Sprint, error) {
	rows, err := db.Query(ctx,
		`SELECT `+sprintRollupSelect+` FROM sprints s WHERE s.project_id = $1 ORDER BY s.starts_on DESC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list sprints: %w", err)
	}
	defer rows.Close()
	out := []Sprint{}
	for rows.Next() {
		sp, err := scanSprint(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *sp)
	}
	return out, rows.Err()
}

// GetSprint returns one sprint with rollups.
func (r *Repo) GetSprint(ctx context.Context, db DBTX, projectID, sprintID string) (*Sprint, error) {
	return scanSprint(db.QueryRow(ctx,
		`SELECT `+sprintRollupSelect+` FROM sprints s WHERE s.id = $1 AND s.project_id = $2`,
		sprintID, projectID))
}

// LockSprint takes the sprint row lock StartSprint/CloseSprint hold across
// their status check and write.
func (r *Repo) LockSprint(ctx context.Context, tx pgx.Tx, projectID, sprintID string) (*Sprint, error) {
	row := tx.QueryRow(ctx,
		`SELECT s.id, s.name, s.starts_on, s.ends_on, s.status, s.created_at, 0, 0
		   FROM sprints s WHERE s.id = $1 AND s.project_id = $2 FOR UPDATE`,
		sprintID, projectID)
	return scanSprint(row)
}

// ActiveSprint returns the project's one active sprint, or ErrNotFound.
func (r *Repo) ActiveSprint(ctx context.Context, db DBTX, projectID string) (*Sprint, error) {
	return scanSprint(db.QueryRow(ctx,
		`SELECT `+sprintRollupSelect+` FROM sprints s WHERE s.project_id = $1 AND s.status = 'active'`,
		projectID))
}

// InsertSprint creates a new planned sprint. startsOn/endsOn are "YYYY-MM-DD".
func (r *Repo) InsertSprint(ctx context.Context, db DBTX, projectID, name, startsOn, endsOn, createdBy string) (*Sprint, error) {
	row := db.QueryRow(ctx,
		`INSERT INTO sprints (project_id, name, starts_on, ends_on, created_by) VALUES ($1,$2,$3,$4,$5)
		 RETURNING id, name, starts_on, ends_on, status, created_at, 0, 0`,
		projectID, name, startsOn, endsOn, createdBy,
	)
	return scanSprint(row)
}

// UpdateSprintStatus applies a machine-checked planned→active→completed
// transition. tx must already hold the sprint row's lock (LockSprint).
func (r *Repo) UpdateSprintStatus(ctx context.Context, tx pgx.Tx, projectID, sprintID, to string) (*Sprint, error) {
	row := tx.QueryRow(ctx,
		`UPDATE sprints SET status = $3, updated_at = now() WHERE id = $1 AND project_id = $2
		 RETURNING id, name, starts_on, ends_on, status, created_at, 0, 0`,
		sprintID, projectID, to,
	)
	return scanSprint(row)
}

// SnapshotSprintCommitments copies every item currently targeting sprintID
// into sprint_commitments — StartSprint's own "snapshot sprint_commitments
// for items with sprint_id" step.
func (r *Repo) SnapshotSprintCommitments(ctx context.Context, tx pgx.Tx, sprintID string) error {
	if _, err := tx.Exec(ctx,
		`INSERT INTO sprint_commitments (sprint_id, item_id)
		   SELECT $1, id FROM work_items WHERE sprint_id = $1 AND archived_at IS NULL
		 ON CONFLICT (sprint_id, item_id) DO NOTHING`,
		sprintID,
	); err != nil {
		return fmt.Errorf("workspace: snapshot sprint commitments: %w", err)
	}
	return nil
}

// ListUnfinishedSprintItems returns every non-archived, non-done/wont_do item
// still targeting sprintID — CloseSprint's own carry-over/backlog input.
func (r *Repo) ListUnfinishedSprintItems(ctx context.Context, tx pgx.Tx, projectID, sprintID string) ([]WorkItem, error) {
	rows, err := tx.Query(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.sprint_id = $2 AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do')`,
		projectID, sprintID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list unfinished sprint items: %w", err)
	}
	defer rows.Close()
	out := []WorkItem{}
	for rows.Next() {
		it, err := scanWorkItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *it)
	}
	return out, rows.Err()
}

// SetItemSprintSystem re-targets an item's sprint without an optimistic
// version check — CloseSprint's own bulk carry-over/backlog move, driven by
// the manager closing the sprint rather than the item's own editor.
func (r *Repo) SetItemSprintSystem(ctx context.Context, tx pgx.Tx, projectID, itemID string, sprintID *string) (*WorkItem, error) {
	row := tx.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET sprint_id = $3, version = version + 1, updated_at = now()
			 WHERE id = $1 AND project_id = $2 AND archived_at IS NULL
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, sprintID,
	)
	return scanWorkItem(row)
}

// SetItemSprint sets (or clears) an item's sprint_id under the optimistic
// version lock — the user-facing PUT …/items/{itemID}/sprint path.
func (r *Repo) SetItemSprint(ctx context.Context, tx pgx.Tx, projectID, itemID string, expectedVersion int, sprintID *string) (*WorkItem, error) {
	row := tx.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET sprint_id = $4, version = version + 1, updated_at = now()
			 WHERE id = $1 AND project_id = $2 AND version = $3 AND archived_at IS NULL
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, expectedVersion, sprintID,
	)
	return scanWorkItem(row)
}

// SprintBurndown mirrors Burndown (repo_dashboard.go) scoped to one sprint's
// committed item set and date range — the dashboard's "burndown over the
// active sprint" (contract-phase5.md).
func (r *Repo) SprintBurndown(ctx context.Context, db DBTX, sprintID string, from, to time.Time) ([]DayPoint, error) {
	rows, err := db.Query(ctx,
		`WITH committed AS (SELECT item_id FROM sprint_commitments WHERE sprint_id = $1),
		      days AS (SELECT generate_series($2::date, $3::date, interval '1 day')::date AS day)
		 SELECT d.day,
		        (SELECT count(*) FROM committed c)
		          - (SELECT count(*) FROM work_item_events e JOIN committed c ON c.item_id = e.item_id
		              WHERE e.kind = 'status' AND e.to_value IN ('done','wont_do') AND e.created_at::date <= d.day),
		        COALESCE((SELECT count(*) FROM work_item_events e JOIN committed c ON c.item_id = e.item_id
		           WHERE e.kind = 'status' AND e.to_value = 'done' AND e.created_at::date = d.day), 0),
		        0
		   FROM days d ORDER BY d.day`,
		sprintID, from, to)
	if err != nil {
		return nil, fmt.Errorf("workspace: sprint burndown: %w", err)
	}
	defer rows.Close()
	out := []DayPoint{}
	for rows.Next() {
		var day time.Time
		var p DayPoint
		if err := rows.Scan(&day, &p.Open, &p.Done, &p.Added); err != nil {
			return nil, fmt.Errorf("workspace: scan sprint burndown day: %w", err)
		}
		if p.Open < 0 {
			p.Open = 0
		}
		p.Day = day.Format("2006-01-02")
		out = append(out, p)
	}
	return out, rows.Err()
}

// ScopeChurnAfterSprintStart counts `sprint` events targeting sprintID after
// startedAt — the dashboard's own scope-churn signal for an active sprint.
func (r *Repo) ScopeChurnAfterSprintStart(ctx context.Context, db DBTX, sprintID string, startedAt time.Time) (added, removed int, err error) {
	err = db.QueryRow(ctx,
		`SELECT count(*) FILTER (WHERE e.to_value = $1), count(*) FILTER (WHERE e.from_value = $1 AND e.to_value IS DISTINCT FROM $1)
		   FROM work_item_events e WHERE e.kind = 'sprint' AND e.created_at > $2`,
		sprintID, startedAt,
	).Scan(&added, &removed)
	if err != nil {
		return 0, 0, fmt.Errorf("workspace: scope churn after sprint start: %w", err)
	}
	return added, removed, nil
}

// SprintStartedAt resolves an active sprint's own start moment (its most
// recent planned→active status... sprints have no dedicated events table, so
// this reads the sprint row's own updated_at, set exactly on StartSprint's
// UpdateSprintStatus write).
func (r *Repo) SprintStartedAt(ctx context.Context, db DBTX, sprintID string) (time.Time, error) {
	var t time.Time
	if err := db.QueryRow(ctx, `SELECT updated_at FROM sprints WHERE id = $1`, sprintID).Scan(&t); err != nil {
		return time.Time{}, fmt.Errorf("workspace: sprint started at: %w", err)
	}
	return t, nil
}

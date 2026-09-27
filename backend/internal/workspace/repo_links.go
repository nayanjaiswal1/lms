package workspace

import (
	"context"
	"errors"
	"fmt"
	"strconv"

	"github.com/jackc/pgx/v5"
)

// LockItemGraph takes the per-project advisory transaction lock that
// serialises every `blocks`-cycle check and Move's ancestor rewrite (01 §4).
// pg_advisory_xact_lock auto-releases at commit/rollback, which is required
// behind the Neon pooler — a session-scoped lock would leak across pooled
// connections.
func (r *Repo) LockItemGraph(ctx context.Context, tx pgx.Tx, projectID string) error {
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended('work_item_graph:' || $1, 0))`, projectID); err != nil {
		return fmt.Errorf("workspace: lock item graph: %w", err)
	}
	return nil
}

// LoadBlocksEdges loads every `blocks` edge in a project into an in-memory
// adjacency map for statemachine.HasPath — the "shared DFS ... once the
// graph is loaded under the project graph lock" statemachine.go documents.
// Must be called after LockItemGraph in the same tx.
func (r *Repo) LoadBlocksEdges(ctx context.Context, tx pgx.Tx, projectID string) (map[string][]string, error) {
	rows, err := tx.Query(ctx, `SELECT from_id, to_id FROM work_item_links WHERE project_id = $1 AND kind = 'blocks'`, projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: load blocks edges: %w", err)
	}
	defer rows.Close()
	edges := map[string][]string{}
	for rows.Next() {
		var from, to string
		if err := rows.Scan(&from, &to); err != nil {
			return nil, fmt.Errorf("workspace: scan blocks edge: %w", err)
		}
		edges[from] = append(edges[from], to)
	}
	return edges, rows.Err()
}

// InsertLink inserts one work_item_links row. Duplicate-kind/relates/duplicates
// violations surface as db.IsUniqueViolation for the caller to map to ErrConflict.
func (r *Repo) InsertLink(ctx context.Context, tx pgx.Tx, projectID, fromID, toID, kind, createdBy string) error {
	if _, err := tx.Exec(ctx,
		`INSERT INTO work_item_links (project_id, from_id, to_id, kind, created_by) VALUES ($1,$2,$3,$4,$5)`,
		projectID, fromID, toID, kind, createdBy,
	); err != nil {
		return err
	}
	return nil
}

// DeleteLink removes one link row.
func (r *Repo) DeleteLink(ctx context.Context, db DBTX, projectID, fromID, toID, kind string) error {
	tag, err := db.Exec(ctx,
		`DELETE FROM work_item_links WHERE project_id = $1 AND from_id = $2 AND to_id = $3 AND kind = $4`,
		projectID, fromID, toID, kind,
	)
	if err != nil {
		return fmt.Errorf("workspace: delete link: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// LinkExists reports whether the exact (from,to,kind) row is already there —
// used by the blocked-transition path to avoid inserting a duplicate blocker
// link (contract: "creates the blocker → item blocks link if absent").
func (r *Repo) LinkExists(ctx context.Context, db DBTX, fromID, toID, kind string) (bool, error) {
	var exists bool
	if err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM work_item_links WHERE from_id = $1 AND to_id = $2 AND kind = $3)`,
		fromID, toID, kind,
	).Scan(&exists); err != nil {
		return false, fmt.Errorf("workspace: check link exists: %w", err)
	}
	return exists, nil
}

// ListItemLinks returns every link touching itemID, from both directions.
func (r *Repo) ListItemLinks(ctx context.Context, db DBTX, projectID, itemID string) ([]ItemLink, error) {
	rows, err := db.Query(ctx,
		`SELECT l.kind, 'outgoing', `+itemRefColumns+`, l.created_by, l.created_at
		   FROM work_item_links l JOIN work_items w ON w.id = l.to_id JOIN workspace_projects p ON p.id = w.project_id
		  WHERE l.project_id = $1 AND l.from_id = $2
		 UNION ALL
		 SELECT l.kind, 'incoming', `+itemRefColumns+`, l.created_by, l.created_at
		   FROM work_item_links l JOIN work_items w ON w.id = l.from_id JOIN workspace_projects p ON p.id = w.project_id
		  WHERE l.project_id = $1 AND l.to_id = $2`,
		projectID, itemID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list item links: %w", err)
	}
	defer rows.Close()

	out := []ItemLink{}
	for rows.Next() {
		var l ItemLink
		var keyPrefix string
		var keyNum int
		if err := rows.Scan(&l.Kind, &l.Direction, &l.Other.ID, &keyNum, &l.Other.Type, &l.Other.Title, &l.Other.Status, &keyPrefix, &l.CreatedBy, &l.CreatedAt); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return nil, fmt.Errorf("workspace: scan item link: %w", err)
		}
		l.Other.Key = keyPrefix + "-" + strconv.Itoa(keyNum)
		out = append(out, l)
	}
	return out, rows.Err()
}

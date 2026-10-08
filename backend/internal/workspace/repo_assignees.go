package workspace

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// ListAssigneesByItem returns one item's assignee rows with the user's name.
func (r *Repo) ListAssigneesByItem(ctx context.Context, db DBTX, itemID string) ([]Assignee, error) {
	rows, err := db.Query(ctx,
		`SELECT a.user_id, u.name, a.role, a.assigned_by, a.assigned_at
		   FROM work_item_assignees a JOIN users u ON u.id = a.user_id
		  WHERE a.item_id = $1
		  ORDER BY a.role, u.name`,
		itemID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list assignees: %w", err)
	}
	defer rows.Close()
	out := []Assignee{}
	for rows.Next() {
		var a Assignee
		if err := rows.Scan(&a.UserID, &a.Name, &a.Role, &a.AssignedBy, &a.AssignedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan assignee: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// ListAssigneesForItems batch-loads assignees for a page of items (list/board
// reads), keyed by item id, avoiding one round trip per row.
func (r *Repo) ListAssigneesForItems(ctx context.Context, db DBTX, itemIDs []string) (map[string][]Assignee, error) {
	out := map[string][]Assignee{}
	if len(itemIDs) == 0 {
		return out, nil
	}
	rows, err := db.Query(ctx,
		`SELECT a.item_id, a.user_id, u.name, a.role, a.assigned_by, a.assigned_at
		   FROM work_item_assignees a JOIN users u ON u.id = a.user_id
		  WHERE a.item_id = ANY($1)
		  ORDER BY a.role, u.name`,
		itemIDs)
	if err != nil {
		return nil, fmt.Errorf("workspace: batch list assignees: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var itemID string
		var a Assignee
		if err := rows.Scan(&itemID, &a.UserID, &a.Name, &a.Role, &a.AssignedBy, &a.AssignedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan batch assignee: %w", err)
		}
		out[itemID] = append(out[itemID], a)
	}
	return out, rows.Err()
}

// InsertAssignee adds one assignee row. Unique-violation on the one-owner
// partial index surfaces as db.IsUniqueViolation to the caller (service_assign.go
// maps it to ErrConflict — 02 §4 "unique-owner violation (23505) → ErrConflict").
func (r *Repo) InsertAssignee(ctx context.Context, tx pgx.Tx, itemID, userID, role, assignedBy string) error {
	if _, err := tx.Exec(ctx,
		`INSERT INTO work_item_assignees (item_id, user_id, role, assigned_by) VALUES ($1,$2,$3,$4)`,
		itemID, userID, role, assignedBy,
	); err != nil {
		return err
	}
	return nil
}

func (r *Repo) DeleteAssignee(ctx context.Context, tx pgx.Tx, itemID, userID, role string) error {
	if _, err := tx.Exec(ctx,
		`DELETE FROM work_item_assignees WHERE item_id = $1 AND user_id = $2 AND role = $3`,
		itemID, userID, role,
	); err != nil {
		return fmt.Errorf("workspace: delete assignee: %w", err)
	}
	return nil
}

// LeavingItemAssignment is one open item a leaving/removed member was
// assigned to (service_onboarding.go's RemoveMember cascade, contract-
// phase4.md 4c).
type LeavingItemAssignment struct {
	ItemID  string
	ItemKey string
	Role    string
}

// ListOpenAssignmentsForUser returns every non-archived, non-terminal
// (not done/wont_do) item's assignee rows for userID in projectID — every
// role, not just owner, since RemoveMember drops all of them on an open item
// (reviewer/tester/developer included) while leaving history on closed items
// untouched.
func (r *Repo) ListOpenAssignmentsForUser(ctx context.Context, tx pgx.Tx, projectID, userID string) ([]LeavingItemAssignment, error) {
	rows, err := tx.Query(ctx,
		`SELECT wia.item_id, p.key_prefix || '-' || w.key_num, wia.role
		   FROM work_item_assignees wia
		   JOIN work_items w ON w.id = wia.item_id
		   JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND wia.user_id = $2
		    AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do')`,
		projectID, userID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list open assignments for user: %w", err)
	}
	defer rows.Close()
	out := []LeavingItemAssignment{}
	for rows.Next() {
		var a LeavingItemAssignment
		if err := rows.Scan(&a.ItemID, &a.ItemKey, &a.Role); err != nil {
			return nil, fmt.Errorf("workspace: scan open assignment: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// IsApprovedTrackMember reports whether userID is an approved member of
// trackID — the assignee eligibility rule for a tracked item.
func (r *Repo) IsApprovedTrackMember(ctx context.Context, db DBTX, trackID, userID string) (bool, error) {
	var ok bool
	if err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM project_track_members WHERE track_id = $1 AND user_id = $2 AND status = 'approved')`,
		trackID, userID,
	).Scan(&ok); err != nil {
		return false, fmt.Errorf("workspace: check track membership: %w", err)
	}
	return ok, nil
}

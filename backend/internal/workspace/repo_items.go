package workspace

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

// Phase 2 — work items data layer. Every query joins workspace_projects so
// the item's display key (key_prefix + "-" + key_num) is computed once, in
// SQL, everywhere an item is read.

const workItemColumns = `w.id, w.project_id, w.key_num, w.type, w.parent_id, w.epic_id, w.feature_id, w.track_id,
	w.release_id, w.sprint_id,
	w.title, w.description, w.status, w.priority, w.severity, w.is_regression, w.estimate_minutes,
	w.doc_wiki_page_id, w.doc_status, w.approved_doc_version, w.spec_changed_at, w.blocked_reason,
	w.reopen_count, w.version, w.due_at, w.created_by, w.archived_at, w.created_at, w.updated_at, p.key_prefix`

func scanWorkItem(row pgx.Row) (*WorkItem, error) {
	var it WorkItem
	var keyPrefix string
	err := row.Scan(
		&it.ID, &it.ProjectID, &it.KeyNum, &it.Type, &it.ParentID, &it.EpicID, &it.FeatureID, &it.TrackID,
		&it.ReleaseID, &it.SprintID,
		&it.Title, &it.Description, &it.Status, &it.Priority, &it.Severity, &it.IsRegression, &it.EstimateMinutes,
		&it.DocWikiPageID, &it.DocStatus, &it.ApprovedDocVersion, &it.SpecChangedAt, &it.BlockedReason,
		&it.ReopenCount, &it.Version, &it.DueAt, &it.CreatedBy, &it.ArchivedAt, &it.CreatedAt, &it.UpdatedAt, &keyPrefix,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan work item: %w", err)
	}
	it.Key = keyPrefix + "-" + strconv.Itoa(it.KeyNum)
	it.Assignees = []Assignee{}
	return &it, nil
}

// itemInsert is the fully-resolved set of columns CreateWorkItem writes.
type itemInsert struct {
	Type            string
	ParentID        *string
	EpicID          *string
	FeatureID       *string
	TrackID         *string
	Title           string
	Description     *string
	Priority        string
	Severity        *string
	EstimateMinutes *int
	DueAt           *time.Time
	CreatedBy       string
}

// BumpItemSeq atomically reserves the next key number for a project, only
// while it's still writable (01 §4 "Item key counter") — 0 rows means the
// project moved to a terminal status concurrently.
func (r *Repo) BumpItemSeq(ctx context.Context, tx pgx.Tx, projectID string) (keyNum int, keyPrefix string, err error) {
	err = tx.QueryRow(ctx,
		`UPDATE workspace_projects SET item_seq = item_seq + 1, updated_at = now()
		  WHERE id = $1 AND project_status IN ('draft','recruiting','active')
		 RETURNING item_seq, key_prefix`,
		projectID,
	).Scan(&keyNum, &keyPrefix)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, "", ErrInvalidState
	}
	if err != nil {
		return 0, "", fmt.Errorf("workspace: bump item seq: %w", err)
	}
	return keyNum, keyPrefix, nil
}

// InsertWorkItem inserts the row at keyNum (already reserved by BumpItemSeq
// in the same tx) and returns the scanned item.
func (r *Repo) InsertWorkItem(ctx context.Context, tx pgx.Tx, projectID string, keyNum int, in itemInsert) (*WorkItem, error) {
	row := tx.QueryRow(ctx,
		`WITH ins AS (
			INSERT INTO work_items
				(project_id, key_num, type, parent_id, epic_id, feature_id, track_id, title, description,
				 priority, severity, estimate_minutes, due_at, created_by)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM ins)`,
		projectID, keyNum, in.Type, in.ParentID, in.EpicID, in.FeatureID, in.TrackID, in.Title, in.Description,
		in.Priority, in.Severity, in.EstimateMinutes, in.DueAt, in.CreatedBy,
	)
	return scanWorkItem(row)
}

// GetWorkItemByID scopes strictly by (id, project_id) — the composite
// uniqueness the 037 FKs rely on.
func (r *Repo) GetWorkItemByID(ctx context.Context, db DBTX, projectID, itemID string) (*WorkItem, error) {
	return scanWorkItem(db.QueryRow(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = $1 AND w.project_id = $2`,
		itemID, projectID))
}

// GetWorkItemByKeyNum resolves the numeric half of a "PREFIX-123" ref.
func (r *Repo) GetWorkItemByKeyNum(ctx context.Context, db DBTX, projectID string, keyNum int) (*WorkItem, error) {
	return scanWorkItem(db.QueryRow(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.key_num = $2`,
		projectID, keyNum))
}

// LockWorkItem is GetWorkItemByID under FOR UPDATE — the item-row lock every
// write path (update, move, transition, assignees) takes before checking or
// writing anything else (01 §4's canonical lock order).
func (r *Repo) LockWorkItem(ctx context.Context, tx pgx.Tx, projectID, itemID string) (*WorkItem, error) {
	return scanWorkItem(tx.QueryRow(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = $1 AND w.project_id = $2 FOR UPDATE OF w`,
		itemID, projectID))
}

// UpdateItemFields applies a fully-resolved PATCH under the optimistic lock:
// 0 rows means either the version is stale (row still exists) or the item is
// gone/archived — the caller (service_items.go) tells those apart with a
// follow-up read.
func (r *Repo) UpdateItemFields(ctx context.Context, db DBTX, projectID, itemID string, expectedVersion int, title string, description *string, priority string, severity *string, isRegression bool, estimateMinutes *int, dueAt *time.Time, trackID *string) (*WorkItem, error) {
	row := db.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET
				title = $4, description = $5, priority = $6, severity = $7, is_regression = $8,
				estimate_minutes = $9, due_at = $10, track_id = $11, version = version + 1, updated_at = now()
			 WHERE id = $1 AND project_id = $2 AND version = $3 AND archived_at IS NULL
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, expectedVersion, title, description, priority, severity, isRegression, estimateMinutes, dueAt, trackID,
	)
	return scanWorkItem(row)
}

// UpdateItemParent re-parents an item (and, by the caller recomputing every
// descendant's epic_id/feature_id under the same graph lock, its whole
// subtree) — Move's own version check.
func (r *Repo) UpdateItemParent(ctx context.Context, tx pgx.Tx, projectID, itemID string, expectedVersion int, parentID, epicID, featureID *string) (*WorkItem, error) {
	row := tx.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET parent_id = $4, epic_id = $5, feature_id = $6, version = version + 1, updated_at = now()
			 WHERE id = $1 AND project_id = $2 AND version = $3 AND archived_at IS NULL
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, expectedVersion, parentID, epicID, featureID,
	)
	return scanWorkItem(row)
}

// UpdateDescendantAncestors rewrites epic_id/feature_id on every existing
// descendant of itemID after a move — called under the project graph lock,
// in the same tx as UpdateItemParent (Move re-checks the whole subtree).
func (r *Repo) UpdateDescendantAncestors(ctx context.Context, tx pgx.Tx, projectID, itemID string, newEpicID, newFeatureID *string) error {
	if _, err := tx.Exec(ctx,
		`WITH RECURSIVE sub AS (
			SELECT id, type FROM work_items WHERE parent_id = $1 AND project_id = $2
			UNION ALL
			SELECT w.id, w.type FROM work_items w JOIN sub s ON w.parent_id = s.id WHERE w.project_id = $2
		 )
		 UPDATE work_items w SET
			epic_id = CASE WHEN w.type = 'epic' THEN NULL ELSE $3 END,
			feature_id = CASE WHEN w.type IN ('epic','feature') THEN NULL ELSE $4 END,
			updated_at = now()
		  FROM sub WHERE w.id = sub.id`,
		itemID, projectID, newEpicID, newFeatureID,
	); err != nil {
		return fmt.Errorf("workspace: update descendant ancestors: %w", err)
	}
	return nil
}

// UpdateItemStatus writes a status change (leaf transition or a system
// roll-up) plus its version bump. reason only applies to the row's own
// blocked_reason column; the event row is written separately
// (repo_events.go) in the same tx.
func (r *Repo) UpdateItemStatus(ctx context.Context, db DBTX, projectID, itemID, newStatus string, reason *string) (*WorkItem, error) {
	row := db.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET
				status = $3,
				blocked_reason = CASE WHEN $3 = 'blocked' THEN $4 ELSE NULL END,
				reopen_count = CASE WHEN $3 = 'reopened' THEN reopen_count + 1 ELSE reopen_count END,
				version = version + 1, updated_at = now()
			 WHERE id = $1 AND project_id = $2
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, newStatus, reason,
	)
	return scanWorkItem(row)
}

// ArchiveItem sets archived_at — refused (0 rows) when it already has
// non-archived children (service_items.go checks that first, but the FK on
// parent_id gives no defence here since archiving isn't a delete).
func (r *Repo) ArchiveItem(ctx context.Context, db DBTX, projectID, itemID string) error {
	tag, err := db.Exec(ctx,
		`UPDATE work_items SET archived_at = now(), updated_at = now()
		  WHERE id = $1 AND project_id = $2 AND archived_at IS NULL`,
		itemID, projectID,
	)
	if err != nil {
		return fmt.Errorf("workspace: archive item: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteItem hard-deletes — only ever called after the service confirms
// "todo, single create event".
func (r *Repo) DeleteItem(ctx context.Context, tx pgx.Tx, projectID, itemID string) error {
	tag, err := tx.Exec(ctx, `DELETE FROM work_items WHERE id = $1 AND project_id = $2`, itemID, projectID)
	if err != nil {
		return fmt.Errorf("workspace: delete item: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CountNonArchivedChildren reports whether itemID still has live children —
// Archive's "not while it has non-archived children" rule.
func (r *Repo) CountNonArchivedChildren(ctx context.Context, db DBTX, itemID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_items WHERE parent_id = $1 AND archived_at IS NULL`, itemID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count children: %w", err)
	}
	return n, nil
}

// ListChildStatuses returns the statuses of itemID's direct non-archived
// children — the roll-up's own input (service_execution.go computes the
// aggregate; this is deliberately dumb).
func (r *Repo) ListChildStatuses(ctx context.Context, db DBTX, itemID string) ([]string, error) {
	rows, err := db.Query(ctx, `SELECT status FROM work_items WHERE parent_id = $1 AND archived_at IS NULL`, itemID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list child statuses: %w", err)
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ItemRef projection, shared by parent/children/link lookups.
func scanItemRef(row pgx.Row) (*ItemRef, error) {
	var ref ItemRef
	var keyPrefix string
	var keyNum int
	if err := row.Scan(&ref.ID, &keyNum, &ref.Type, &ref.Title, &ref.Status, &keyPrefix); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan item ref: %w", err)
	}
	ref.Key = keyPrefix + "-" + strconv.Itoa(keyNum)
	return &ref, nil
}

const itemRefColumns = `w.id, w.key_num, w.type, w.title, w.status, p.key_prefix`

// GetItemRef loads the compact pointer form of one item.
func (r *Repo) GetItemRef(ctx context.Context, db DBTX, projectID, itemID string) (*ItemRef, error) {
	return scanItemRef(db.QueryRow(ctx,
		`SELECT `+itemRefColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = $1 AND w.project_id = $2`,
		itemID, projectID))
}

// ListChildRefs returns every non-archived direct child of itemID.
func (r *Repo) ListChildRefs(ctx context.Context, db DBTX, projectID, itemID string) ([]ItemRef, error) {
	rows, err := db.Query(ctx,
		`SELECT `+itemRefColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.parent_id = $2 AND w.archived_at IS NULL
		  ORDER BY w.key_num ASC`,
		projectID, itemID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list child refs: %w", err)
	}
	defer rows.Close()
	out := []ItemRef{}
	for rows.Next() {
		ref, err := scanItemRef(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *ref)
	}
	return out, rows.Err()
}

// ─── list ───────────────────────────────────────────────────────────────────

// ListWorkItems applies ItemFilter with keyset pagination on (created_at, id).
func (r *Repo) ListWorkItems(ctx context.Context, db DBTX, projectID string, f ItemFilter, cursorAt time.Time, cursorID string, limit int) ([]WorkItem, error) {
	where := []string{"w.project_id = $1"}
	args := []any{projectID}
	arg := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}
	if !f.IncludeArchived {
		where = append(where, "w.archived_at IS NULL")
	}
	if f.Type != "" {
		where = append(where, "w.type = "+arg(f.Type))
	}
	if f.Status != "" {
		where = append(where, "w.status = "+arg(f.Status))
	}
	if f.TrackID != "" {
		where = append(where, "w.track_id = "+arg(f.TrackID))
	}
	if f.ParentID != "" {
		where = append(where, "w.parent_id = "+arg(f.ParentID))
	}
	if f.FeatureID != "" {
		where = append(where, "w.feature_id = "+arg(f.FeatureID))
	}
	if f.EpicID != "" {
		where = append(where, "w.epic_id = "+arg(f.EpicID))
	}
	if f.ReleaseID != "" {
		where = append(where, "w.release_id = "+arg(f.ReleaseID))
	}
	if f.SprintID != "" {
		where = append(where, "w.sprint_id = "+arg(f.SprintID))
	}
	if f.AssigneeID != "" {
		where = append(where, "EXISTS (SELECT 1 FROM work_item_assignees a WHERE a.item_id = w.id AND a.user_id = "+arg(f.AssigneeID)+")")
	}
	if f.Q != "" {
		where = append(where, "w.title ILIKE "+arg("%"+f.Q+"%"))
	}
	if cursorID != "" {
		where = append(where, fmt.Sprintf("(w.created_at, w.id) > (%s, %s)", arg(cursorAt), arg(cursorID)))
	}
	args = append(args, limit)

	query := `SELECT ` + workItemColumns + ` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		WHERE ` + joinAnd(where) + ` ORDER BY w.created_at ASC, w.id ASC LIMIT $` + strconv.Itoa(len(args))
	rows, err := db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("workspace: list work items: %w", err)
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

func joinAnd(parts []string) string {
	out := parts[0]
	for _, p := range parts[1:] {
		out += " AND " + p
	}
	return out
}

// ListSimilarItems runs the trgm dedup query (01 §4 "Dedup"): SET LOCAL keeps
// the threshold change scoped to this transaction only, which is required
// behind the Neon pooler (set_limit() is session-scoped and unsafe there).
func (r *Repo) ListSimilarItems(ctx context.Context, tx pgx.Tx, projectID, q, excludeItemID string) ([]SimilarItem, error) {
	if _, err := tx.Exec(ctx, fmt.Sprintf("SET LOCAL pg_trgm.similarity_threshold = %f", SimilarityThreshold)); err != nil {
		return nil, fmt.Errorf("workspace: set similarity threshold: %w", err)
	}
	rows, err := tx.Query(ctx,
		`SELECT w.id, w.key_num, p.key_prefix, w.title, w.type, w.status, similarity(w.title, $2) AS sim
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do')
		    AND w.id <> COALESCE(NULLIF($3, '')::uuid, '00000000-0000-0000-0000-000000000000'::uuid)
		    AND w.title % $2
		  ORDER BY sim DESC LIMIT $4`,
		projectID, q, excludeItemID, SimilarLimit,
	)
	if err != nil {
		return nil, fmt.Errorf("workspace: list similar items: %w", err)
	}
	defer rows.Close()

	out := []SimilarItem{}
	for rows.Next() {
		var s SimilarItem
		var keyNum int
		var keyPrefix string
		if err := rows.Scan(&s.ID, &keyNum, &keyPrefix, &s.Title, &s.Type, &s.Status, &s.Similarity); err != nil {
			return nil, fmt.Errorf("workspace: scan similar item: %w", err)
		}
		s.Key = keyPrefix + "-" + strconv.Itoa(keyNum)
		out = append(out, s)
	}
	return out, rows.Err()
}

// IsFeatureDocApproved reports a feature's own doc_status — the task
// in_progress doc gate (contract-phase2.md "Doc gate").
func (r *Repo) IsFeatureDocApproved(ctx context.Context, db DBTX, featureItemID string) (bool, error) {
	var status *string
	if err := db.QueryRow(ctx, `SELECT doc_status FROM work_items WHERE id = $1`, featureItemID).Scan(&status); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, ErrNotFound
		}
		return false, fmt.Errorf("workspace: check feature doc status: %w", err)
	}
	return status != nil && *status == DocApproved, nil
}

// HasOpenIncomingBlock reports whether itemID is the target of an
// unresolved `blocks` link from another still-open item.
func (r *Repo) HasOpenIncomingBlock(ctx context.Context, db DBTX, itemID string) (bool, error) {
	var open bool
	if err := db.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM work_item_links l JOIN work_items w ON w.id = l.from_id
		    WHERE l.to_id = $1 AND l.kind = 'blocks' AND w.archived_at IS NULL
		      AND w.status NOT IN ('done','wont_do'))`,
		itemID,
	).Scan(&open); err != nil {
		return false, fmt.Errorf("workspace: check open blockers: %w", err)
	}
	return open, nil
}

// LockMemberRow takes the project_members row lock the WIP check must hold
// across its count and the transition write (01 §4 "WIP limit"). Called with
// a pool connection during a read-only preview (ItemDetail's legal-transition
// scan), the FOR UPDATE lock still runs but releases immediately with that
// single implicit transaction — harmless, and the same code path either way.
func (r *Repo) LockMemberRow(ctx context.Context, db DBTX, projectID, userID string) error {
	var exists bool
	if err := db.QueryRow(ctx,
		`SELECT true FROM project_members WHERE project_id = $1 AND user_id = $2 FOR UPDATE`,
		projectID, userID,
	).Scan(&exists); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("workspace: lock member row: %w", err)
	}
	return nil
}

// planningItem is one row of the caller's assigned-open-items feed — the
// planning board/issues endpoints' own read model (service_planning.go),
// deliberately separate from WorkItem since it carries cross-project display
// fields (project title, owner/creator names) no single-project view needs.
type planningItem struct {
	ID              string
	Key             string
	KeyNum          int
	Type            string
	Title           string
	Description     *string
	Status          string
	Priority        string
	Severity        *string
	DueAt           *time.Time
	EstimateMinutes *int
	CreatedByName   *string
	CreatedAt       time.Time
	UpdatedAt       time.Time
	ProjectTitle    string
	OwnerName       *string
}

// ListAssignedOpenItems returns userID's open (not done/wont_do), non-archived
// work items across every workspace they're an active member of, most
// recently updated first — the planning board/issues feed's one query.
func (r *Repo) ListAssignedOpenItems(ctx context.Context, db DBTX, userID string, limit int) ([]planningItem, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix, w.key_num, w.type, w.title, w.description, w.status, w.priority, w.severity,
		        w.due_at, w.estimate_minutes, cu.name, w.created_at, w.updated_at, p.title, ou.name
		   FROM work_items w
		   JOIN workspace_projects p ON p.id = w.project_id
		   JOIN project_members pm ON pm.project_id = w.project_id AND pm.user_id = $1 AND pm.status = 'active'
		   LEFT JOIN users cu ON cu.id = w.created_by
		   LEFT JOIN work_item_assignees oa ON oa.item_id = w.id AND oa.role = 'owner'
		   LEFT JOIN users ou ON ou.id = oa.user_id
		  WHERE w.archived_at IS NULL AND w.status NOT IN ('done', 'wont_do')
		    AND p.project_status IN ('draft', 'recruiting', 'active', 'paused', 'completed')
		    AND EXISTS (SELECT 1 FROM work_item_assignees a WHERE a.item_id = w.id AND a.user_id = $1)
		  ORDER BY w.updated_at DESC
		  LIMIT $2`,
		userID, limit)
	if err != nil {
		return nil, fmt.Errorf("workspace: list assigned open items: %w", err)
	}
	defer rows.Close()

	out := []planningItem{}
	for rows.Next() {
		var it planningItem
		var keyPrefix string
		if err := rows.Scan(&it.ID, &keyPrefix, &it.KeyNum, &it.Type, &it.Title, &it.Description, &it.Status, &it.Priority,
			&it.Severity, &it.DueAt, &it.EstimateMinutes, &it.CreatedByName, &it.CreatedAt, &it.UpdatedAt, &it.ProjectTitle, &it.OwnerName,
		); err != nil {
			return nil, fmt.Errorf("workspace: scan assigned open item: %w", err)
		}
		it.Key = keyPrefix + "-" + strconv.Itoa(it.KeyNum)
		out = append(out, it)
	}
	return out, rows.Err()
}

// CountOpenExecutionItems counts non-archived items actively in flight
// (in_progress/in_review/testing) — SetProjectStatus's own active→completed
// gate (contract-phase5.md 5b, ErrCompleteBlocked).
func (r *Repo) CountOpenExecutionItems(ctx context.Context, db DBTX, projectID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_items
		  WHERE project_id = $1 AND archived_at IS NULL AND status IN ('in_progress','in_review','testing')`,
		projectID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count open execution items: %w", err)
	}
	return n, nil
}

// CountOwnedInProgress counts userID's owned, non-archived in_progress items
// in a project — the WIP limit's own count.
func (r *Repo) CountOwnedInProgress(ctx context.Context, db DBTX, projectID, userID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_items w
		   JOIN work_item_assignees a ON a.item_id = w.id AND a.role = 'owner' AND a.user_id = $2
		  WHERE w.project_id = $1 AND w.archived_at IS NULL AND w.status = 'in_progress'`,
		projectID, userID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count owned in-progress items: %w", err)
	}
	return n, nil
}

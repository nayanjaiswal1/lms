package sheets

import (
	"context"
	"errors"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the sheets domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound is returned when a sheet or item does not exist, or the
// requesting user does not have the access needed to see or modify it.
var ErrNotFound = errors.New("sheets: not found")

const sheetColumns = `id, name, slug, description, category, is_system, created_by, created_at, updated_at, COALESCE(source_sheet_ids, '{}')`

func scanSheet(row pgx.Row) (Sheet, error) {
	var s Sheet
	err := row.Scan(&s.ID, &s.Name, &s.Slug, &s.Description, &s.Category, &s.IsSystem, &s.CreatedBy, &s.CreatedAt, &s.UpdatedAt, &s.SourceSheetIDs)
	return s, err
}

// ListPublicSheets returns every system-seeded sheet, ordered by name — the
// catalogue a user can "start with".
func (r *Repo) ListPublicSheets(ctx context.Context) ([]Sheet, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT s.id, s.name, s.slug, s.description, s.category, s.is_system, s.created_by,
		        s.created_at, s.updated_at, COALESCE(s.source_sheet_ids, '{}'),
		        COUNT(si.id),
		        COALESCE(array_agg(DISTINCT si.category) FILTER (WHERE si.category IS NOT NULL), '{}')
		 FROM sheets s
		 LEFT JOIN sheet_items si ON si.sheet_id = s.id
		 WHERE s.is_system = true
		 GROUP BY s.id
		 ORDER BY s.name`)
	if err != nil {
		return nil, fmt.Errorf("sheets: list public sheets: %w", err)
	}
	defer rows.Close()

	out := []Sheet{}
	for rows.Next() {
		var s Sheet
		if err := rows.Scan(
			&s.ID, &s.Name, &s.Slug, &s.Description, &s.Category, &s.IsSystem, &s.CreatedBy,
			&s.CreatedAt, &s.UpdatedAt, &s.SourceSheetIDs, &s.ItemCount, &s.Topics,
		); err != nil {
			return nil, fmt.Errorf("sheets: scan public sheet: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// GetSheetBySlug returns one sheet by its slug.
func (r *Repo) GetSheetBySlug(ctx context.Context, slug string) (Sheet, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+sheetColumns+` FROM sheets WHERE slug = $1`, slug)
	s, err := scanSheet(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Sheet{}, ErrNotFound
		}
		return Sheet{}, fmt.Errorf("sheets: get sheet by slug: %w", err)
	}
	return s, nil
}

// UserHasAccess reports whether userID may read a sheet's items: either the
// sheet is system-seeded (public preview), or the user owns/subscribes to it.
func (r *Repo) UserHasAccess(ctx context.Context, userID, sheetID string) (bool, error) {
	var hasAccess bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM sheets
		   WHERE id = $1 AND (
		     is_system = true
		     OR EXISTS(SELECT 1 FROM user_sheets WHERE user_id = $2 AND sheet_id = $1)
		   )
		 )`, sheetID, userID,
	).Scan(&hasAccess)
	if err != nil {
		return false, fmt.Errorf("sheets: check access: %w", err)
	}
	return hasAccess, nil
}

// IsOwner reports whether userID owns sheetID.
func (r *Repo) IsOwner(ctx context.Context, userID, sheetID string) (bool, error) {
	var isOwner bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM user_sheets WHERE user_id = $1 AND sheet_id = $2 AND role = 'owner'
		 )`, userID, sheetID,
	).Scan(&isOwner)
	if err != nil {
		return false, fmt.Errorf("sheets: check owner: %w", err)
	}
	return isOwner, nil
}

// ListItemsWithProgress returns every item in a sheet, joined with userID's
// progress for each item's topic_tag (defaulting to "todo" if never touched).
func (r *Repo) ListItemsWithProgress(ctx context.Context, sheetID, userID string) ([]SheetItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT si.id, si.sheet_id, si.title, si.topic_tag, si.category, si.difficulty,
		        si.external_url, si.order_index, si.created_at,
		        COALESCE(upp.status, 'todo'), upp.solved_at, upp.revision_at
		 FROM sheet_items si
		 LEFT JOIN user_problem_progress upp
		   ON upp.topic_tag = si.topic_tag AND upp.user_id = $2
		 WHERE si.sheet_id = $1
		 ORDER BY si.order_index`, sheetID, userID)
	if err != nil {
		return nil, fmt.Errorf("sheets: list items: %w", err)
	}
	defer rows.Close()

	out := []SheetItem{}
	for rows.Next() {
		var it SheetItem
		if err := rows.Scan(
			&it.ID, &it.SheetID, &it.Title, &it.TopicTag, &it.Category, &it.Difficulty,
			&it.ExternalURL, &it.OrderIndex, &it.CreatedAt,
			&it.Status, &it.SolvedAt, &it.RevisionAt,
		); err != nil {
			return nil, fmt.Errorf("sheets: scan item: %w", err)
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

// CreateSheet inserts a new sheet and registers the creator as its owner in a
// single transaction.
func (r *Repo) CreateSheet(ctx context.Context, userID, slug string, req CreateSheetRequest) (Sheet, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return Sheet{}, fmt.Errorf("sheets: begin create sheet tx: %w", err)
	}
	defer tx.Rollback(ctx)

	row := tx.QueryRow(ctx,
		`INSERT INTO sheets (name, slug, description, category, is_system, created_by)
		 VALUES ($1, $2, $3, $4, false, $5)
		 RETURNING `+sheetColumns,
		req.Name, slug, req.Description, req.Category, userID,
	)
	s, err := scanSheet(row)
	if err != nil {
		return Sheet{}, fmt.Errorf("sheets: insert sheet: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO user_sheets (user_id, sheet_id, role) VALUES ($1, $2, 'owner')`,
		userID, s.ID,
	); err != nil {
		return Sheet{}, fmt.Errorf("sheets: insert owner row: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return Sheet{}, fmt.Errorf("sheets: commit create sheet tx: %w", err)
	}
	return s, nil
}

// CombineSheets creates a new owned sheet whose items are the union of every
// source sheet's items, deduped by topic_tag (first occurrence — in SheetIDs
// order, then by each source's own order_index — wins). Caller must verify
// access to every source sheet first. See docs/sheets.md "Combine".
func (r *Repo) CombineSheets(ctx context.Context, userID, slug string, req CombineSheetsRequest) (Sheet, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return Sheet{}, fmt.Errorf("sheets: begin combine tx: %w", err)
	}
	defer tx.Rollback(ctx)

	rows, err := tx.Query(ctx,
		`SELECT title, topic_tag, category, difficulty, external_url, sheet_id, order_index
		 FROM sheet_items WHERE sheet_id = ANY($1::uuid[])`, req.SheetIDs)
	if err != nil {
		return Sheet{}, fmt.Errorf("sheets: query source items: %w", err)
	}
	type sourceItem struct {
		title, topicTag                   string
		category, difficulty, externalURL *string
		sheetID                            string
		orderIndex                         int
	}
	var all []sourceItem
	for rows.Next() {
		var it sourceItem
		if err := rows.Scan(&it.title, &it.topicTag, &it.category, &it.difficulty, &it.externalURL, &it.sheetID, &it.orderIndex); err != nil {
			rows.Close()
			return Sheet{}, fmt.Errorf("sheets: scan source item: %w", err)
		}
		all = append(all, it)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return Sheet{}, fmt.Errorf("sheets: read source items: %w", err)
	}

	rank := make(map[string]int, len(req.SheetIDs))
	for i, id := range req.SheetIDs {
		rank[id] = i
	}
	sort.SliceStable(all, func(i, j int) bool {
		if ri, rj := rank[all[i].sheetID], rank[all[j].sheetID]; ri != rj {
			return ri < rj
		}
		return all[i].orderIndex < all[j].orderIndex
	})

	excluded := make(map[string]bool, len(req.ExcludeTopicTags))
	for _, t := range req.ExcludeTopicTags {
		excluded[t] = true
	}

	seen := make(map[string]bool, len(all))
	deduped := make([]sourceItem, 0, len(all))
	for _, it := range all {
		if seen[it.topicTag] || excluded[it.topicTag] {
			continue
		}
		seen[it.topicTag] = true
		deduped = append(deduped, it)
	}

	row := tx.QueryRow(ctx,
		`INSERT INTO sheets (name, slug, is_system, created_by, source_sheet_ids)
		 VALUES ($1, $2, false, $3, $4)
		 RETURNING `+sheetColumns,
		req.Name, slug, userID, req.SheetIDs,
	)
	s, err := scanSheet(row)
	if err != nil {
		return Sheet{}, fmt.Errorf("sheets: insert combined sheet: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO user_sheets (user_id, sheet_id, role) VALUES ($1, $2, 'owner')`,
		userID, s.ID,
	); err != nil {
		return Sheet{}, fmt.Errorf("sheets: insert owner row: %w", err)
	}

	for i, it := range deduped {
		if _, err := tx.Exec(ctx,
			`INSERT INTO sheet_items (sheet_id, title, topic_tag, category, difficulty, external_url, order_index)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			s.ID, it.title, it.topicTag, it.category, it.difficulty, it.externalURL, i,
		); err != nil {
			return Sheet{}, fmt.Errorf("sheets: insert combined item: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return Sheet{}, fmt.Errorf("sheets: commit combine tx: %w", err)
	}
	return s, nil
}

// AddItem inserts a new item into sheetID. Caller must verify ownership first.
func (r *Repo) AddItem(ctx context.Context, sheetID, topicTag string, req AddItemRequest) (SheetItem, error) {
	var it SheetItem
	err := r.pool.QueryRow(ctx,
		`INSERT INTO sheet_items (sheet_id, title, topic_tag, category, difficulty, external_url, order_index)
		 SELECT $1, $2, $3, $4, $5, $6, COALESCE(MAX(order_index) + 1, 0)
		 FROM sheet_items WHERE sheet_id = $1
		 RETURNING id, sheet_id, title, topic_tag, category, difficulty, external_url, order_index, created_at`,
		sheetID, req.Title, topicTag, req.Category, req.Difficulty, req.ExternalURL,
	).Scan(&it.ID, &it.SheetID, &it.Title, &it.TopicTag, &it.Category, &it.Difficulty, &it.ExternalURL, &it.OrderIndex, &it.CreatedAt)
	if err != nil {
		return SheetItem{}, fmt.Errorf("sheets: add item: %w", err)
	}
	it.Status = "todo"
	return it, nil
}

// UpdateItem applies a partial update to an item. Caller must verify
// ownership first. Nil fields in req are left unchanged.
func (r *Repo) UpdateItem(ctx context.Context, sheetID, itemID string, req UpdateItemRequest) (SheetItem, error) {
	var it SheetItem
	err := r.pool.QueryRow(ctx,
		`UPDATE sheet_items
		 SET title        = COALESCE($3, title),
		     category     = COALESCE($4, category),
		     difficulty   = COALESCE($5, difficulty),
		     external_url = COALESCE($6, external_url)
		 WHERE id = $1 AND sheet_id = $2
		 RETURNING id, sheet_id, title, topic_tag, category, difficulty, external_url, order_index, created_at`,
		itemID, sheetID, req.Title, req.Category, req.Difficulty, req.ExternalURL,
	).Scan(&it.ID, &it.SheetID, &it.Title, &it.TopicTag, &it.Category, &it.Difficulty, &it.ExternalURL, &it.OrderIndex, &it.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return SheetItem{}, ErrNotFound
		}
		return SheetItem{}, fmt.Errorf("sheets: update item: %w", err)
	}
	return it, nil
}

// DeleteItem removes an item from a sheet. Caller must verify ownership first.
func (r *Repo) DeleteItem(ctx context.Context, sheetID, itemID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM sheet_items WHERE id = $1 AND sheet_id = $2`, itemID, sheetID)
	if err != nil {
		return fmt.Errorf("sheets: delete item: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ListUserSheets returns every sheet the user owns or subscribes to, most
// recently added first — this backs the tab bar.
func (r *Repo) ListUserSheets(ctx context.Context, userID string) ([]UserSheetSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT s.id, s.name, s.slug, s.description, s.category, s.is_system,
		        s.created_by, s.created_at, s.updated_at, us.role, COALESCE(s.source_sheet_ids, '{}'),
		        COUNT(si.id),
		        COALESCE(array_agg(DISTINCT si.category) FILTER (WHERE si.category IS NOT NULL), '{}')
		 FROM user_sheets us
		 JOIN sheets s ON s.id = us.sheet_id
		 LEFT JOIN sheet_items si ON si.sheet_id = s.id
		 WHERE us.user_id = $1
		 GROUP BY s.id, us.role, us.added_at
		 ORDER BY us.added_at`, userID)
	if err != nil {
		return nil, fmt.Errorf("sheets: list user sheets: %w", err)
	}
	defer rows.Close()

	out := []UserSheetSummary{}
	for rows.Next() {
		var u UserSheetSummary
		if err := rows.Scan(
			&u.ID, &u.Name, &u.Slug, &u.Description, &u.Category, &u.IsSystem,
			&u.CreatedBy, &u.CreatedAt, &u.UpdatedAt, &u.Role, &u.SourceSheetIDs,
			&u.ItemCount, &u.Topics,
		); err != nil {
			return nil, fmt.Errorf("sheets: scan user sheet: %w", err)
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// Subscribe pins a sheet (typically a system sheet) as one the user tracks.
func (r *Repo) Subscribe(ctx context.Context, userID, sheetID string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_sheets (user_id, sheet_id, role) VALUES ($1, $2, 'subscriber')
		 ON CONFLICT (user_id, sheet_id) DO NOTHING`, userID, sheetID)
	if err != nil {
		return fmt.Errorf("sheets: subscribe: %w", err)
	}
	return nil
}

// Unsubscribe stops tracking a sheet the user subscribes to (does not affect
// sheets the user owns).
func (r *Repo) Unsubscribe(ctx context.Context, userID, sheetID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM user_sheets WHERE user_id = $1 AND sheet_id = $2 AND role = 'subscriber'`,
		userID, sheetID)
	if err != nil {
		return fmt.Errorf("sheets: unsubscribe: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpsertProgress sets the status for a topic_tag, deriving solved_at and
// revision_at from the transition:
//   - "done"    -> solved_at = now(), revision_at = now() + 7 days
//   - "revisit" -> solved_at unchanged, revision_at = now()
//   - "todo"    -> solved_at and revision_at cleared
func (r *Repo) UpsertProgress(ctx context.Context, userID, topicTag, status string) (SheetItem, error) {
	var it SheetItem
	err := r.pool.QueryRow(ctx,
		`INSERT INTO user_problem_progress (user_id, topic_tag, status, solved_at, revision_at)
		 VALUES (
		   $1, $2, $3,
		   CASE WHEN $3 = 'done' THEN now()
		        WHEN $3 = 'todo' THEN NULL
		        ELSE (SELECT solved_at FROM user_problem_progress WHERE user_id = $1 AND topic_tag = $2)
		   END,
		   CASE WHEN $3 = 'done' THEN now() + interval '7 days'
		        WHEN $3 = 'revisit' THEN now()
		        ELSE NULL
		   END
		 )
		 ON CONFLICT (user_id, topic_tag) DO UPDATE SET
		   status      = EXCLUDED.status,
		   solved_at   = CASE WHEN EXCLUDED.status = 'done' THEN now()
		                      WHEN EXCLUDED.status = 'todo' THEN NULL
		                      ELSE user_problem_progress.solved_at
		                 END,
		   revision_at = CASE WHEN EXCLUDED.status = 'done' THEN now() + interval '7 days'
		                      WHEN EXCLUDED.status = 'revisit' THEN now()
		                      ELSE NULL
		                 END
		 RETURNING topic_tag, status, solved_at, revision_at`,
		userID, topicTag, status,
	).Scan(&it.TopicTag, &it.Status, &it.SolvedAt, &it.RevisionAt)
	if err != nil {
		return SheetItem{}, fmt.Errorf("sheets: upsert progress: %w", err)
	}
	return it, nil
}

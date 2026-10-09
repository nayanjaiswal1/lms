package library

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/pagination"
)

// Repo executes the library domain's own query: the unified search over
// lab_definitions, assessments, and notes-type course_modules. Every other
// operation (Attach's eligibility checks and insert) reuses courses/labs/
// assessment's own repos directly — see Service.
type Repo struct{ pool *pgxpool.Pool }

func NewRepo(pool *pgxpool.Pool) *Repo { return &Repo{pool: pool} }

const defaultListLimit = 30
const maxListLimit = 100

// List returns a cursor-paginated page of library items visible to orgID —
// its own published labs plus platform-shared ones, its own published
// quizzes, and its own notes lessons. No new table: this queries
// lab_definitions, assessments, and course_modules directly (docs/debug-labs.md
// L4).
func (r *Repo) List(ctx context.Context, orgID string, f ListFilter) (ItemPage, error) {
	limit := f.Limit
	if limit <= 0 || limit > maxListLimit {
		limit = defaultListLimit
	}

	var cursorCreatedAt *time.Time
	var cursorID *string
	if f.Cursor != "" {
		t, id, err := pagination.DecodeCursor(f.Cursor, "library")
		if err != nil {
			return ItemPage{}, fmt.Errorf("library.Repo.List: decode cursor: %w", err)
		}
		cursorCreatedAt, cursorID = &t, &id
	}

	var kinds []string
	if len(f.Kinds) > 0 {
		kinds = f.Kinds
	}

	rows, err := r.pool.Query(ctx, `
		SELECT kind, id, title, description, mode, platform, created_at FROM (
			SELECT 'lab' AS kind, id, title, description, 'reference' AS mode,
			       (library_visibility = 'platform' AND org_id <> $1) AS platform, created_at
			FROM lab_definitions
			WHERE is_published = true AND (org_id = $1 OR library_visibility = 'platform')
			UNION ALL
			SELECT 'quiz' AS kind, id, title, description, 'reference' AS mode, false AS platform, created_at
			FROM assessments
			WHERE status = 'published' AND org_id = $1
			UNION ALL
			SELECT 'notes' AS kind, cm.id, cm.title, NULL::text AS description, 'copy' AS mode, false AS platform, cm.created_at
			FROM course_modules cm JOIN courses c ON c.id = cm.course_id
			WHERE cm.type = 'notes' AND cm.deleted_at IS NULL AND c.org_id = $1
		) items
		WHERE ($2::text[] IS NULL OR kind = ANY($2))
		  AND ($3 = '' OR title ILIKE '%' || $3 || '%')
		  AND ($4::timestamptz IS NULL OR (created_at, id) < ($4, $5::uuid))
		ORDER BY created_at DESC, id DESC
		LIMIT $6`,
		orgID, kinds, f.Search, cursorCreatedAt, cursorID, limit+1,
	)
	if err != nil {
		return ItemPage{}, fmt.Errorf("library.Repo.List: %w", err)
	}
	defer rows.Close()

	items := []Item{}
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.Kind, &it.ID, &it.Title, &it.Description, &it.Mode, &it.Platform, &it.CreatedAt); err != nil {
			return ItemPage{}, fmt.Errorf("library.Repo.List: scan: %w", err)
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return ItemPage{}, fmt.Errorf("library.Repo.List: rows: %w", err)
	}

	page := ItemPage{Items: items}
	if len(items) > limit {
		last := items[limit-1]
		page.Items = items[:limit]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

package mistakes

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Create inserts a new mistake event into learning_annotations with annotation_type='mistake'.
func (r *Repo) Create(ctx context.Context, userID string, req LogRequest) (Entry, error) {
	var e Entry
	meta := map[string]interface{}{
		"category":        req.Category,
		"corrected_text":  req.CorrectedText,
	}
	metaBytes, _ := json.Marshal(meta)

	err := r.pool.QueryRow(ctx,
		`INSERT INTO learning_annotations (user_id, source_type, source_id, annotation_type, text, meta, resolved_at)
		 VALUES ($1, 'module', $2, 'mistake', $3, $4::jsonb, NULL)
		 RETURNING id, user_id, text, created_at`,
		userID, req.SourceModuleID, req.OriginalText, metaBytes,
	).Scan(&e.ID, &e.UserID, &e.OriginalText, &e.CreatedAt)
	if err != nil {
		return Entry{}, fmt.Errorf("mistakes: create: %w", err)
	}
	e.Category = req.Category
	e.CorrectedText = req.CorrectedText
	e.SourceModuleID = req.SourceModuleID
	e.Status = StatusNew
	return e, nil
}

// statusDerivationCTE computes each entry's status without a stored,
// recompute-on-write column: "resolved" holds unless a newer entry for the
// same category landed after resolved_at (the mistake came back, so the
// earlier resolution no longer describes the present); the first-ever
// occurrence of a category is "new"; the second is "recurring"; from the
// third occurrence on, "recurring" if the newest gap is <= the one before it
// else "improving". Note: sub_topic is no longer tracked in the new schema.
const statusDerivationCTE = `
	WITH ordered AS (
		SELECT *,
		       (meta->>'category')::text AS category,
		       ROW_NUMBER() OVER (PARTITION BY (meta->>'category') ORDER BY created_at) AS rn,
		       LAG(created_at)    OVER (PARTITION BY (meta->>'category') ORDER BY created_at) AS prev_created_at,
		       LAG(created_at, 2) OVER (PARTITION BY (meta->>'category') ORDER BY created_at) AS prev_prev_created_at
		FROM learning_annotations
		WHERE user_id = $1 AND annotation_type = 'mistake'
	)
	SELECT id, user_id, category, text, (meta->>'corrected_text')::text, source_id, resolved_at, created_at,
	       CASE
	         WHEN resolved_at IS NOT NULL AND NOT EXISTS (
	           SELECT 1 FROM learning_annotations newer
	           WHERE newer.user_id = ordered.user_id AND (newer.meta->>'category')::text = ordered.category
	             AND newer.annotation_type = 'mistake' AND newer.created_at > ordered.resolved_at
	         ) THEN '` + StatusResolved + `'
	         WHEN rn = 1 THEN '` + StatusNew + `'
	         WHEN prev_prev_created_at IS NULL THEN '` + StatusRecurring + `'
	         WHEN (created_at - prev_created_at) <= (prev_created_at - prev_prev_created_at) THEN '` + StatusRecurring + `'
	         ELSE '` + StatusImproving + `'
	       END AS status
	FROM ordered`

// List returns the user's mistake timeline, newest first, optionally
// filtered by category/date range.
func (r *Repo) List(ctx context.Context, userID string, f ListFilter) ([]Entry, error) {
	query := statusDerivationCTE
	args := []any{userID}
	// outerHasWhere tracks the outer SELECT ... FROM ordered clause only — the
	// CTE it's built on top of already contains its own "WHERE user_id = $1",
	// so scanning the accumulated query string for "WHERE" would find that one
	// and wrongly conclude the outer query already has a filter.
	outerHasWhere := false
	addFilter := func(clause string, arg any) {
		args = append(args, arg)
		if outerHasWhere {
			query += fmt.Sprintf(" AND %s $%d", clause, len(args))
		} else {
			query += fmt.Sprintf(" WHERE %s $%d", clause, len(args))
			outerHasWhere = true
		}
	}
	if f.Category != nil {
		addFilter("category =", *f.Category)
	}
	// Note: ContextTag no longer exists in learning_annotations schema; filter removed
	if f.From != nil {
		addFilter("created_at >=", *f.From)
	}
	if f.To != nil {
		addFilter("created_at <=", *f.To)
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("mistakes: list: %w", err)
	}
	defer rows.Close()

	out := []Entry{}
	for rows.Next() {
		var e Entry
		var correctedText *string
		if err := rows.Scan(&e.ID, &e.UserID, &e.Category, &e.OriginalText, &correctedText,
			&e.SourceModuleID, &e.ResolvedAt, &e.CreatedAt, &e.Status); err != nil {
			return nil, fmt.Errorf("mistakes: scan entry: %w", err)
		}
		if correctedText != nil {
			e.CorrectedText = *correctedText
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// Summary aggregates per-category counts and a trailing-window trend in one
// round trip — cheap enough to call on every dashboard load.
func (r *Repo) Summary(ctx context.Context, userID string) ([]CategorySummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT (meta->>'category')::text as category,
		        COUNT(*),
		        MIN(created_at),
		        MAX(created_at),
		        COUNT(*) FILTER (WHERE created_at > now() - interval '7 days') AS recent,
		        COUNT(*) FILTER (WHERE created_at <= now() - interval '7 days' AND created_at > now() - interval '14 days') AS prior
		 FROM learning_annotations
		 WHERE user_id = $1 AND annotation_type = 'mistake'
		 GROUP BY (meta->>'category')::text
		 ORDER BY COUNT(*) DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("mistakes: summary: %w", err)
	}
	defer rows.Close()

	out := []CategorySummary{}
	for rows.Next() {
		var s CategorySummary
		var recent, prior int
		if err := rows.Scan(&s.Category, &s.Total, &s.FirstOccurredAt, &s.LastOccurredAt, &recent, &prior); err != nil {
			return nil, fmt.Errorf("mistakes: scan summary: %w", err)
		}
		switch {
		case recent > prior:
			s.Trend = TrendWorsening
		case recent < prior:
			s.Trend = TrendImproving
		default:
			s.Trend = TrendStable
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// MarkResolved records that the student considers this mistake fixed. It can
// flip back to "recurring" automatically if the same category happens again
// later (see statusDerivationCTE), so this never needs to be undone manually.
func (r *Repo) MarkResolved(ctx context.Context, userID, entryID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE learning_annotations SET resolved_at = now() WHERE id = $1 AND user_id = $2 AND annotation_type = 'mistake'`,
		entryID, userID)
	if err != nil {
		return fmt.Errorf("mistakes: mark resolved: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete removes a mistake annotation. Used by the log_mistake MCP tool's Revert.
func (r *Repo) Delete(ctx context.Context, userID, entryID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM learning_annotations WHERE id = $1 AND user_id = $2 AND annotation_type = 'mistake'`,
		entryID, userID)
	if err != nil {
		return fmt.Errorf("mistakes: delete: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

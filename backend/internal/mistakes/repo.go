package mistakes

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Create inserts a new mistake event.
func (r *Repo) Create(ctx context.Context, userID string, req LogRequest) (Entry, error) {
	var e Entry
	err := r.pool.QueryRow(ctx,
		`INSERT INTO mistake_entries (user_id, category, sub_topic, original_text, corrected_text, context_tag, source_module_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 RETURNING id, user_id, category, sub_topic, original_text, corrected_text, context_tag, source_module_id, resolved_at, created_at`,
		userID, req.Category, req.SubTopic, req.OriginalText, req.CorrectedText, req.ContextTag, req.SourceModuleID,
	).Scan(&e.ID, &e.UserID, &e.Category, &e.SubTopic, &e.OriginalText, &e.CorrectedText, &e.ContextTag, &e.SourceModuleID, &e.ResolvedAt, &e.CreatedAt)
	if err != nil {
		return Entry{}, fmt.Errorf("mistakes: create: %w", err)
	}
	e.Status = StatusNew
	return e, nil
}

// statusDerivationCTE computes each entry's status without a stored,
// recompute-on-write column: "resolved" holds unless a newer entry for the
// same (category, sub_topic) landed after resolved_at (the mistake came
// back, so the earlier resolution no longer describes the present); the
// first-ever occurrence of a topic is "new"; the second is "recurring" (it
// repeated at all, there's no prior gap yet to compare); from the third
// occurrence on, "recurring" if the newest gap is <= the one before it
// (happening at least as often as before) else "improving".
const statusDerivationCTE = `
	WITH ordered AS (
		SELECT *,
		       ROW_NUMBER() OVER (PARTITION BY category, sub_topic ORDER BY created_at) AS rn,
		       LAG(created_at)    OVER (PARTITION BY category, sub_topic ORDER BY created_at) AS prev_created_at,
		       LAG(created_at, 2) OVER (PARTITION BY category, sub_topic ORDER BY created_at) AS prev_prev_created_at
		FROM mistake_entries
		WHERE user_id = $1
	)
	SELECT id, user_id, category, sub_topic, original_text, corrected_text, context_tag, source_module_id, resolved_at, created_at,
	       CASE
	         WHEN resolved_at IS NOT NULL AND NOT EXISTS (
	           SELECT 1 FROM mistake_entries newer
	           WHERE newer.user_id = ordered.user_id AND newer.category = ordered.category
	             AND newer.sub_topic = ordered.sub_topic AND newer.created_at > ordered.resolved_at
	         ) THEN '` + StatusResolved + `'
	         WHEN rn = 1 THEN '` + StatusNew + `'
	         WHEN prev_prev_created_at IS NULL THEN '` + StatusRecurring + `'
	         WHEN (created_at - prev_created_at) <= (prev_created_at - prev_prev_created_at) THEN '` + StatusRecurring + `'
	         ELSE '` + StatusImproving + `'
	       END AS status
	FROM ordered`

// List returns the user's mistake timeline, newest first, optionally
// filtered by category/context_tag/date range.
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
	if f.ContextTag != nil {
		addFilter("context_tag =", *f.ContextTag)
	}
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
		if err := rows.Scan(&e.ID, &e.UserID, &e.Category, &e.SubTopic, &e.OriginalText, &e.CorrectedText,
			&e.ContextTag, &e.SourceModuleID, &e.ResolvedAt, &e.CreatedAt, &e.Status); err != nil {
			return nil, fmt.Errorf("mistakes: scan entry: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// Summary aggregates per-category counts and a trailing-window trend in one
// round trip — cheap enough to call on every dashboard load without a
// cached/materialized table, since a single learner's ledger is at most a
// few thousand rows and idx_mistake_entries_user_created makes this an
// index-only scan.
func (r *Repo) Summary(ctx context.Context, userID string) ([]CategorySummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT category,
		        COUNT(*),
		        MIN(created_at),
		        MAX(created_at),
		        COUNT(*) FILTER (WHERE created_at > now() - interval '7 days') AS recent,
		        COUNT(*) FILTER (WHERE created_at <= now() - interval '7 days' AND created_at > now() - interval '14 days') AS prior
		 FROM mistake_entries
		 WHERE user_id = $1
		 GROUP BY category
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

// MarkResolved records that the student (or their AI, on the student's
// confirmation) considers this mistake fixed. It can flip back to
// "recurring" automatically — see statusDerivationCTE — if the same
// category/sub_topic happens again later, so this never needs to be undone
// manually.
func (r *Repo) MarkResolved(ctx context.Context, userID, entryID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE mistake_entries SET resolved_at = now() WHERE id = $1 AND user_id = $2`,
		entryID, userID)
	if err != nil {
		return fmt.Errorf("mistakes: mark resolved: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete removes a mistake entry (and, via ON DELETE CASCADE, its linked SRS
// card). Used by the log_mistake MCP tool's Revert.
func (r *Repo) Delete(ctx context.Context, userID, entryID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM mistake_entries WHERE id = $1 AND user_id = $2`, entryID, userID)
	if err != nil {
		return fmt.Errorf("mistakes: delete: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

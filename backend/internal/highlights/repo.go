package highlights

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("highlights: not found")
	ErrNotOwner = errors.New("highlights: not owner")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

func (r *Repo) Create(ctx context.Context, userID, textHash string, req CreateRequest) (Highlight, error) {
	var h Highlight
	err := r.pool.QueryRow(ctx,
		`INSERT INTO highlights
		   (user_id, source_type, source_id, selected_text, text_hash,
		    position_start, position_end, context_snippet, source_url, saved_for_revision)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 RETURNING id, user_id, source_type, source_id, selected_text, text_hash,
		           position_start, position_end, context_snippet, source_url,
		           source_orphaned, saved_for_revision, created_at, updated_at`,
		userID, req.SourceType, req.SourceID, req.SelectedText, textHash,
		req.PositionStart, req.PositionEnd, req.ContextSnippet, req.SourceURL, req.SaveForRevision,
	).Scan(
		&h.ID, &h.UserID, &h.SourceType, &h.SourceID, &h.SelectedText, &h.TextHash,
		&h.PositionStart, &h.PositionEnd, &h.ContextSnippet, &h.SourceURL,
		&h.SourceOrphaned, &h.SavedForRevision, &h.CreatedAt, &h.UpdatedAt,
	)
	if err != nil {
		return Highlight{}, fmt.Errorf("highlights: create: %w", err)
	}
	return h, nil
}

// OrphanBySource marks all highlights for a deleted source as orphaned.
// Called by other domains (wiki, courses, problems) when they delete content.
// The highlights themselves are preserved — the student's context and explanation
// remain readable — but source_orphaned = true removes the navigation link.
func (r *Repo) OrphanBySource(ctx context.Context, sourceType, sourceID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE highlights
		 SET source_orphaned = TRUE, updated_at = now()
		 WHERE source_type = $1 AND source_id = $2 AND source_orphaned = FALSE`,
		sourceType, sourceID)
	if err != nil {
		return fmt.Errorf("highlights: orphan by source: %w", err)
	}
	return nil
}

// GetExplanationByHash looks up the shared explanation cache for the given hash.
// Returns (explanation, true, nil) on hit, (zero, false, nil) on miss.
func (r *Repo) GetExplanationByHash(ctx context.Context, textHash string) (Explanation, bool, error) {
	var e Explanation
	err := r.pool.QueryRow(ctx,
		`SELECT id, text_hash, selected_text, source_type, explanation, model_used, serve_count, created_at, updated_at
		 FROM highlight_explanations WHERE text_hash = $1`, textHash,
	).Scan(
		&e.ID, &e.TextHash, &e.SelectedText, &e.SourceType, &e.Explanation,
		&e.ModelUsed, &e.ServeCount, &e.CreatedAt, &e.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Explanation{}, false, nil
		}
		return Explanation{}, false, fmt.Errorf("highlights: get explanation by hash: %w", err)
	}
	return e, true, nil
}

// IncrementServeCount bumps the serve_count for a cache hit — this is the
// token-savings counter used by the analytics endpoint.
func (r *Repo) IncrementServeCount(ctx context.Context, textHash string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE highlight_explanations
		 SET serve_count = serve_count + 1, updated_at = now()
		 WHERE text_hash = $1`, textHash)
	if err != nil {
		return fmt.Errorf("highlights: increment serve count: %w", err)
	}
	return nil
}

// InsertExplanation stores a freshly generated explanation.
// ON CONFLICT handles the race where two simultaneous cache misses both call the LLM;
// the loser's INSERT updates serve_count instead of creating a duplicate row.
func (r *Repo) InsertExplanation(ctx context.Context, textHash, selectedText, sourceType, explanation, modelUsed string) (Explanation, error) {
	var e Explanation
	err := r.pool.QueryRow(ctx,
		`INSERT INTO highlight_explanations
		   (text_hash, selected_text, source_type, explanation, model_used, serve_count)
		 VALUES ($1, $2, $3, $4, $5, 1)
		 ON CONFLICT (text_hash) DO UPDATE
		   SET serve_count = highlight_explanations.serve_count + 1,
		       updated_at  = now()
		 RETURNING id, text_hash, selected_text, source_type, explanation, model_used, serve_count, created_at, updated_at`,
		textHash, selectedText, sourceType, explanation, modelUsed,
	).Scan(
		&e.ID, &e.TextHash, &e.SelectedText, &e.SourceType, &e.Explanation,
		&e.ModelUsed, &e.ServeCount, &e.CreatedAt, &e.UpdatedAt,
	)
	if err != nil {
		return Explanation{}, fmt.Errorf("highlights: insert explanation: %w", err)
	}
	return e, nil
}

// ToggleRevision updates the saved_for_revision flag on a user-owned highlight.
// Returns ErrNotFound when the highlight does not exist or belongs to another user.
func (r *Repo) ToggleRevision(ctx context.Context, highlightID, userID string, save bool) (Highlight, error) {
	var h Highlight
	err := r.pool.QueryRow(ctx,
		`UPDATE highlights
		 SET saved_for_revision = $1, updated_at = now()
		 WHERE id = $2 AND user_id = $3
		 RETURNING id, user_id, source_type, source_id, selected_text, text_hash,
		           position_start, position_end, context_snippet, source_url,
		           source_orphaned, saved_for_revision, created_at, updated_at`,
		save, highlightID, userID,
	).Scan(
		&h.ID, &h.UserID, &h.SourceType, &h.SourceID, &h.SelectedText, &h.TextHash,
		&h.PositionStart, &h.PositionEnd, &h.ContextSnippet, &h.SourceURL,
		&h.SourceOrphaned, &h.SavedForRevision, &h.CreatedAt, &h.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Highlight{}, ErrNotFound
		}
		return Highlight{}, fmt.Errorf("highlights: toggle revision: %w", err)
	}
	return h, nil
}

// ListByUser returns all highlights for a user, newest first.
// When savedOnly is true, only revision-saved highlights are returned.
func (r *Repo) ListByUser(ctx context.Context, userID string, savedOnly bool) ([]Highlight, error) {
	query := `SELECT id, user_id, source_type, source_id, selected_text, text_hash,
	                 position_start, position_end, context_snippet, source_url,
	                 source_orphaned, saved_for_revision, created_at, updated_at
	          FROM highlights WHERE user_id = $1`
	if savedOnly {
		query += ` AND saved_for_revision = TRUE`
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("highlights: list by user: %w", err)
	}
	defer rows.Close()

	out := []Highlight{}
	for rows.Next() {
		var h Highlight
		if err := rows.Scan(
			&h.ID, &h.UserID, &h.SourceType, &h.SourceID, &h.SelectedText, &h.TextHash,
			&h.PositionStart, &h.PositionEnd, &h.ContextSnippet, &h.SourceURL,
			&h.SourceOrphaned, &h.SavedForRevision, &h.CreatedAt, &h.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("highlights: scan highlight: %w", err)
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

// ListBySource returns a user's highlights for a specific content resource,
// newest first, with the cached explanation LEFT JOINed in where available.
func (r *Repo) ListBySource(ctx context.Context, userID, sourceType, sourceID string) ([]Highlight, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT h.id, h.user_id, h.source_type, h.source_id, h.selected_text, h.text_hash,
		        h.position_start, h.position_end, h.context_snippet, h.source_url,
		        h.source_orphaned, h.saved_for_revision, h.created_at, h.updated_at,
		        he.id, he.text_hash, he.selected_text, he.source_type, he.explanation,
		        he.model_used, he.serve_count, he.created_at, he.updated_at
		 FROM highlights h
		 LEFT JOIN highlight_explanations he ON he.text_hash = h.text_hash
		 WHERE h.user_id = $1 AND h.source_type = $2 AND h.source_id = $3
		 ORDER BY h.created_at DESC`,
		userID, sourceType, sourceID)
	if err != nil {
		return nil, fmt.Errorf("highlights: list by source: %w", err)
	}
	defer rows.Close()

	out := []Highlight{}
	for rows.Next() {
		var h Highlight
		var e Explanation
		var (
			eID, eHash, eText, eSrcType, eExpl, eModel *string
			eServe                                      *int
			eCreatedAt, eUpdatedAt                      *time.Time
		)
		if err := rows.Scan(
			&h.ID, &h.UserID, &h.SourceType, &h.SourceID, &h.SelectedText, &h.TextHash,
			&h.PositionStart, &h.PositionEnd, &h.ContextSnippet, &h.SourceURL,
			&h.SourceOrphaned, &h.SavedForRevision, &h.CreatedAt, &h.UpdatedAt,
			&eID, &eHash, &eText, &eSrcType, &eExpl, &eModel, &eServe, &eCreatedAt, &eUpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("highlights: scan list by source: %w", err)
		}
		if eID != nil {
			e.ID = *eID
			e.TextHash = *eHash
			e.SelectedText = *eText
			e.SourceType = *eSrcType
			e.Explanation = *eExpl
			e.ModelUsed = *eModel
			e.ServeCount = *eServe
			e.CreatedAt = *eCreatedAt
			e.UpdatedAt = *eUpdatedAt
			h.Explanation = &e
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

// TopExplanations returns the most-served cached explanations for the analytics dashboard.
func (r *Repo) TopExplanations(ctx context.Context, limit int) ([]AnalyticsEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT text_hash, selected_text, source_type, serve_count, model_used, created_at
		 FROM highlight_explanations
		 ORDER BY serve_count DESC
		 LIMIT $1`, limit)
	if err != nil {
		return nil, fmt.Errorf("highlights: top explanations: %w", err)
	}
	defer rows.Close()

	out := []AnalyticsEntry{}
	for rows.Next() {
		var e AnalyticsEntry
		if err := rows.Scan(&e.TextHash, &e.SelectedText, &e.SourceType, &e.ServeCount, &e.ModelUsed, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("highlights: scan analytics entry: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

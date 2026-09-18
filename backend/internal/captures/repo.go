package captures

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the captures domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound is returned when a capture does not exist, or belongs to a
// different user than the one asking.
var ErrNotFound = errors.New("captures: not found")

// captureMatchThreshold mirrors journal.journalMatchThreshold — the same
// pg_trgm similarity bet, applied to the AI-generated question front instead
// of a journal title.
const captureMatchThreshold = 0.3

const similarMatchesLimit = 5

const captureColumns = `id, user_id, type, storage_key, source_url, status, extracted_text,
	kind, category, subcategory, title, content, journal_entry_id, srs_card_id,
	error_message, created_at, processed_at`

type scanner interface {
	Scan(dest ...any) error
}

func scanCapture(row scanner) (Capture, error) {
	var c Capture
	err := row.Scan(
		&c.ID, &c.UserID, &c.Type, &c.StorageKey, &c.SourceURL, &c.Status, &c.ExtractedText,
		&c.Kind, &c.Category, &c.Subcategory, &c.Title, &c.Content, &c.JournalEntryID, &c.SRSCardID,
		&c.ErrorMessage, &c.CreatedAt, &c.ProcessedAt,
	)
	if err != nil {
		return Capture{}, err
	}
	return c, nil
}

// CreateUploadCapture inserts a pending image/pdf capture already stored at
// storageKey (see storage.StorageClient.Upload — the handler uploads before
// this is called, so a failed insert never orphans an object it can't clean
// up here).
func (r *Repo) CreateUploadCapture(ctx context.Context, userID, captureType, storageKey string) (Capture, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO captures (user_id, type, storage_key, status)
		 VALUES ($1, $2, $3, $4)
		 RETURNING `+captureColumns,
		userID, captureType, storageKey, StatusPending,
	)
	c, err := scanCapture(row)
	if err != nil {
		return Capture{}, fmt.Errorf("captures: create upload capture: %w", err)
	}
	return c, nil
}

// CreateLinkCapture inserts a pending link capture.
func (r *Repo) CreateLinkCapture(ctx context.Context, userID, url string) (Capture, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO captures (user_id, type, source_url, status)
		 VALUES ($1, $2, $3, $4)
		 RETURNING `+captureColumns,
		userID, TypeLink, url, StatusPending,
	)
	c, err := scanCapture(row)
	if err != nil {
		return Capture{}, fmt.Errorf("captures: create link capture: %w", err)
	}
	return c, nil
}

// CreateHTMLCapture inserts a pending html capture with its text already
// extracted (extractHTML is pure CPU — no network fetch needed at all, so
// there's nothing left for the async job to do at the extract stage; see
// Processor.extract's TypeHTML case).
func (r *Repo) CreateHTMLCapture(ctx context.Context, userID, extractedText string) (Capture, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO captures (user_id, type, extracted_text, status)
		 VALUES ($1, $2, $3, $4)
		 RETURNING `+captureColumns,
		userID, TypeHTML, extractedText, StatusPending,
	)
	c, err := scanCapture(row)
	if err != nil {
		return Capture{}, fmt.Errorf("captures: create html capture: %w", err)
	}
	return c, nil
}

// GetCapture returns one capture — ownership is baked into the WHERE clause,
// same pattern as journal.Repo.GetEntry.
func (r *Repo) GetCapture(ctx context.Context, userID, id string) (Capture, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+captureColumns+` FROM captures WHERE id = $1 AND user_id = $2`, id, userID)
	c, err := scanCapture(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Capture{}, ErrNotFound
		}
		return Capture{}, fmt.Errorf("captures: get capture: %w", err)
	}
	return c, nil
}

// GetCaptureByID returns one capture regardless of owner — used by the async
// job, which runs with no authenticated caller and must still know who to
// scope the AI structuring/dedup step to.
func (r *Repo) GetCaptureByID(ctx context.Context, id string) (Capture, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+captureColumns+` FROM captures WHERE id = $1`, id)
	c, err := scanCapture(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Capture{}, ErrNotFound
		}
		return Capture{}, fmt.Errorf("captures: get capture by id: %w", err)
	}
	return c, nil
}

// ListCaptures returns userID's captures, newest first, optionally narrowed
// to one status — the inbox view.
func (r *Repo) ListCaptures(ctx context.Context, userID string, filter ListFilter) ([]Capture, error) {
	query := `SELECT ` + captureColumns + ` FROM captures WHERE user_id = $1`
	args := []any{userID}
	if filter.Status != "" {
		args = append(args, filter.Status)
		query += fmt.Sprintf(" AND status = $%d", len(args))
	}
	limit := filter.Limit
	if limit <= 0 || limit > MaxListLimit {
		limit = DefaultListLimit
	}
	args = append(args, limit)
	query += fmt.Sprintf(" ORDER BY created_at DESC LIMIT $%d", len(args))

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("captures: list captures: %w", err)
	}
	defer rows.Close()

	out := []Capture{}
	for rows.Next() {
		c, err := scanCapture(rows)
		if err != nil {
			return nil, fmt.Errorf("captures: scan capture: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// MarkProcessing flips a pending (or previously failed, on retry) capture to
// processing right before the job starts extraction — so a concurrent
// duplicate job run (two workers claiming the same retried job) can tell via
// RowsAffected == 0 that another worker already picked it up.
func (r *Repo) MarkProcessing(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE captures SET status = $2 WHERE id = $1 AND status IN ($3, $4)`,
		id, StatusProcessing, StatusPending, StatusFailed,
	)
	if err != nil {
		return false, fmt.Errorf("captures: mark processing: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// MarkReady stores the extracted text and the AI's structuring output,
// flipping the capture to ready for review.
func (r *Repo) MarkReady(ctx context.Context, id, extractedText string, s StructuredSuggestion) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE captures
		 SET status = $2, extracted_text = $3, kind = $4, category = $5, subcategory = $6,
		     title = $7, content = $8, processed_at = now()
		 WHERE id = $1`,
		id, StatusReady, extractedText, s.Kind, nullIfEmpty(s.Category), nullIfEmpty(s.Subcategory), s.Title, s.Content,
	)
	if err != nil {
		return fmt.Errorf("captures: mark ready: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// MarkFailed records why extraction/structuring failed, so the inbox can
// show a retryable error instead of leaving the capture silently stuck in
// "processing" forever.
func (r *Repo) MarkFailed(ctx context.Context, id, errMessage string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE captures SET status = $2, error_message = $3, processed_at = now() WHERE id = $1`,
		id, StatusFailed, errMessage,
	)
	if err != nil {
		return fmt.Errorf("captures: mark failed: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// LinkPromoted records which journal entry or SRS card this capture was
// promoted into (exactly one of the two IDs is non-empty) and moves it to
// the promoted terminal state.
func (r *Repo) LinkPromoted(ctx context.Context, userID, id, journalEntryID, srsCardID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE captures SET status = $3, journal_entry_id = NULLIF($4, ''), srs_card_id = NULLIF($5, '')
		 WHERE id = $1 AND user_id = $2`,
		id, userID, StatusPromoted, journalEntryID, srsCardID,
	)
	if err != nil {
		return fmt.Errorf("captures: link promoted: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Dismiss marks a capture as reviewed-and-skipped — it stays visible in the
// inbox under the dismissed filter rather than being deleted, so nothing a
// user captured just disappears without a trace.
func (r *Repo) Dismiss(ctx context.Context, userID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE captures SET status = $3 WHERE id = $1 AND user_id = $2`,
		id, userID, StatusDismissed,
	)
	if err != nil {
		return fmt.Errorf("captures: dismiss: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// FindSimilarQuestionCards returns userID's own capture-sourced SRS cards
// whose front clears captureMatchThreshold against front, closest match
// first — the "question" branch's equivalent of
// journal.Repo.FindSimilarEntries.
func (r *Repo) FindSimilarQuestionCards(ctx context.Context, userID, front string) ([]SimilarMatch, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, front FROM srs_cards
		 WHERE user_id = $1 AND source_type = 'capture' AND similarity(front, $2) > $3
		 ORDER BY similarity(front, $2) DESC LIMIT $4`,
		userID, front, captureMatchThreshold, similarMatchesLimit,
	)
	if err != nil {
		return nil, fmt.Errorf("captures: find similar question cards: %w", err)
	}
	defer rows.Close()

	out := []SimilarMatch{}
	for rows.Next() {
		var m SimilarMatch
		if err := rows.Scan(&m.ID, &m.Title); err != nil {
			return nil, fmt.Errorf("captures: scan similar card: %w", err)
		}
		m.Type = "srs_card"
		out = append(out, m)
	}
	return out, rows.Err()
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

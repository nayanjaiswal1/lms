package diary

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the diary domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound is returned when an entry does not exist, or belongs to a
// different user than the one asking.
var ErrNotFound = errors.New("diary: not found")

const entryColumns = `id, user_id, entry_date, content, ai_analysis, analyzed_hash, analyzed_at, created_at, updated_at`

// scanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query).
type scanner interface {
	Scan(dest ...any) error
}

func scanEntry(row scanner) (Entry, error) {
	var e Entry
	var entryDate time.Time
	var aiRaw []byte
	var analyzedHash *string
	err := row.Scan(&e.ID, &e.UserID, &entryDate, &e.Content, &aiRaw, &analyzedHash, &e.AnalyzedAt, &e.CreatedAt, &e.UpdatedAt)
	if err != nil {
		return Entry{}, err
	}
	e.EntryDate = entryDate.Format("2006-01-02")
	if analyzedHash != nil {
		e.AnalyzedHash = *analyzedHash
	}
	e.Highlights = []Highlight{}
	if len(aiRaw) > 0 {
		var a aiAnalysis
		if err := json.Unmarshal(aiRaw, &a); err == nil && a.Highlights != nil {
			e.Highlights = a.Highlights
		}
	}
	return e, nil
}

// ContentHash is the dedup key used to skip re-analysis of unchanged
// content — sha256 is overkill for collision resistance here, but it's
// already an import-free stdlib call and the exact same "did this content
// change" hash used elsewhere in the codebase (e.g. idempotency keys).
func ContentHash(content string) string {
	sum := sha256.Sum256([]byte(content))
	return hex.EncodeToString(sum[:])
}

// GetOrCreateByDate returns userID's entry for entryDate, creating an empty
// one if it doesn't exist yet. entryDate must already be "2006-01-02".
func (r *Repo) GetOrCreateByDate(ctx context.Context, userID, entryDate string) (Entry, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO diary_entries (user_id, entry_date)
		 VALUES ($1, $2::date)
		 ON CONFLICT (user_id, entry_date) DO NOTHING
		 RETURNING `+entryColumns,
		userID, entryDate,
	)
	e, err := scanEntry(row)
	if err == nil {
		return e, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return Entry{}, fmt.Errorf("diary: get or create by date: insert: %w", err)
	}

	// The row already existed (ON CONFLICT DO NOTHING returned no row) — fetch it.
	row = r.pool.QueryRow(ctx,
		`SELECT `+entryColumns+` FROM diary_entries WHERE user_id = $1 AND entry_date = $2::date`,
		userID, entryDate,
	)
	e, err = scanEntry(row)
	if err != nil {
		return Entry{}, fmt.Errorf("diary: get or create by date: select: %w", err)
	}
	return e, nil
}

// GetByDate returns userID's entry for entryDate, or ErrNotFound.
func (r *Repo) GetByDate(ctx context.Context, userID, entryDate string) (Entry, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+entryColumns+` FROM diary_entries WHERE user_id = $1 AND entry_date = $2::date`,
		userID, entryDate,
	)
	e, err := scanEntry(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, ErrNotFound
		}
		return Entry{}, fmt.Errorf("diary: get by date: %w", err)
	}
	return e, nil
}

// UpdateContent overwrites id's content. Ownership is enforced by the WHERE
// clause.
func (r *Repo) UpdateContent(ctx context.Context, userID, id, content string) (Entry, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE diary_entries SET content = $3, updated_at = now()
		 WHERE id = $1 AND user_id = $2
		 RETURNING `+entryColumns,
		id, userID, content,
	)
	e, err := scanEntry(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, ErrNotFound
		}
		return Entry{}, fmt.Errorf("diary: update content: %w", err)
	}
	return e, nil
}

// SaveAnalysis persists the resolved highlight list and the content hash
// they were computed from, and stamps analyzed_at — called by Service.Apply
// once habit/whatnow mutations have already been applied.
func (r *Repo) SaveAnalysis(ctx context.Context, id string, highlights []Highlight, hash string) error {
	if highlights == nil {
		highlights = []Highlight{}
	}
	raw, err := json.Marshal(aiAnalysis{Highlights: highlights})
	if err != nil {
		return fmt.Errorf("diary: marshal analysis: %w", err)
	}
	tag, err := r.pool.Exec(ctx,
		`UPDATE diary_entries SET ai_analysis = $2, analyzed_hash = $3, analyzed_at = now() WHERE id = $1`,
		id, raw, hash,
	)
	if err != nil {
		return fmt.Errorf("diary: save analysis: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

const defaultListLimit = 30
const maxListLimit = 100

// ListEntries returns a page of userID's entry previews, newest day first,
// optionally narrowed to [from, to] and paginated by an entry_date cursor
// (the last page's oldest entry_date — strictly less-than, so a day with
// exactly one entry per user never repeats across pages).
func (r *Repo) ListEntries(ctx context.Context, userID, from, to, cursor string, limit int) ([]EntryPreview, error) {
	if limit <= 0 || limit > maxListLimit {
		limit = defaultListLimit
	}
	query := `SELECT id, entry_date, content FROM diary_entries WHERE user_id = $1`
	args := []any{userID}
	if from != "" {
		args = append(args, from)
		query += fmt.Sprintf(" AND entry_date >= $%d::date", len(args))
	}
	if to != "" {
		args = append(args, to)
		query += fmt.Sprintf(" AND entry_date <= $%d::date", len(args))
	}
	if cursor != "" {
		args = append(args, cursor)
		query += fmt.Sprintf(" AND entry_date < $%d::date", len(args))
	}
	args = append(args, limit)
	query += fmt.Sprintf(" ORDER BY entry_date DESC LIMIT $%d", len(args))

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("diary: list entries: %w", err)
	}
	defer rows.Close()

	out := []EntryPreview{}
	for rows.Next() {
		var id, content string
		var entryDate time.Time
		if err := rows.Scan(&id, &entryDate, &content); err != nil {
			return nil, fmt.Errorf("diary: scan entry preview: %w", err)
		}
		out = append(out, EntryPreview{ID: id, EntryDate: entryDate.Format("2006-01-02"), Preview: previewOf(content)})
	}
	return out, rows.Err()
}

// previewOf truncates content to previewLength runes for the history list,
// so a long entry doesn't bloat the list payload.
func previewOf(content string) string {
	r := []rune(content)
	if len(r) <= previewLength {
		return content
	}
	return string(r[:previewLength]) + "…"
}

const taskColumns = `id, title, kind, tags, done, source_entry_id, created_at, updated_at`

func scanTask(row scanner) (Task, error) {
	var t Task
	if err := row.Scan(&t.ID, &t.Title, &t.Kind, &t.Tags, &t.Done, &t.SourceEntryID, &t.CreatedAt, &t.UpdatedAt); err != nil {
		return Task{}, err
	}
	return t, nil
}

// ListTasks returns userID's diary tasks, newest first, optionally narrowed
// by tag (array-contains) and/or done state.
func (r *Repo) ListTasks(ctx context.Context, userID, tag string, done *bool) ([]Task, error) {
	query := `SELECT ` + taskColumns + ` FROM diary_tasks WHERE user_id = $1`
	args := []any{userID}
	if tag != "" {
		args = append(args, tag)
		query += fmt.Sprintf(" AND $%d = ANY(tags)", len(args))
	}
	if done != nil {
		args = append(args, *done)
		query += fmt.Sprintf(" AND done = $%d", len(args))
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("diary: list tasks: %w", err)
	}
	defer rows.Close()

	out := []Task{}
	for rows.Next() {
		t, err := scanTask(rows)
		if err != nil {
			return nil, fmt.Errorf("diary: scan task: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListOpenTasks returns userID's not-yet-done diary tasks — the closed
// vocabulary Service.vocabulary resolves "task_done" highlights against.
func (r *Repo) ListOpenTasks(ctx context.Context, userID string) ([]Task, error) {
	done := false
	return r.ListTasks(ctx, userID, "", &done)
}

// CreateTask inserts a new diary task. sourceEntryID is nil for a
// manually-created task, or the diary entry whose text an AI Apply pass
// captured it from.
func (r *Repo) CreateTask(ctx context.Context, userID, title, kind string, sourceEntryID *string, tags []string) (Task, error) {
	if tags == nil {
		tags = []string{}
	}
	row := r.pool.QueryRow(ctx,
		`INSERT INTO diary_tasks (user_id, title, kind, tags, source_entry_id)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING `+taskColumns,
		userID, title, kind, tags, sourceEntryID,
	)
	t, err := scanTask(row)
	if err != nil {
		return Task{}, fmt.Errorf("diary: create task: %w", err)
	}
	return t, nil
}

// SetTaskDone updates id's done state. Ownership is enforced by the WHERE
// clause.
func (r *Repo) SetTaskDone(ctx context.Context, userID, id string, done bool) (Task, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE diary_tasks SET done = $3, updated_at = now()
		 WHERE id = $1 AND user_id = $2
		 RETURNING `+taskColumns,
		id, userID, done,
	)
	t, err := scanTask(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Task{}, ErrNotFound
		}
		return Task{}, fmt.Errorf("diary: set task done: %w", err)
	}
	return t, nil
}

// UpdateTask partially updates id's title/tags. Nil fields are left
// unchanged. Ownership is enforced by the WHERE clause.
func (r *Repo) UpdateTask(ctx context.Context, userID, id string, title *string, tags []string) (Task, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE diary_tasks SET
		   title = COALESCE($3, title),
		   tags = COALESCE($4, tags),
		   updated_at = now()
		 WHERE id = $1 AND user_id = $2
		 RETURNING `+taskColumns,
		id, userID, title, tags,
	)
	t, err := scanTask(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Task{}, ErrNotFound
		}
		return Task{}, fmt.Errorf("diary: update task: %w", err)
	}
	return t, nil
}

// DeleteTask removes id. Ownership is enforced by the WHERE clause.
func (r *Repo) DeleteTask(ctx context.Context, userID, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM diary_tasks WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("diary: delete task: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

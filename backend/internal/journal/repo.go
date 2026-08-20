package journal

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the learning journal domain.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// ErrNotFound is returned when an entry does not exist, or belongs to a
// different user than the one asking.
var ErrNotFound = errors.New("journal: not found")

// journalMatchThreshold — the minimum pg_trgm similarity score trusted
// before surfacing two entry titles as "about the same thing," mirroring
// courses.selfContentMatchThreshold (internal/courses/repo.go).
const journalMatchThreshold = 0.3

const similarEntriesLimit = 5

const entryColumns = `id, user_id, entry_date, category, subcategory, title, content, created_at, updated_at`

// scanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query), so
// scanEntry works for either without duplicating the Scan call shape.
type scanner interface {
	Scan(dest ...any) error
}

func scanEntry(row scanner) (Entry, error) {
	var e Entry
	var entryDate time.Time
	err := row.Scan(&e.ID, &e.UserID, &entryDate, &e.Category, &e.Subcategory, &e.Title, &e.Content, &e.CreatedAt, &e.UpdatedAt)
	if err != nil {
		return Entry{}, err
	}
	e.EntryDate = entryDate.Format("2006-01-02")
	e.Source = "journal"
	return e, nil
}

// ListEntries returns userID's entries, newest day first, optionally
// narrowed by exact category match and/or a title/content substring search.
func (r *Repo) ListEntries(ctx context.Context, userID string, filter ListEntriesFilter) ([]Entry, error) {
	query := `SELECT ` + entryColumns + ` FROM learning_journal_entries WHERE user_id = $1`
	args := []any{userID}
	if filter.Category != "" {
		args = append(args, filter.Category)
		query += fmt.Sprintf(" AND category = $%d", len(args))
	}
	if filter.Subcategory != "" {
		args = append(args, filter.Subcategory)
		query += fmt.Sprintf(" AND subcategory = $%d", len(args))
	}
	if filter.Search != "" {
		args = append(args, "%"+filter.Search+"%")
		query += fmt.Sprintf(" AND (title ILIKE $%d OR content ILIKE $%d)", len(args), len(args))
	}
	query += " ORDER BY entry_date DESC, created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("journal: list entries: %w", err)
	}
	defer rows.Close()

	out := []Entry{}
	for rows.Next() {
		e, err := scanEntry(rows)
		if err != nil {
			return nil, fmt.Errorf("journal: scan entry: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ListCategories returns the distinct category -> subcategories tree userID
// has used, backing the frontend's nested filter chips. Rows come back
// ordered by category then subcategory, so a single pass groups them without
// a second query.
func (r *Repo) ListCategories(ctx context.Context, userID string) ([]CategoryNode, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT category, subcategory FROM learning_journal_entries
		 WHERE user_id = $1 ORDER BY category, subcategory`, userID)
	if err != nil {
		return nil, fmt.Errorf("journal: list categories: %w", err)
	}
	defer rows.Close()

	out := []CategoryNode{}
	for rows.Next() {
		var category, subcategory string
		if err := rows.Scan(&category, &subcategory); err != nil {
			return nil, fmt.Errorf("journal: scan category: %w", err)
		}
		if len(out) == 0 || out[len(out)-1].Category != category {
			out = append(out, CategoryNode{Category: category, Subcategories: []string{}})
		}
		out[len(out)-1].Subcategories = append(out[len(out)-1].Subcategories, subcategory)
	}
	return out, rows.Err()
}

// GetEntry returns one entry — ownership is baked into the WHERE clause
// itself, since every row has exactly one owner via its own user_id column
// (unlike sheets, which needs a separate join-table ownership check).
func (r *Repo) GetEntry(ctx context.Context, userID, id string) (Entry, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+entryColumns+` FROM learning_journal_entries WHERE id = $1 AND user_id = $2`, id, userID)
	e, err := scanEntry(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, ErrNotFound
		}
		return Entry{}, fmt.Errorf("journal: get entry: %w", err)
	}
	return e, nil
}

// FindSimilarEntries returns userID's own entries whose title clears
// journalMatchThreshold against title, closest match first — cross-category
// on purpose, since the same topic can resurface under a differently-typed
// tag. excludeID, if non-empty, omits that entry (its own row, right after
// creating it). Purely informational: never merges or blocks a create,
// since journal entries are dated log rows, not course content to fold
// together.
//
// ponytail: title-only trigram match, the same mechanism courses already
// trusts for this; upgrade to pgvector/embedding similarity over content
// only if trigram misses too many semantically-similar-but-differently-
// worded entries in practice.
func (r *Repo) FindSimilarEntries(ctx context.Context, userID, title, excludeID string) ([]Entry, error) {
	query := `SELECT ` + entryColumns + ` FROM learning_journal_entries
		WHERE user_id = $1 AND similarity(title, $2) > $3`
	args := []any{userID, title, journalMatchThreshold}
	if excludeID != "" {
		args = append(args, excludeID)
		query += fmt.Sprintf(" AND id != $%d", len(args))
	}
	args = append(args, similarEntriesLimit)
	query += fmt.Sprintf(" ORDER BY similarity(title, $2) DESC LIMIT $%d", len(args))

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("journal: find similar entries: %w", err)
	}
	defer rows.Close()

	out := []Entry{}
	for rows.Next() {
		e, err := scanEntry(rows)
		if err != nil {
			return nil, fmt.Errorf("journal: scan similar entry: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// similarPairsLimit bounds the self-join below — personal-journal scale
// doesn't need real pagination, but an unbounded self-join deserves a floor.
const similarPairsLimit = 500

// ListSimilarPairs returns every pair of userID's own entries whose titles
// clear journalMatchThreshold against each other — the graph view's
// cross-branch edges. a.id < b.id keeps each pair once (not twice, reversed).
func (r *Repo) ListSimilarPairs(ctx context.Context, userID string) ([]SimilarPair, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT a.id, b.id
		 FROM learning_journal_entries a
		 JOIN learning_journal_entries b
		   ON b.user_id = a.user_id AND b.id > a.id AND similarity(a.title, b.title) > $2
		 WHERE a.user_id = $1
		 LIMIT $3`,
		userID, journalMatchThreshold, similarPairsLimit,
	)
	if err != nil {
		return nil, fmt.Errorf("journal: list similar pairs: %w", err)
	}
	defer rows.Close()

	out := []SimilarPair{}
	for rows.Next() {
		var p SimilarPair
		if err := rows.Scan(&p.SourceID, &p.TargetID); err != nil {
			return nil, fmt.Errorf("journal: scan similar pair: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// CreateEntry inserts a new entry. req.EntryDate nil defaults to today via
// the SQL COALESCE — the handler is responsible for turning an empty string
// into nil before this is called.
func (r *Repo) CreateEntry(ctx context.Context, userID string, req CreateEntryRequest) (Entry, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO learning_journal_entries (user_id, entry_date, category, subcategory, title, content)
		 VALUES ($1, COALESCE($2::date, CURRENT_DATE), $3, $4, $5, $6)
		 RETURNING `+entryColumns,
		userID, req.EntryDate, req.Category, req.Subcategory, req.Title, req.Content,
	)
	e, err := scanEntry(row)
	if err != nil {
		return Entry{}, fmt.Errorf("journal: create entry: %w", err)
	}
	return e, nil
}

// UpdateEntry applies a partial update. Nil fields are left unchanged.
func (r *Repo) UpdateEntry(ctx context.Context, userID, id string, req UpdateEntryRequest) (Entry, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE learning_journal_entries
		 SET entry_date  = COALESCE($3::date, entry_date),
		     category    = COALESCE($4, category),
		     subcategory = COALESCE($5, subcategory),
		     title       = COALESCE($6, title),
		     content     = COALESCE($7, content),
		     updated_at  = now()
		 WHERE id = $1 AND user_id = $2
		 RETURNING `+entryColumns,
		id, userID, req.EntryDate, req.Category, req.Subcategory, req.Title, req.Content,
	)
	e, err := scanEntry(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, ErrNotFound
		}
		return Entry{}, fmt.Errorf("journal: update entry: %w", err)
	}
	return e, nil
}

// MergeEntries combines otherID's content onto keepID and deletes otherID,
// atomically — both rows are locked first so a concurrent edit/delete can't
// interleave. Returns the updated kept entry and the full pre-delete
// snapshot of the removed entry (the caller holds it for a Ctrl+Z undo).
func (r *Repo) MergeEntries(ctx context.Context, userID, keepID, otherID string) (kept Entry, removed Entry, err error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return Entry{}, Entry{}, fmt.Errorf("journal: begin merge tx: %w", err)
	}
	defer tx.Rollback(ctx)

	keepRow := tx.QueryRow(ctx, `SELECT `+entryColumns+` FROM learning_journal_entries WHERE id = $1 AND user_id = $2 FOR UPDATE`, keepID, userID)
	keepBefore, err := scanEntry(keepRow)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, Entry{}, ErrNotFound
		}
		return Entry{}, Entry{}, fmt.Errorf("journal: lock kept entry: %w", err)
	}

	otherRow := tx.QueryRow(ctx, `SELECT `+entryColumns+` FROM learning_journal_entries WHERE id = $1 AND user_id = $2 FOR UPDATE`, otherID, userID)
	removed, err = scanEntry(otherRow)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, Entry{}, ErrNotFound
		}
		return Entry{}, Entry{}, fmt.Errorf("journal: lock merged-away entry: %w", err)
	}

	mergedContent := keepBefore.Content + "\n\n---\n\n" + removed.Content
	updatedRow := tx.QueryRow(ctx,
		`UPDATE learning_journal_entries SET content = $3, updated_at = now() WHERE id = $1 AND user_id = $2 RETURNING `+entryColumns,
		keepID, userID, mergedContent)
	kept, err = scanEntry(updatedRow)
	if err != nil {
		return Entry{}, Entry{}, fmt.Errorf("journal: update kept entry: %w", err)
	}

	tag, err := tx.Exec(ctx, `DELETE FROM learning_journal_entries WHERE id = $1 AND user_id = $2`, otherID, userID)
	if err != nil {
		return Entry{}, Entry{}, fmt.Errorf("journal: delete merged-away entry: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return Entry{}, Entry{}, ErrNotFound
	}

	if err := tx.Commit(ctx); err != nil {
		return Entry{}, Entry{}, fmt.Errorf("journal: commit merge: %w", err)
	}
	return kept, removed, nil
}

// DeleteEntry permanently deletes an entry the caller owns.
func (r *Repo) DeleteEntry(ctx context.Context, userID, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM learning_journal_entries WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("journal: delete entry: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

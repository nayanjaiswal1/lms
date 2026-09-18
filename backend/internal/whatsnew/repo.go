package whatsnew

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

const entryColumns = `id, title, description, icon, cta_label, cta_href, published, published_at, created_by, updated_at`

func scanEntry(row pgx.Row) (Entry, error) {
	var e Entry
	err := row.Scan(&e.ID, &e.Title, &e.Description, &e.Icon, &e.CTALabel, &e.CTAHref,
		&e.Published, &e.PublishedAt, &e.CreatedBy, &e.UpdatedAt)
	return e, err
}

func scanEntries(rows pgx.Rows) ([]Entry, error) {
	defer rows.Close()
	out := []Entry{}
	for rows.Next() {
		e, err := scanEntry(rows)
		if err != nil {
			return nil, fmt.Errorf("whatsnew: scan: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ListPublished returns the published entries any authenticated user sees in
// the sidebar panel, newest first.
func (r *Repo) ListPublished(ctx context.Context) ([]Entry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+entryColumns+` FROM whats_new_entries WHERE published ORDER BY published_at DESC LIMIT 20`,
	)
	if err != nil {
		return nil, fmt.Errorf("whatsnew: list published: %w", err)
	}
	return scanEntries(rows)
}

// ListAll returns every entry (published and draft), for the platform admin
// editor at /platform/whats-new.
func (r *Repo) ListAll(ctx context.Context) ([]Entry, error) {
	rows, err := r.pool.Query(ctx, `SELECT `+entryColumns+` FROM whats_new_entries ORDER BY published_at DESC`)
	if err != nil {
		return nil, fmt.Errorf("whatsnew: list all: %w", err)
	}
	return scanEntries(rows)
}

// Create inserts a new entry. Callers (service.go) have already validated
// Title/Description/Icon/CTALabel/CTAHref.
func (r *Repo) Create(ctx context.Context, e Entry) (Entry, error) {
	created, err := scanEntry(r.pool.QueryRow(ctx,
		`INSERT INTO whats_new_entries (title, description, icon, cta_label, cta_href, published, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)
		 RETURNING `+entryColumns,
		e.Title, e.Description, e.Icon, e.CTALabel, e.CTAHref, e.Published, e.CreatedBy,
	))
	if err != nil {
		return Entry{}, fmt.Errorf("whatsnew: create: %w", err)
	}
	return created, nil
}

// Update overwrites every editable field of an existing entry. published_at
// is bumped to now() whenever a draft transitions to published, so it starts
// sorting as the newest entry the moment it goes live — never mutated
// otherwise, so re-editing a live entry doesn't reorder the list.
func (r *Repo) Update(ctx context.Context, id string, e Entry) (Entry, error) {
	updated, err := scanEntry(r.pool.QueryRow(ctx,
		`UPDATE whats_new_entries
		    SET title = $2, description = $3, icon = $4, cta_label = $5, cta_href = $6,
		        published_at = CASE WHEN published = false AND $7 = true THEN now() ELSE published_at END,
		        published = $7, updated_at = now()
		  WHERE id = $1
		  RETURNING `+entryColumns,
		id, e.Title, e.Description, e.Icon, e.CTALabel, e.CTAHref, e.Published,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Entry{}, ErrNotFound
		}
		return Entry{}, fmt.Errorf("whatsnew: update: %w", err)
	}
	return updated, nil
}

// Delete permanently removes an entry — changelog rows carry no downstream
// references (unlike a coupon's redemptions), so unlike coupons.Deactivate
// this is a hard delete, not a soft one.
func (r *Repo) Delete(ctx context.Context, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM whats_new_entries WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("whatsnew: delete: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

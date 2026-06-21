package assessment

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the data-access layer for the assessment domain. Every method that
// reads or writes tenant data takes an orgID and filters on it, so a caller can
// never reach another organisation's rows.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Domain errors surfaced by the repo and service; handlers map these to HTTP codes.
var (
	// ErrNotFound — row does not exist or is not visible to the org.
	ErrNotFound = errors.New("assessment: not found")
	// ErrNotDraft — a structural edit was attempted on a non-draft assessment.
	ErrNotDraft = errors.New("assessment: only draft assessments can be edited")
	// ErrConflict — a uniqueness or state-transition rule was violated.
	ErrConflict = errors.New("assessment: conflict")
)

// txFunc runs fn inside a transaction, committing on nil error and rolling back
// otherwise. Used for multi-table writes (question + version, attempt finalize).
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("assessment: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("assessment: commit tx: %w", err)
	}
	return nil
}

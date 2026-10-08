package workspace

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo is the workspace data layer. Methods that must join a caller's
// transaction take a pgx.Tx (or DBTX) explicitly; the rest use the pool.
// Every query is scoped by project_id (and org_id where the project is
// looked up), so a row id from another project can never match.
type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo { return &Repo{pool: pool} }

// DBTX is satisfied by both *pgxpool.Pool and pgx.Tx, so read helpers can
// run inside or outside a transaction.
type DBTX interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// InTx runs fn inside one transaction, committing on nil and rolling back
// otherwise. Locks taken inside fn (FOR UPDATE, pg_advisory_xact_lock) span
// both the check and the write, as 02 §8 requires.
func (r *Repo) InTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("workspace: begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op after commit
	if err := fn(tx); err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("workspace: commit: %w", err)
	}
	return nil
}

// Pool exposes the pool for the few callers (jobs, middleware wiring) that
// need it directly.
func (r *Repo) Pool() *pgxpool.Pool { return r.pool }

package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
)

// pgErrUndefinedTable is the PostgreSQL error code for "relation does not exist".
const pgErrUndefinedTable = "42P01"

// AnalyticsPayload is the JSON payload for analytics.task jobs.
type AnalyticsPayload struct {
	// Date is a YYYY-MM-DD string for the daily rollup. Empty string skips the
	// rollup and only performs the cleanup pass.
	Date string `json:"date"`
}

// AnalyticsHandler implements jobs.Handler for HandlerAnalytics jobs.
type AnalyticsHandler struct {
	pool *pgxpool.Pool
}

// NewAnalyticsHandler constructs an AnalyticsHandler.
func NewAnalyticsHandler(pool *pgxpool.Pool) *AnalyticsHandler {
	return &AnalyticsHandler{pool: pool}
}

// Handle runs the optional daily rollup (when Date is set) and always runs the
// expired-token cleanup pass.
func (h *AnalyticsHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p AnalyticsPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.analytics: unmarshal payload: %w", err)
	}

	if p.Date != "" {
		if err := h.runDailyRollup(ctx, p.Date); err != nil {
			return err
		}
	}

	return h.runCleanup(ctx)
}

// runDailyRollup aggregates assessment attempt counts by org for the given date
// and upserts them into analytics_summaries. If that table does not exist yet
// (migration not yet applied), the step is skipped with a warning — the cleanup
// still runs. Each metric is upserted atomically; the INSERT … ON CONFLICT
// is idempotent so re-running for the same date is safe.
func (h *AnalyticsHandler) runDailyRollup(ctx context.Context, date string) error {
	_, err := h.pool.Exec(ctx,
		`INSERT INTO analytics_summaries (date, org_id, metric_key, value, created_at)
		 SELECT
		   $1::date,
		   aa.org_id,
		   'assessment_attempts',
		   COUNT(*),
		   NOW()
		 FROM assessment_attempts aa
		 WHERE DATE(aa.created_at) = $1::date
		 GROUP BY aa.org_id
		 ON CONFLICT (date, org_id, metric_key) DO UPDATE
		   SET value = EXCLUDED.value, updated_at = NOW()`,
		date,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgErrUndefinedTable {
			slog.WarnContext(ctx, "handlers.analytics: analytics_summaries table does not exist yet, skipping rollup",
				"date", date,
				"hint", "apply the analytics_summaries migration to enable this rollup")
			return nil
		}
		return fmt.Errorf("handlers.analytics: rollup assessment_attempts (%s): %w", date, err)
	}

	slog.InfoContext(ctx, "handlers.analytics: daily rollup complete", "date", date)
	return nil
}

// runCleanup deletes expired rows from the four auth token tables.
// Each table runs in its own independent transaction so that a 42P01 error
// (table does not exist) on one table does not abort the others — PostgreSQL
// marks the whole transaction as aborted on any error, so we cannot share a
// transaction across tables when some may be missing.
func (h *AnalyticsHandler) runCleanup(ctx context.Context) error {
	type cleanupStep struct {
		table string
		query string
	}

	steps := []cleanupStep{
		{
			table: "jti_blocklist",
			query: `DELETE FROM jti_blocklist WHERE expires_at < NOW()`,
		},
		{
			table: "refresh_tokens",
			query: `DELETE FROM refresh_tokens WHERE expires_at < NOW()`,
		},
		{
			table: "email_verifications",
			query: `DELETE FROM email_verifications WHERE expires_at < NOW() AND verified_at IS NOT NULL`,
		},
		{
			table: "oauth_exchanges",
			query: `DELETE FROM oauth_exchanges WHERE expires_at < NOW()`,
		},
	}

	for _, step := range steps {
		deleted, err := h.cleanupTable(ctx, step.query)
		if err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == pgErrUndefinedTable {
				slog.WarnContext(ctx, "handlers.analytics: cleanup table does not exist, skipping",
					"table", step.table)
				continue
			}
			return fmt.Errorf("handlers.analytics: cleanup %s: %w", step.table, err)
		}
		slog.InfoContext(ctx, "handlers.analytics: cleanup",
			"table", step.table,
			"rows_deleted", deleted)
	}

	return nil
}

// cleanupTable runs a single DELETE in its own transaction and returns the row count.
func (h *AnalyticsHandler) cleanupTable(ctx context.Context, query string) (int64, error) {
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	tag, err := tx.Exec(ctx, query)
	if err != nil {
		return 0, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit tx: %w", err)
	}
	return tag.RowsAffected(), nil
}

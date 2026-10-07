package handlers

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
)

// retentionStep is one purge statement. Statements with needsWindow take the
// age in days as $1; days == 0 disables the step. allowAuthEventsDelete lets
// the statement through the auth_events append-only trigger for its own
// transaction only.
type retentionStep struct {
	name                  string
	days                  int
	query                 string
	needsWindow           bool
	allowAuthEventsDelete bool
}

// RetentionPurgeHandler enforces the retention schedule (DPDP s.8(7)): old
// audit/event rows, public-test candidate PII and expired MCP tokens.
type RetentionPurgeHandler struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

// NewRetentionPurgeHandler constructs a RetentionPurgeHandler.
func NewRetentionPurgeHandler(pool *pgxpool.Pool, cfg *config.Config) *RetentionPurgeHandler {
	return &RetentionPurgeHandler{pool: pool, cfg: cfg}
}

// retentionSteps builds the enabled purge steps from cfg. Expired MCP tokens
// have no window: they are useless once past expires_at. mcp_connections
// (revoked, or refresh token expired) are kept for the audit window first.
func retentionSteps(cfg *config.Config) []retentionStep {
	const olderThan = ` < now() - make_interval(days => $1)`
	all := []retentionStep{
		{name: "audit_logs", days: cfg.RetentionAuditDays, needsWindow: true,
			query: `DELETE FROM audit_logs WHERE source <> 'mcp' AND created_at` + olderThan},
		{name: "mcp_action_log", days: cfg.RetentionMCPActionDays, needsWindow: true,
			query: `DELETE FROM audit_logs WHERE source = 'mcp' AND created_at` + olderThan},
		{name: "auth_events", days: cfg.RetentionAuthEventsDays, needsWindow: true, allowAuthEventsDelete: true,
			query: `DELETE FROM auth_events WHERE ts` + olderThan},
		{name: "attempt_events", days: cfg.RetentionAttemptEventsDays, needsWindow: true,
			query: `DELETE FROM attempt_events WHERE created_at` + olderThan},
		{name: "xp_events", days: cfg.RetentionXPEventsDays, needsWindow: true,
			query: `DELETE FROM xp_events WHERE created_at` + olderThan},
		{name: "lab_ai_interactions", days: cfg.RetentionLabAIDays, needsWindow: true,
			query: `DELETE FROM lab_ai_interactions WHERE created_at` + olderThan},
		{name: "public_test_candidates", days: cfg.RetentionPublicCandidatesDays, needsWindow: true,
			query: `UPDATE assessment_attempts SET anonymous_identity = NULL
			        WHERE user_id IS NULL AND anonymous_identity IS NOT NULL AND created_at` + olderThan},
		{name: "mcp_connections", days: cfg.RetentionMCPConnectionDays, needsWindow: true,
			query: `DELETE FROM mcp_connections
			        WHERE (status = 'revoked' AND revoked_at < now() - make_interval(days => $1))
			           OR refresh_token_expires_at < now() - make_interval(days => $1)`},
		{name: "mcp_tokens", days: 1,
			query: `DELETE FROM auth_tokens WHERE purpose IN ('mcp_auth_code', 'mcp_access_token') AND expires_at < now()`},
	}
	steps := all[:0]
	for _, s := range all {
		if s.days > 0 {
			steps = append(steps, s)
		}
	}
	return steps
}

// Handle runs every enabled purge step in its own transaction so one failing
// table does not block the others; the first error is returned after all ran.
func (h *RetentionPurgeHandler) Handle(ctx context.Context, _ jobs.Job) error {
	var firstErr error
	for _, s := range retentionSteps(h.cfg) {
		n, err := h.run(ctx, s)
		if err != nil {
			slog.ErrorContext(ctx, "handlers.retention: purge failed", "step", s.name, "error", err)
			if firstErr == nil {
				firstErr = fmt.Errorf("handlers.retention: %s: %w", s.name, err)
			}
			continue
		}
		slog.InfoContext(ctx, "handlers.retention: purged", "step", s.name, "rows", n)
	}
	return firstErr
}

func (h *RetentionPurgeHandler) run(ctx context.Context, s retentionStep) (int64, error) {
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if s.allowAuthEventsDelete {
		if _, err := tx.Exec(ctx, `SELECT set_config('mindforge.purge_auth_events', 'on', true)`); err != nil {
			return 0, fmt.Errorf("allow purge: %w", err)
		}
	}
	args := []any{}
	if s.needsWindow {
		args = append(args, s.days)
	}
	tag, err := tx.Exec(ctx, s.query, args...)
	if err != nil {
		return 0, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit tx: %w", err)
	}
	return tag.RowsAffected(), nil
}

package handlers

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labs"
)

const (
	HandlerLabExpire  = "lab.expire_sessions"
	HandlerLabCleanup = "lab.cleanup_containers"
)

// LabExpireHandler marks stale lab sessions as expired and removes their containers.
type LabExpireHandler struct {
	pool    *pgxpool.Pool
	runtime labs.ContainerRuntime
}

// NewLabExpireHandler constructs a LabExpireHandler.
func NewLabExpireHandler(pool *pgxpool.Pool, runtime labs.ContainerRuntime) *LabExpireHandler {
	return &LabExpireHandler{pool: pool, runtime: runtime}
}

// Handle finds all running/paused sessions that have either hit their hard
// expires_at cap or gone quiet for longer than labs.IdleTimeoutMinutes (no
// last_active_at heartbeat — the lab proxy bumps that every 5s while a
// terminal WebSocket is connected, so a stale timestamp means the user
// closed the tab or lost connection without ending the session). Each match
// gets its container removed and is marked expired with the reason that
// triggered it, so the result page can tell the user why their lab ended.
func (h *LabExpireHandler) Handle(ctx context.Context, job jobs.Job) error {
	rows, err := h.pool.Query(ctx,
		`SELECT id, container_id,
		        CASE WHEN expires_at < now() THEN 'time_limit' ELSE 'idle_timeout' END AS reason
		 FROM lab_sessions
		 WHERE status IN ($1, $2)
		   AND (expires_at < now() OR last_active_at < now() - make_interval(mins => $3))
		 LIMIT 100`,
		labs.SessionStatusRunning, labs.SessionStatusPaused, labs.IdleTimeoutMinutes,
	)
	if err != nil {
		return fmt.Errorf("lab.expire_sessions: query sessions: %w", err)
	}
	defer rows.Close()

	type sessionRow struct {
		id          string
		containerID *string
		reason      string
	}

	var sessions []sessionRow
	for rows.Next() {
		var r sessionRow
		if err := rows.Scan(&r.id, &r.containerID, &r.reason); err != nil {
			return fmt.Errorf("lab.expire_sessions: scan row: %w", err)
		}
		sessions = append(sessions, r)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("lab.expire_sessions: iterate rows: %w", err)
	}
	if len(sessions) == 0 {
		return nil
	}

	// Removing a sandbox is a per-session runtime call — can't be batched.
	// The DB update below is a single statement for the API responses.
	ids := make([]string, len(sessions))
	timeLimitCount, idleCount := 0, 0
	for i, s := range sessions {
		ids[i] = s.id
		if s.containerID != nil && *s.containerID != "" {
			if rmErr := h.runtime.Kill(ctx, *s.containerID); rmErr != nil {
				slog.Error("lab.expire_sessions: kill sandbox failed",
					"container", *s.containerID, "error", rmErr)
			}
		}
		if s.reason == "idle_timeout" {
			idleCount++
		} else {
			timeLimitCount++
		}
	}

	// One round trip for up to 100 rows instead of one per row. The reason is
	// recomputed here with the same CASE expression as the SELECT above —
	// safe, since now() only moves forward: any row that matched
	// expires_at < now() there still matches it a few milliseconds later here.
	if _, err := h.pool.Exec(ctx,
		`UPDATE lab_sessions
		 SET status = $2,
		     end_reason = CASE WHEN expires_at < now() THEN 'time_limit' ELSE 'idle_timeout' END
		 WHERE id = ANY($1)`,
		ids, labs.SessionStatusExpired,
	); err != nil {
		// The job retries next minute — the same stale sessions will still
		// match the SELECT above (their status hasn't changed), so a failed
		// batch here is not silently lost.
		return fmt.Errorf("lab.expire_sessions: batch update status: %w", err)
	}

	slog.Info("lab.expire_sessions: expired sessions",
		"time_limit", timeLimitCount, "idle_timeout", idleCount)
	return nil
}

// LabCleanupHandler removes orphaned lab sandboxes that have no active session row.
type LabCleanupHandler struct {
	pool    *pgxpool.Pool
	runtime labs.ContainerRuntime
}

// NewLabCleanupHandler constructs a LabCleanupHandler.
func NewLabCleanupHandler(pool *pgxpool.Pool, runtime labs.ContainerRuntime) *LabCleanupHandler {
	return &LabCleanupHandler{pool: pool, runtime: runtime}
}

// Handle scans all mindforge-lab-* and mindforge-validate-* sandboxes and
// removes those that are old enough and have no corresponding active session row.
func (h *LabCleanupHandler) Handle(ctx context.Context, job jobs.Job) error {
	removed := 0

	// --- lab sandboxes ---
	labSandboxes, labErr := h.runtime.List(ctx, "mindforge-lab-")
	if labErr != nil {
		slog.Warn("lab.cleanup_containers: list (lab)", "error", labErr)
	} else {
		for _, sb := range labSandboxes {
			// Extract sessionID: mindforge-lab-{UUID36}-{resetCount}
			trimmed := strings.TrimPrefix(sb.Name, "mindforge-lab-")
			if len(trimmed) < 36 {
				continue
			}
			sessionID := trimmed[:36]

			if time.Since(sb.CreatedAt) < 2*time.Minute {
				continue
			}

			// Only remove if no active session row exists.
			var activeID string
			qErr := h.pool.QueryRow(ctx,
				`SELECT id FROM lab_sessions
				 WHERE id=$1 AND status IN ('provisioning','running','paused')
				 LIMIT 1`,
				sessionID,
			).Scan(&activeID)
			if qErr == nil {
				// Active session found — leave the sandbox alone.
				continue
			}
			if !errors.Is(qErr, pgx.ErrNoRows) {
				// Real DB error — skip removal to avoid accidentally destroying a live sandbox.
				slog.Warn("lab.cleanup_containers: query active session",
					"session", sessionID, "error", qErr)
				continue
			}

			if rmErr := h.runtime.Kill(ctx, sb.ID); rmErr != nil {
				slog.Error("lab.cleanup_containers: kill (lab)",
					"container", sb.ID, "error", rmErr)
				continue
			}
			removed++
		}
	}

	// --- validate sandboxes (older than 15 minutes are always orphaned) ---
	validateSandboxes, vErr := h.runtime.List(ctx, "mindforge-validate-")
	if vErr != nil {
		slog.Warn("lab.cleanup_containers: list (validate)", "error", vErr)
	} else {
		for _, sb := range validateSandboxes {
			if time.Since(sb.CreatedAt) < 15*time.Minute {
				continue
			}
			if rmErr := h.runtime.Kill(ctx, sb.ID); rmErr != nil {
				slog.Error("lab.cleanup_containers: kill (validate)",
					"container", sb.ID, "error", rmErr)
				continue
			}
			removed++
		}
	}

	// --- warm-pool sandboxes ---
	// A "mindforge-warm-{UUID36}" container is legitimate exactly while its
	// lab_warm_containers row exists (any status — claimed ones belong to a
	// live session). No row means the reconciler gave up on it (e.g. a
	// StartWarm that timed out after the row was deleted) — remove it.
	warmSandboxes, wErr := h.runtime.List(ctx, "mindforge-warm-")
	if wErr != nil {
		slog.Warn("lab.cleanup_containers: list (warm)", "error", wErr)
	} else {
		warmRepo := labs.NewRepo(h.pool)
		for _, sb := range warmSandboxes {
			trimmed := strings.TrimPrefix(sb.Name, "mindforge-warm-")
			if len(trimmed) < 36 {
				continue
			}
			warmID := trimmed[:36]

			if time.Since(sb.CreatedAt) < 2*time.Minute {
				continue
			}

			exists, qErr := warmRepo.WarmContainerExists(ctx, warmID)
			if qErr != nil {
				// DB error — skip removal to avoid destroying a live sandbox.
				slog.Warn("lab.cleanup_containers: query warm row", "warm_id", warmID, "error", qErr)
				continue
			}
			if exists {
				continue
			}

			if rmErr := h.runtime.Kill(ctx, sb.ID); rmErr != nil {
				slog.Error("lab.cleanup_containers: kill (warm)",
					"container", sb.ID, "error", rmErr)
				continue
			}
			removed++
		}
	}

	slog.Info("lab.cleanup_containers: removed orphaned containers", "count", removed)
	return nil
}

// ─── Warm pool reconciler ────────────────────────────────────────────────────

// HandlerLabWarmPool runs the demand-driven warm pool planner (labs/warmpool.go)
// once per minute: gather signals → decide per-lab targets → record every
// decision with its inputs → converge containers.
const HandlerLabWarmPool = "lab.warm_pool_reconcile"

// LabWarmPoolHandler adapts labs.WarmPoolPlanner to the jobs registry.
type LabWarmPoolHandler struct {
	planner *labs.WarmPoolPlanner
}

// NewLabWarmPoolHandler constructs the handler. globalMax is
// LABS_WARM_POOL_GLOBAL_MAX — the total warm container budget across labs.
func NewLabWarmPoolHandler(pool *pgxpool.Pool, runtime labs.ContainerRuntime, globalMax int) *LabWarmPoolHandler {
	return &LabWarmPoolHandler{planner: labs.NewWarmPoolPlanner(pool, runtime, globalMax)}
}

// Handle runs one reconcile tick.
func (h *LabWarmPoolHandler) Handle(ctx context.Context, job jobs.Job) error {
	return h.planner.Tick(ctx)
}

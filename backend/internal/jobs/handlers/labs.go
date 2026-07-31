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
	"github.com/mindforge/backend/internal/notifications"
)

const (
	HandlerLabExpire  = "lab.expire_sessions"
	HandlerLabCleanup = "lab.cleanup_containers"
)

// LabExpireHandler marks stale lab sessions as expired and removes their containers.
type LabExpireHandler struct {
	pool          *pgxpool.Pool
	runtime       labs.ContainerRuntime
	notifications *notifications.Service
}

// NewLabExpireHandler constructs a LabExpireHandler. notifSvc backs the
// repeated-provisioning-failure admin alert reapStuckProvisioning fires —
// see that method's own doc comment.
func NewLabExpireHandler(pool *pgxpool.Pool, runtime labs.ContainerRuntime, notifSvc *notifications.Service) *LabExpireHandler {
	return &LabExpireHandler{pool: pool, runtime: runtime, notifications: notifSvc}
}

// Handle finds all running/paused sessions that have either hit their hard
// expires_at cap or gone quiet for longer than labs.IdleTimeoutMinutes (no
// last_active_at heartbeat — the lab proxy bumps that every 5s while a
// terminal WebSocket is connected, so a stale timestamp means the user
// closed the tab or lost connection without ending the session). Each match
// gets its container removed and is marked expired with the reason that
// triggered it, so the result page can tell the user why their lab ended.
func (h *LabExpireHandler) Handle(ctx context.Context, job jobs.Job) error {
	if err := h.reapStuckProvisioning(ctx); err != nil {
		// Logged, not returned: a failure here must not stop the
		// running/paused sweep below from also running this tick.
		slog.Error("lab.expire_sessions: reap stuck provisioning failed", "error", err)
	}

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

// reapStuckProvisioning is the durable backstop for labs.Service.provisionContainer's
// in-process timeout: that function runs as a fire-and-forget goroutine on
// context.Background(), so if the backend process restarts (deploy, crash)
// while a session is mid-provision, the goroutine — and its
// labs.ProvisionTimeoutSeconds context timeout — dies with it, leaving the
// row in 'provisioning' forever. lab_sessions_one_active only excludes
// terminal statuses, so an orphaned row permanently blocks that user from
// starting any other lab (see docs/labs.md "Session stuck in provisioning"
// edge case — this is what actually implements it). Runs every tick
// alongside the running/paused sweep since both are "find stale sessions and
// close them out"; still marks the session 'failed', not 'expired', since
// nothing ever ran here.
func (h *LabExpireHandler) reapStuckProvisioning(ctx context.Context) error {
	thresholdSeconds := labs.ProvisionTimeoutSeconds + labs.ProvisionReapGraceSeconds

	rows, err := h.pool.Query(ctx,
		`SELECT id, lab_id, org_id, container_id
		 FROM lab_sessions
		 WHERE status = $1
		   AND started_at < now() - make_interval(secs => $2)
		 LIMIT 100`,
		labs.SessionStatusProvisioning, thresholdSeconds,
	)
	if err != nil {
		return fmt.Errorf("query stuck provisioning sessions: %w", err)
	}

	type stuckSession struct {
		id, labID, orgID string
		containerID      *string
	}
	var stuck []stuckSession
	for rows.Next() {
		var s stuckSession
		if err := rows.Scan(&s.id, &s.labID, &s.orgID, &s.containerID); err != nil {
			rows.Close()
			return fmt.Errorf("scan stuck provisioning session: %w", err)
		}
		stuck = append(stuck, s)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return fmt.Errorf("stuck provisioning rows: %w", err)
	}
	rows.Close()
	if len(stuck) == 0 {
		return nil
	}

	reason := fmt.Sprintf("Provisioning did not complete within %ds; session reaped by lab.expire_sessions.", thresholdSeconds)
	affectedLabs := map[string]string{} // labID -> orgID, deduped for the notify pass below

	for _, s := range stuck {
		if s.containerID != nil && *s.containerID != "" {
			if rmErr := h.runtime.Kill(ctx, *s.containerID); rmErr != nil {
				slog.Error("lab.expire_sessions: kill stuck-provisioning sandbox failed",
					"container", *s.containerID, "error", rmErr)
			}
		}
		if _, err := h.pool.Exec(ctx,
			`UPDATE lab_sessions SET status=$2, end_reason=$3, provision_error=$4 WHERE id=$1`,
			s.id, labs.SessionStatusFailed, labs.EndReasonProvisionTimeout, reason,
		); err != nil {
			slog.Error("lab.expire_sessions: mark stuck provisioning failed",
				"session_id", s.id, "error", err)
			continue
		}
		affectedLabs[s.labID] = s.orgID
	}

	slog.Info("lab.expire_sessions: reaped stuck provisioning sessions", "count", len(stuck))

	for labID, orgID := range affectedLabs {
		h.notifyRepeatedProvisionFailures(ctx, labID, orgID)
	}
	return nil
}

// notifyRepeatedProvisionFailures mirrors labs.Service's own method of the
// same name (duplicated rather than shared — this handler intentionally
// holds only pool+runtime+notifications, not a full *labs.Service, matching
// every other handler in this file; see labs.Service.StartSession's
// circuit-breaker gate for the other caller of this same threshold). Both
// must stay in sync with labs.ProvisionFailureCircuitBreakerThreshold/Window.
func (h *LabExpireHandler) notifyRepeatedProvisionFailures(ctx context.Context, labID, orgID string) {
	if h.notifications == nil {
		return
	}

	var failures int
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM lab_sessions
		 WHERE lab_id=$1
		   AND end_reason IN ('provision_timeout', 'provision_failed')
		   AND started_at > now() - $2::interval`,
		labID, fmt.Sprintf("%d seconds", int(labs.ProvisionFailureCircuitBreakerWindow.Seconds())),
	).Scan(&failures); err != nil {
		slog.Error("lab.expire_sessions: count recent provision failures", "lab_id", labID, "error", err)
		return
	}
	if failures < labs.ProvisionFailureCircuitBreakerThreshold {
		return
	}

	var labTitle string
	if err := h.pool.QueryRow(ctx, `SELECT title FROM lab_definitions WHERE id=$1`, labID).Scan(&labTitle); err != nil {
		slog.Error("lab.expire_sessions: get lab title", "lab_id", labID, "error", err)
		return
	}

	rows, err := h.pool.Query(ctx,
		`SELECT user_id FROM org_members WHERE org_id=$1 AND role IN ('owner', 'admin')`, orgID,
	)
	if err != nil {
		slog.Error("lab.expire_sessions: get org admins", "org_id", orgID, "error", err)
		return
	}
	var recipients []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			slog.Error("lab.expire_sessions: scan org admin", "error", err)
			return
		}
		recipients = append(recipients, id)
	}
	rows.Close()
	if len(recipients) == 0 {
		return
	}

	windowBucket := time.Now().UTC().Truncate(labs.ProvisionFailureCircuitBreakerWindow).Unix()
	body := fmt.Sprintf(
		"\"%s\" has failed to provision %d times in the last %s and is temporarily blocked from starting new sessions until fixed. Check the lab's image and setup_script.",
		labTitle, failures, labs.ProvisionFailureCircuitBreakerWindow,
	)
	entityType := "lab_definition"

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		slog.Error("lab.expire_sessions: begin notify tx", "error", err)
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := h.notifications.NotifyMany(ctx, tx, notifications.New{
		OrgID:      orgID,
		Type:       "lab_provisioning_unstable",
		Title:      fmt.Sprintf("Lab \"%s\" is repeatedly failing to start", labTitle),
		Body:       &body,
		EntityType: &entityType,
		EntityID:   &labID,
		Priority:   notifications.PriorityHigh,
		DedupeKey:  fmt.Sprintf("lab-provision-incident:%s:%d", labID, windowBucket),
		AlsoEmail:  true,
	}, recipients); err != nil {
		slog.Error("lab.expire_sessions: notify repeated provision failures", "lab_id", labID, "error", err)
		return
	}
	if err := tx.Commit(ctx); err != nil {
		slog.Error("lab.expire_sessions: commit notify tx", "error", err)
	}
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

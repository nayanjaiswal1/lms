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

// Handle runs three passes every tick, in order:
//
//  1. hardExpireOverdue — ANY running or paused session past its hard
//     expires_at deadline is closed out immediately, regardless of pause
//     state. This is the wall-clock cap docs/labs.md calls HARD; nothing
//     below is allowed to extend it.
//  2. pauseIdleRunning — a running session gone quiet for
//     labs.IdleTimeoutMinutes (no last_active_at heartbeat — bumped by every
//     session-touching request, not just the terminal WS) is PAUSED, not
//     killed: this stops CPU billing while preserving the student's
//     filesystem/process state exactly as docs/labs.md's "Idle-pause" design
//     describes. A runtime that can't pause (Kubernetes — see
//     ContainerRuntime.Pause) falls back to the old kill+expire behavior,
//     since there is no cheaper way to reclaim that Pod.
//  3. reapLongPaused — a paused session that has sat untouched for
//     labs.IdleReapMinutes (much longer than the pause threshold) is finally
//     closed out. A paused container still holds memory and disk, so it
//     cannot be held forever, but this gives the student a wide window to
//     come back to it — the old behavior destroyed their work at 15 minutes
//     flat.
func (h *LabExpireHandler) Handle(ctx context.Context, job jobs.Job) error {
	if err := h.reapStuckProvisioning(ctx); err != nil {
		// Logged, not returned: a failure here must not stop the passes below.
		slog.Error("lab.expire_sessions: reap stuck provisioning failed", "error", err)
	}
	if err := h.hardExpireOverdue(ctx); err != nil {
		slog.Error("lab.expire_sessions: hard expire failed", "error", err)
	}
	if err := h.pauseIdleRunning(ctx); err != nil {
		slog.Error("lab.expire_sessions: pause idle running failed", "error", err)
	}
	if err := h.reapLongPaused(ctx); err != nil {
		slog.Error("lab.expire_sessions: reap long-paused failed", "error", err)
	}
	return nil
}

// sessionRow is the (id, container_id) shape every pass below queries and
// acts on.
type sessionRow struct {
	id          string
	containerID *string
}

// closeSessions kills each session's container (best-effort, per-session —
// Kill is a runtime call and can't be batched), then in one round trip marks
// every row expired with endReason and records its billed container_seconds.
// Shared by hardExpireOverdue and reapLongPaused, which differ only in which
// rows they select and which end_reason applies.
func (h *LabExpireHandler) closeSessions(ctx context.Context, sessions []sessionRow, endReason string) error {
	if len(sessions) == 0 {
		return nil
	}
	ids := make([]string, len(sessions))
	for i, s := range sessions {
		ids[i] = s.id
		if s.containerID != nil && *s.containerID != "" {
			if rmErr := h.runtime.Kill(ctx, *s.containerID); rmErr != nil {
				slog.Error("lab.expire_sessions: kill sandbox failed",
					"container", *s.containerID, "error", rmErr)
			}
		}
	}
	if _, err := h.pool.Exec(ctx,
		`UPDATE lab_sessions SET status=$2, end_reason=$3, paused_at=NULL WHERE id = ANY($1)`,
		ids, labs.SessionStatusExpired, endReason,
	); err != nil {
		// The job retries next tick — the same rows still match their
		// originating SELECT (status hasn't changed), so this is not lost.
		return fmt.Errorf("batch update status: %w", err)
	}
	if err := labs.NewRepo(h.pool).RecordSessionContainerUsageBatch(ctx, ids); err != nil {
		slog.Error("lab.expire_sessions: record usage batch", "error", err)
	}
	slog.Info("lab.expire_sessions: closed sessions", "count", len(sessions), "reason", endReason)
	return nil
}

// hardExpireOverdue closes out every running/paused session whose
// expires_at has passed, unconditionally — see Handle's doc comment.
func (h *LabExpireHandler) hardExpireOverdue(ctx context.Context) error {
	rows, err := h.pool.Query(ctx,
		`SELECT id, container_id FROM lab_sessions
		 WHERE status IN ($1, $2) AND expires_at < now()
		 LIMIT 100`,
		labs.SessionStatusRunning, labs.SessionStatusPaused,
	)
	if err != nil {
		return fmt.Errorf("query overdue sessions: %w", err)
	}
	sessions, err := scanIDContainerRows(rows)
	if err != nil {
		return err
	}
	return h.closeSessions(ctx, sessions, labs.EndReasonTimeLimit)
}

// pauseIdleRunning pauses every running session that has gone quiet for
// labs.IdleTimeoutMinutes but is not yet past its hard deadline (that case
// is hardExpireOverdue's, and runs first every tick). Sessions with no
// container (code labs — nothing to pause, nothing costs CPU while idle) are
// excluded and simply ride until expires_at.
func (h *LabExpireHandler) pauseIdleRunning(ctx context.Context) error {
	rows, err := h.pool.Query(ctx,
		`SELECT id, container_id FROM lab_sessions
		 WHERE status = $1
		   AND container_id IS NOT NULL
		   AND expires_at >= now()
		   AND last_active_at < now() - make_interval(mins => $2)
		 LIMIT 100`,
		labs.SessionStatusRunning, labs.IdleTimeoutMinutes,
	)
	if err != nil {
		return fmt.Errorf("query idle running sessions: %w", err)
	}
	sessions, err := scanIDContainerRows(rows)
	if err != nil {
		return err
	}
	if len(sessions) == 0 {
		return nil
	}

	var paused []sessionRow
	var fallbackKill []sessionRow
	for _, s := range sessions {
		pauseErr := h.runtime.Pause(ctx, *s.containerID)
		switch {
		case pauseErr == nil:
			paused = append(paused, s)
		case errors.Is(pauseErr, labs.ErrPauseUnsupported):
			// Expected on Kubernetes — not an error worth logging every tick.
			fallbackKill = append(fallbackKill, s)
		default:
			slog.Error("lab.expire_sessions: pause failed, falling back to kill",
				"session_id", s.id, "container", *s.containerID, "error", pauseErr)
			fallbackKill = append(fallbackKill, s)
		}
	}

	if len(paused) > 0 {
		ids := make([]string, len(paused))
		for i, s := range paused {
			ids[i] = s.id
		}
		if _, err := h.pool.Exec(ctx,
			`UPDATE lab_sessions SET status=$2, paused_at=now() WHERE id = ANY($1)`,
			ids, labs.SessionStatusPaused,
		); err != nil {
			return fmt.Errorf("batch update paused: %w", err)
		}
	}
	if err := h.closeSessions(ctx, fallbackKill, labs.EndReasonIdleTimeout); err != nil {
		return fmt.Errorf("fallback kill: %w", err)
	}

	slog.Info("lab.expire_sessions: paused idle sessions", "paused", len(paused), "fallback_killed", len(fallbackKill))
	return nil
}

// reapLongPaused closes out every session that has sat paused for
// labs.IdleReapMinutes — see Handle's doc comment.
func (h *LabExpireHandler) reapLongPaused(ctx context.Context) error {
	rows, err := h.pool.Query(ctx,
		`SELECT id, container_id FROM lab_sessions
		 WHERE status = $1 AND paused_at < now() - make_interval(mins => $2)
		 LIMIT 100`,
		labs.SessionStatusPaused, labs.IdleReapMinutes,
	)
	if err != nil {
		return fmt.Errorf("query long-paused sessions: %w", err)
	}
	sessions, err := scanIDContainerRows(rows)
	if err != nil {
		return err
	}
	return h.closeSessions(ctx, sessions, labs.EndReasonIdleTimeout)
}

// scanIDContainerRows drains a (id, container_id) result set into a slice.
// Shared by every pass above — they differ only in the WHERE clause feeding
// this same two-column shape.
func scanIDContainerRows(rows pgx.Rows) ([]sessionRow, error) {
	defer rows.Close()
	var out []sessionRow
	for rows.Next() {
		var s sessionRow
		if err := rows.Scan(&s.id, &s.containerID); err != nil {
			return nil, fmt.Errorf("scan row: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
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
// LABS_WARM_POOL_GLOBAL_MAX — the total warm container budget across images;
// overrides is the parsed LABS_WARM_POOL_OVERRIDES map (nil = size every image
// automatically).
func NewLabWarmPoolHandler(pool *pgxpool.Pool, runtime labs.ContainerRuntime, globalMax int, overrides map[string]labs.WarmPoolOverride) *LabWarmPoolHandler {
	return &LabWarmPoolHandler{planner: labs.NewWarmPoolPlanner(pool, runtime, globalMax, overrides)}
}

// Handle runs one reconcile tick.
func (h *LabWarmPoolHandler) Handle(ctx context.Context, job jobs.Job) error {
	return h.planner.Tick(ctx)
}

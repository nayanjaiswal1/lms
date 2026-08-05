package labs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo executes direct pgx/v5 queries against the labs schema.
type Repo struct{ pool *pgxpool.Pool }

// NewRepo builds a Repo from the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo { return &Repo{pool: pool} }

// ─── Lab definitions ─────────────────────────────────────────────────────────

// GetLab loads a lab definition visible to the given org.
func (r *Repo) GetLab(ctx context.Context, labID, orgID string) (*LabDefinition, error) {
	var l LabDefinition
	err := r.pool.QueryRow(ctx, `
		SELECT id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port,
		       language, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published,
		       published_version_id, workspace_layout, created_by, created_at, updated_at
		FROM lab_definitions WHERE id=$1 AND org_id=$2`,
		labID, orgID,
	).Scan(
		&l.ID, &l.OrgID, &l.CourseID, &l.ModuleID, &l.Scope, &l.Title, &l.Description,
		&l.LabType, &l.Environment, &l.PreviewPort, &l.Language, &l.SetupScript, &l.RunScript, &l.MaxDuration, &l.MaxResets,
		&l.HintPenaltyPct, &l.IsRequired, &l.IsPublished, &l.PublishedVersionID, &l.WorkspaceLayout,
		&l.CreatedBy, &l.CreatedAt, &l.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetLab: %w", err)
	}
	return &l, nil
}

// GetLabByModuleID returns the published lab definition linked to a course module.
func (r *Repo) GetLabByModuleID(ctx context.Context, moduleID, orgID string) (*LabDefinition, error) {
	var l LabDefinition
	err := r.pool.QueryRow(ctx, `
		SELECT id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port,
		       language, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published,
		       published_version_id, workspace_layout, created_by, created_at, updated_at
		FROM lab_definitions WHERE module_id=$1 AND org_id=$2 AND is_published=true
		LIMIT 1`,
		moduleID, orgID,
	).Scan(
		&l.ID, &l.OrgID, &l.CourseID, &l.ModuleID, &l.Scope, &l.Title, &l.Description,
		&l.LabType, &l.Environment, &l.PreviewPort, &l.Language, &l.SetupScript, &l.RunScript, &l.MaxDuration, &l.MaxResets,
		&l.HintPenaltyPct, &l.IsRequired, &l.IsPublished, &l.PublishedVersionID, &l.WorkspaceLayout,
		&l.CreatedBy, &l.CreatedAt, &l.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetLabByModuleID: %w", err)
	}
	return &l, nil
}

// GetPublishedVersion loads the task snapshot rows for a task version,
// ordered by position. TaskSnapshot.ID is the lab_task_version_items
// surrogate id (not the mutable lab_tasks id) — it's what completions are
// keyed against, scoped to this one version.
func (r *Repo) GetPublishedVersion(ctx context.Context, versionID string) ([]TaskSnapshot, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, position, title, description, verification_script,
		        COALESCE(hint_context, ''), COALESCE(explanation_context, ''),
		        points, is_optional, is_stateful
		 FROM lab_task_version_items WHERE task_version_id=$1 ORDER BY position`,
		versionID,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.GetPublishedVersion: %w", err)
	}
	defer rows.Close()
	tasks := make([]TaskSnapshot, 0)
	for rows.Next() {
		var t TaskSnapshot
		if err := rows.Scan(&t.ID, &t.Position, &t.Title, &t.Description, &t.VerificationScript,
			&t.HintContext, &t.ExplanationContext, &t.Points, &t.IsOptional, &t.IsStateful); err != nil {
			return nil, fmt.Errorf("labs.Repo.GetPublishedVersion: scan: %w", err)
		}
		tasks = append(tasks, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("labs.Repo.GetPublishedVersion: rows: %w", err)
	}
	// An empty result is a legitimate, expected snapshot — `playground` labs
	// are task-free by design (docs/labs.md), and publish cuts them an empty
	// version. Returning ErrNotFound here previously made every caller that
	// loads the snapshot fail closed for those labs, which is why a
	// playground session could never be ended: EndSession 404'd before it
	// could compute a terminal status, leaving the row 'running' until the
	// reaper took it. There is no "version missing" case to distinguish —
	// versionID always arrives via a NOT NULL FK (lab_sessions.task_version_id
	// or lab_definitions.published_version_id).
	return tasks, nil
}

// ─── Org config ──────────────────────────────────────────────────────────────

// GetOrgConfig loads org-level lab config from org_settings.labs jsonb.
// Missing rows or empty jsonb return platform defaults with nil error.
func (r *Repo) GetOrgConfig(ctx context.Context, orgID string) (LabOrgConfig, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(labs, '{}'::jsonb) FROM org_settings WHERE org_id=$1`,
		orgID,
	).Scan(&raw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return LabOrgConfig{
				OrgID:                 orgID,
				MaxConcurrentSessions: MaxConcurrentSessionsDefault,
				MaxSessionDuration:    MaxSessionDurationDefault,
			}, nil
		}
		return LabOrgConfig{}, fmt.Errorf("labs.Repo.GetOrgConfig: %w", err)
	}

	cfg := LabOrgConfig{
		OrgID:                 orgID,
		MaxConcurrentSessions: MaxConcurrentSessionsDefault,
		MaxSessionDuration:    MaxSessionDurationDefault,
	}

	type labsJSON struct {
		MaxConcurrentSessions *int      `json:"max_concurrent_sessions"`
		MaxSessionDuration    *int      `json:"max_session_duration"`
		AllowedImages         []string  `json:"allowed_images"`
		EgressProxyEnabled    *bool     `json:"egress_proxy_enabled"`
	}

	var parsed labsJSON
	if len(raw) > 2 { // Skip empty {}
		if err := json.Unmarshal(raw, &parsed); err != nil {
			return LabOrgConfig{}, fmt.Errorf("labs.Repo.GetOrgConfig: unmarshal: %w", err)
		}
		if parsed.MaxConcurrentSessions != nil {
			cfg.MaxConcurrentSessions = *parsed.MaxConcurrentSessions
		}
		if parsed.MaxSessionDuration != nil {
			cfg.MaxSessionDuration = *parsed.MaxSessionDuration
		}
		cfg.AllowedImages = parsed.AllowedImages
		if parsed.EgressProxyEnabled != nil {
			cfg.EgressProxyEnabled = *parsed.EgressProxyEnabled
		}
	}

	return cfg, nil
}

// ─── Sessions ────────────────────────────────────────────────────────────────

// CreateSessionParams carries the inputs for a new lab session row.
type CreateSessionParams struct {
	LabID         string
	TaskVersionID string
	UserID        string
	OrgID         string
	ExpiresAt     time.Time
	IsTest        bool
}

// CreateSession inserts a new lab_sessions row inside the given transaction.
// Returns ErrSessionActive when the per-user-per-lab unique index fires.
func (r *Repo) CreateSession(ctx context.Context, tx pgx.Tx, params CreateSessionParams) (*LabSession, error) {
	var s LabSession
	err := tx.QueryRow(ctx, `
		INSERT INTO lab_sessions (lab_id, task_version_id, user_id, org_id, expires_at, is_test)
		VALUES ($1,$2,$3,$4,$5,$6)
		RETURNING id, lab_id, task_version_id, user_id, org_id, container_id, container_host,
		          status, reset_count, score, is_test, started_at, expires_at, paused_seconds, paused_at,
		          completed_at, last_active_at, end_reason`,
		params.LabID, params.TaskVersionID, params.UserID, params.OrgID,
		params.ExpiresAt, params.IsTest,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds, &s.PausedAt,
		&s.CompletedAt, &s.LastActiveAt, &s.EndReason,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, ErrSessionActive
		}
		return nil, fmt.Errorf("labs.Repo.CreateSession: %w", err)
	}
	return &s, nil
}

// GetSession loads a session, enforcing that it belongs to userID (IDOR guard).
func (r *Repo) GetSession(ctx context.Context, sessionID, userID string) (*LabSession, error) {
	var s LabSession
	err := r.pool.QueryRow(ctx, `
		SELECT id, lab_id, task_version_id, user_id, org_id, container_id, container_host,
		       status, reset_count, score, is_test, started_at, expires_at, paused_seconds, paused_at,
		       completed_at, last_active_at, end_reason, provision_error
		FROM lab_sessions WHERE id=$1 AND user_id=$2`,
		sessionID, userID,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds, &s.PausedAt,
		&s.CompletedAt, &s.LastActiveAt, &s.EndReason, &s.ProvisionError,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetSession: %w", err)
	}
	return &s, nil
}

// GetSessionByID loads a session without an ownership check. For internal use
// only (provisioning goroutines, background jobs).
func (r *Repo) GetSessionByID(ctx context.Context, sessionID string) (*LabSession, error) {
	var s LabSession
	err := r.pool.QueryRow(ctx, `
		SELECT id, lab_id, task_version_id, user_id, org_id, container_id, container_host,
		       status, reset_count, score, is_test, started_at, expires_at, paused_seconds, paused_at,
		       completed_at, last_active_at, end_reason, provision_error
		FROM lab_sessions WHERE id=$1`, sessionID,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds, &s.PausedAt,
		&s.CompletedAt, &s.LastActiveAt, &s.EndReason, &s.ProvisionError,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetSessionByID: %w", err)
	}
	return &s, nil
}

// ListActiveSessions returns every non-test session the user currently has in
// an active state (provisioning/running/paused), across all labs, joined with
// the lab title/type for display. Used to let a user resume or end a lab after
// a page refresh or a fresh login, since that state otherwise only lives in
// the browser tab that launched it.
func (r *Repo) ListActiveSessions(ctx context.Context, userID string) ([]ActiveLabSession, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT s.id, s.lab_id, l.title, l.lab_type, s.status, s.started_at, s.expires_at, s.last_active_at
		FROM lab_sessions s
		JOIN lab_definitions l ON l.id = s.lab_id
		WHERE s.user_id=$1 AND s.is_test=false AND s.status IN ('provisioning','running','paused')
		ORDER BY s.last_active_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListActiveSessions: %w", err)
	}
	defer rows.Close()

	sessions := []ActiveLabSession{}
	for rows.Next() {
		var s ActiveLabSession
		if err := rows.Scan(
			&s.SessionID, &s.LabID, &s.LabTitle, &s.LabType,
			&s.Status, &s.StartedAt, &s.ExpiresAt, &s.LastActiveAt,
		); err != nil {
			return nil, fmt.Errorf("labs.Repo.ListActiveSessions: scan: %w", err)
		}
		sessions = append(sessions, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("labs.Repo.ListActiveSessions: rows: %w", err)
	}
	return sessions, nil
}

// GetActiveSessionForLab returns the active (provisioning/running/paused) session
// a user has for a specific lab, if one exists.
func (r *Repo) GetActiveSessionForLab(ctx context.Context, userID, labID string) (*LabSession, error) {
	var s LabSession
	err := r.pool.QueryRow(ctx, `
		SELECT id, lab_id, task_version_id, user_id, org_id, container_id, container_host,
		       status, reset_count, score, is_test, started_at, expires_at, paused_seconds, paused_at,
		       completed_at, last_active_at, end_reason
		FROM lab_sessions
		WHERE user_id=$1 AND lab_id=$2 AND status IN ('provisioning','running','paused')
		LIMIT 1`,
		userID, labID,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds, &s.PausedAt,
		&s.CompletedAt, &s.LastActiveAt, &s.EndReason,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetActiveSessionForLab: %w", err)
	}
	return &s, nil
}

// UpdateSessionRunning marks a session as running and records its container coordinates.
func (r *Repo) UpdateSessionRunning(ctx context.Context, sessionID, containerID, containerHost string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET status='running', container_id=$2, container_host=$3, last_active_at=now() WHERE id=$1",
		sessionID, containerID, containerHost,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionRunning: %w", err)
	}
	return nil
}

// SwapSessionContainer records a staged reset's replacement container
// coordinates: bumps reset_count, points container_id/container_host at the
// new sandbox, and clears any pause state (a reset always yields a running
// session regardless of what the old one's status was). Runs inside the same
// transaction as the completions wipe / score zero, so a reset is atomic:
// the student never observes a session pointed at the new container with the
// old score, or vice versa.
func (r *Repo) SwapSessionContainer(ctx context.Context, tx pgx.Tx, sessionID, containerID, containerHost string, resetCount int) error {
	if _, err := tx.Exec(ctx, `
		UPDATE lab_sessions
		SET container_id = $2, container_host = $3, reset_count = $4,
		    status = 'running', paused_at = NULL, last_active_at = now()
		WHERE id = $1`,
		sessionID, containerID, containerHost, resetCount,
	); err != nil {
		return fmt.Errorf("labs.Repo.SwapSessionContainer: %w", err)
	}
	return nil
}

// UpdateSessionRepoClone records the outcome of the Batch 3 lab-container
// auto-clone hook (see Service.runRepoClone) — status is one of
// 'cloned'/'failed'/'skipped' (migration 023's check constraint also allows
// 'pending', unused here since the clone runs synchronously inside
// provisionContainer before the session is ever reported ready).
func (r *Repo) UpdateSessionRepoClone(ctx context.Context, sessionID, status string, cloneErr *string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET repo_clone_status=$2, repo_clone_error=$3 WHERE id=$1",
		sessionID, status, cloneErr,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionRepoClone: %w", err)
	}
	return nil
}

// UpdateSessionStatus sets the session to an arbitrary status.
func (r *Repo) UpdateSessionStatus(ctx context.Context, sessionID, status string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET status=$2 WHERE id=$1",
		sessionID, status,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionStatus: %w", err)
	}
	return nil
}

// PauseSession flips a running session to paused and records when the pause
// began, so ResumeFromPause knows how much idle time to bill into
// paused_seconds. Guarded to only fire from 'running' — a session already
// paused, or one that raced to a terminal state, must not be touched.
func (r *Repo) PauseSession(ctx context.Context, sessionID string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET status='paused', paused_at=now() WHERE id=$1 AND status='running'",
		sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.PauseSession: %w", err)
	}
	return nil
}

// ResumeFromPause flips a paused session back to running, folding the
// just-ended pause into the cumulative paused_seconds cost counter. Guarded
// to only fire from 'paused' so an already-running session (a benign
// double-resume race) is a no-op rather than double-crediting the counter.
func (r *Repo) ResumeFromPause(ctx context.Context, sessionID string) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE lab_sessions
		SET status='running',
		    paused_seconds = paused_seconds + GREATEST(0, EXTRACT(EPOCH FROM (now() - paused_at))::int),
		    paused_at = NULL,
		    last_active_at = now()
		WHERE id=$1 AND status='paused'`,
		sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.ResumeFromPause: %w", err)
	}
	return nil
}

// UpdateSessionCompleted marks a session as completed inside a transaction,
// recording the completion timestamp. Score is deliberately NOT written here
// — it is already correct in the DB from MarkTaskPassed's atomic
// `score = score + $2`, which ran (in this same transaction) just before the
// caller decided the session is now complete. Accepting a score parameter
// and overwriting it with an in-memory value was the exact bug: the caller's
// copy of session.Score is a snapshot from whenever it was first loaded, so
// two concurrent verifies completing different tasks would both compute
// their own "final" total and the second write would silently erase the
// first task's points. Returns the authoritative post-write score so the
// caller doesn't need to guess it.
func (r *Repo) UpdateSessionCompleted(ctx context.Context, tx pgx.Tx, sessionID string) (score int, err error) {
	err = tx.QueryRow(ctx,
		"UPDATE lab_sessions SET status='completed', completed_at=now() WHERE id=$1 RETURNING score",
		sessionID,
	).Scan(&score)
	if err != nil {
		return 0, fmt.Errorf("labs.Repo.UpdateSessionCompleted: %w", err)
	}
	return score, nil
}

// UpdateSessionExpired marks a session as expired with the given end_reason
// — used by requireSessionLive's request-time deadline check. Guarded by
// "AND status <> 'expired'" purely to keep repeated calls (a session hit by
// several requests after its deadline before the reaper's next tick) from
// generating redundant writes; it is not a correctness requirement, since
// the update is idempotent either way.
func (r *Repo) UpdateSessionExpired(ctx context.Context, sessionID, endReason string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET status='expired', end_reason=$2 WHERE id=$1 AND status <> 'expired'",
		sessionID, endReason,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionExpired: %w", err)
	}
	return nil
}

// UpdateSessionFailed marks a session 'failed' with the reason it ended and,
// when known, the underlying error text — persisted so the cause survives
// past the ephemeral slog line that first reported it (mirrors
// UpdateSessionRepoClone's *string-error shape).
func (r *Repo) UpdateSessionFailed(ctx context.Context, sessionID, endReason string, provisionErr *string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET status='failed', end_reason=$2, provision_error=$3 WHERE id=$1",
		sessionID, endReason, provisionErr,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionFailed: %w", err)
	}
	return nil
}

// OrgOwnersAndAdmins returns the user IDs of every 'owner'/'admin' member of
// orgID — the recipients for a lab-provisioning-circuit-breaker notification
// (mirrors mentor_escalation.go's orgMentors query shape, scoped to the two
// roles who can actually act on a broken lab image/setup_script).
func (r *Repo) OrgOwnersAndAdmins(ctx context.Context, orgID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id FROM org_members WHERE org_id=$1 AND role IN ('owner', 'admin')`,
		orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.OrgOwnersAndAdmins: %w", err)
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("labs.Repo.OrgOwnersAndAdmins: scan: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("labs.Repo.OrgOwnersAndAdmins: rows: %w", err)
	}
	return ids, nil
}

// CountRecentProvisionFailures counts how many sessions for labID have
// failed to provision (end_reason IN provision_timeout/provision_failed)
// within the given window — the signal behind ErrLabProvisioningUnstable.
func (r *Repo) CountRecentProvisionFailures(ctx context.Context, labID string, window time.Duration) (int, error) {
	var n int
	if err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM lab_sessions
		 WHERE lab_id=$1
		   AND end_reason IN ('provision_timeout', 'provision_failed')
		   AND started_at > now() - $2::interval`,
		labID, fmt.Sprintf("%d seconds", int(window.Seconds())),
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("labs.Repo.CountRecentProvisionFailures: %w", err)
	}
	return n, nil
}

// UpdateLastActiveAt bumps the last_active_at heartbeat timestamp.
func (r *Repo) UpdateLastActiveAt(ctx context.Context, sessionID string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET last_active_at=now() WHERE id=$1", sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateLastActiveAt: %w", err)
	}
	return nil
}

// ResetTaskCompletions deletes all task completion rows for a session within a tx.
func (r *Repo) ResetTaskCompletions(ctx context.Context, tx pgx.Tx, sessionID string) error {
	if _, err := tx.Exec(ctx,
		"DELETE FROM lab_task_completions WHERE session_id=$1", sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.ResetTaskCompletions: %w", err)
	}
	return nil
}

// ZeroSessionScore resets score to 0 within a tx (used on lab reset).
func (r *Repo) ZeroSessionScore(ctx context.Context, tx pgx.Tx, sessionID string) error {
	if _, err := tx.Exec(ctx,
		"UPDATE lab_sessions SET score=0 WHERE id=$1", sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.ZeroSessionScore: %w", err)
	}
	return nil
}

// ─── Task completions ────────────────────────────────────────────────────────

// GetTaskCompletions returns all task completion records for a session, ordered
// by task_id.
func (r *Repo) GetTaskCompletions(ctx context.Context, sessionID string) ([]LabTaskCompletion, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT id, session_id, task_version_item_id, status, attempts, hints_used, completed_at FROM lab_task_completions WHERE session_id=$1 ORDER BY task_version_item_id",
		sessionID,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.GetTaskCompletions: %w", err)
	}
	defer rows.Close()
	completions := make([]LabTaskCompletion, 0)
	for rows.Next() {
		var c LabTaskCompletion
		if err := rows.Scan(&c.ID, &c.SessionID, &c.TaskID, &c.Status, &c.Attempts, &c.HintsUsed, &c.CompletedAt); err != nil {
			return nil, fmt.Errorf("labs.Repo.GetTaskCompletions: scan: %w", err)
		}
		completions = append(completions, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("labs.Repo.GetTaskCompletions: rows: %w", err)
	}
	return completions, nil
}

// EnsureTaskCompletion creates a task completion record if one does not exist,
// using ON CONFLICT DO NOTHING for idempotency.
func (r *Repo) EnsureTaskCompletion(ctx context.Context, sessionID, taskID string) error {
	if _, err := r.pool.Exec(ctx,
		"INSERT INTO lab_task_completions (session_id, task_version_item_id) VALUES ($1,$2) ON CONFLICT (session_id, task_version_item_id) DO NOTHING",
		sessionID, taskID,
	); err != nil {
		return fmt.Errorf("labs.Repo.EnsureTaskCompletion: %w", err)
	}
	return nil
}

// IncrementTaskAttempts atomically increments the attempt counter and returns
// the new value.
func (r *Repo) IncrementTaskAttempts(ctx context.Context, sessionID, taskID string) (int, error) {
	var attempts int
	if err := r.pool.QueryRow(ctx,
		"UPDATE lab_task_completions SET attempts = attempts + 1 WHERE session_id=$1 AND task_version_item_id=$2 RETURNING attempts",
		sessionID, taskID,
	).Scan(&attempts); err != nil {
		return 0, fmt.Errorf("labs.Repo.IncrementTaskAttempts: %w", err)
	}
	return attempts, nil
}

// MarkTaskPassed sets a task completion to passed inside a transaction. Returns
// ErrTaskAlreadyPassed when the row was not in the pending state.
// scoreAdded is the points earned after applying the hint penalty.
func (r *Repo) MarkTaskPassed(ctx context.Context, tx pgx.Tx, sessionID, taskID string, points, hintsUsed, hintPenaltyPct int) (scoreAdded int, err error) {
	scoreAdded = max(0, points-(hintsUsed*points*hintPenaltyPct/100))

	tag, err := tx.Exec(ctx,
		"UPDATE lab_task_completions SET status='passed', completed_at=now() WHERE session_id=$1 AND task_version_item_id=$2 AND status='pending'",
		sessionID, taskID,
	)
	if err != nil {
		return 0, fmt.Errorf("labs.Repo.MarkTaskPassed: update completion: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return 0, ErrTaskAlreadyPassed
	}

	if _, err := tx.Exec(ctx,
		"UPDATE lab_sessions SET score = score + $2 WHERE id=$1",
		sessionID, scoreAdded,
	); err != nil {
		return 0, fmt.Errorf("labs.Repo.MarkTaskPassed: update score: %w", err)
	}

	return scoreAdded, nil
}

// MarkTaskSkipped sets a pending task completion to skipped.
func (r *Repo) MarkTaskSkipped(ctx context.Context, sessionID, taskID string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_task_completions SET status='skipped' WHERE session_id=$1 AND task_version_item_id=$2 AND status='pending'",
		sessionID, taskID,
	); err != nil {
		return fmt.Errorf("labs.Repo.MarkTaskSkipped: %w", err)
	}
	return nil
}

// IncrementHintsUsed atomically increments hints_used and returns the new value.
func (r *Repo) IncrementHintsUsed(ctx context.Context, sessionID, taskID string) (int, error) {
	var hintsUsed int
	if err := r.pool.QueryRow(ctx,
		"UPDATE lab_task_completions SET hints_used = hints_used + 1 WHERE session_id=$1 AND task_version_item_id=$2 RETURNING hints_used",
		sessionID, taskID,
	).Scan(&hintsUsed); err != nil {
		return 0, fmt.Errorf("labs.Repo.IncrementHintsUsed: %w", err)
	}
	return hintsUsed, nil
}

// rowQuerier is satisfied by both *pgxpool.Pool and pgx.Tx, so
// CountPassedNonOptionalTasks can run either as a standalone read (EndSession)
// or against an in-flight transaction (finalizeTaskPass's completion check,
// which must see that same transaction's just-written MarkTaskPassed row —
// querying via the pool instead would hit a different connection and see
// pre-commit, stale state).
type rowQuerier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// CountPassedNonOptionalTasks counts how many of the given task IDs have a
// passed completion record for the session, via q (either r.pool for a
// standalone read or an open tx to see uncommitted writes in the same
// transaction).
func (r *Repo) CountPassedNonOptionalTasks(ctx context.Context, q rowQuerier, sessionID string, nonOptionalTaskIDs []string) (int, error) {
	if len(nonOptionalTaskIDs) == 0 {
		return 0, nil
	}
	var count int
	if err := q.QueryRow(ctx,
		"SELECT COUNT(*) FROM lab_task_completions WHERE session_id=$1 AND task_version_item_id = ANY($2) AND status='passed'",
		sessionID, nonOptionalTaskIDs,
	).Scan(&count); err != nil {
		return 0, fmt.Errorf("labs.Repo.CountPassedNonOptionalTasks: %w", err)
	}
	return count, nil
}

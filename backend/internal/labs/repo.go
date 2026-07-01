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
		SELECT id, org_id, course_id, module_id, scope, title, description, lab_type, environment,
		       setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published,
		       published_version_id, created_by, created_at, updated_at
		FROM lab_definitions WHERE id=$1 AND org_id=$2`,
		labID, orgID,
	).Scan(
		&l.ID, &l.OrgID, &l.CourseID, &l.ModuleID, &l.Scope, &l.Title, &l.Description,
		&l.LabType, &l.Environment, &l.SetupScript, &l.MaxDuration, &l.MaxResets,
		&l.HintPenaltyPct, &l.IsRequired, &l.IsPublished, &l.PublishedVersionID,
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
		SELECT id, org_id, course_id, module_id, scope, title, description, lab_type, environment,
		       setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published,
		       published_version_id, created_by, created_at, updated_at
		FROM lab_definitions WHERE module_id=$1 AND org_id=$2 AND is_published=true
		LIMIT 1`,
		moduleID, orgID,
	).Scan(
		&l.ID, &l.OrgID, &l.CourseID, &l.ModuleID, &l.Scope, &l.Title, &l.Description,
		&l.LabType, &l.Environment, &l.SetupScript, &l.MaxDuration, &l.MaxResets,
		&l.HintPenaltyPct, &l.IsRequired, &l.IsPublished, &l.PublishedVersionID,
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

// GetPublishedVersion loads the task snapshot array from a task version row.
func (r *Repo) GetPublishedVersion(ctx context.Context, versionID string) ([]TaskSnapshot, error) {
	var raw json.RawMessage
	err := r.pool.QueryRow(ctx,
		"SELECT tasks FROM lab_task_versions WHERE id=$1", versionID,
	).Scan(&raw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetPublishedVersion: %w", err)
	}
	var tasks []TaskSnapshot
	if err := json.Unmarshal(raw, &tasks); err != nil {
		return nil, fmt.Errorf("labs.Repo.GetPublishedVersion: unmarshal: %w", err)
	}
	return tasks, nil
}

// ─── Org config ──────────────────────────────────────────────────────────────

// GetOrgConfig loads org-level lab config. Missing rows return platform defaults
// with nil error.
func (r *Repo) GetOrgConfig(ctx context.Context, orgID string) (LabOrgConfig, error) {
	var cfg LabOrgConfig
	err := r.pool.QueryRow(ctx, `
		SELECT org_id, max_concurrent_sessions, max_session_duration,
		       COALESCE(allowed_images, '{}'), egress_proxy_enabled, updated_at
		FROM lab_org_config WHERE org_id=$1`, orgID,
	).Scan(&cfg.OrgID, &cfg.MaxConcurrentSessions, &cfg.MaxSessionDuration,
		&cfg.AllowedImages, &cfg.EgressProxyEnabled, &cfg.UpdatedAt)
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
		          status, reset_count, score, is_test, started_at, expires_at, paused_seconds,
		          completed_at, last_active_at`,
		params.LabID, params.TaskVersionID, params.UserID, params.OrgID,
		params.ExpiresAt, params.IsTest,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds,
		&s.CompletedAt, &s.LastActiveAt,
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
		       status, reset_count, score, is_test, started_at, expires_at, paused_seconds,
		       completed_at, last_active_at
		FROM lab_sessions WHERE id=$1 AND user_id=$2`,
		sessionID, userID,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds,
		&s.CompletedAt, &s.LastActiveAt,
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
		       status, reset_count, score, is_test, started_at, expires_at, paused_seconds,
		       completed_at, last_active_at
		FROM lab_sessions WHERE id=$1`, sessionID,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds,
		&s.CompletedAt, &s.LastActiveAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("labs.Repo.GetSessionByID: %w", err)
	}
	return &s, nil
}

// GetActiveSessionForLab returns the active (provisioning/running/paused) session
// a user has for a specific lab, if one exists.
func (r *Repo) GetActiveSessionForLab(ctx context.Context, userID, labID string) (*LabSession, error) {
	var s LabSession
	err := r.pool.QueryRow(ctx, `
		SELECT id, lab_id, task_version_id, user_id, org_id, container_id, container_host,
		       status, reset_count, score, is_test, started_at, expires_at, paused_seconds,
		       completed_at, last_active_at
		FROM lab_sessions
		WHERE user_id=$1 AND lab_id=$2 AND status IN ('provisioning','running','paused')
		LIMIT 1`,
		userID, labID,
	).Scan(
		&s.ID, &s.LabID, &s.TaskVersionID, &s.UserID, &s.OrgID,
		&s.ContainerID, &s.ContainerHost, &s.Status, &s.ResetCount, &s.Score,
		&s.IsTest, &s.StartedAt, &s.ExpiresAt, &s.PausedSeconds,
		&s.CompletedAt, &s.LastActiveAt,
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

// UpdateSessionCompleted marks a session as completed inside a transaction,
// recording the final score and completion timestamp.
func (r *Repo) UpdateSessionCompleted(ctx context.Context, tx pgx.Tx, sessionID string, score int) error {
	if _, err := tx.Exec(ctx,
		"UPDATE lab_sessions SET status='completed', completed_at=now(), score=$2 WHERE id=$1",
		sessionID, score,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionCompleted: %w", err)
	}
	return nil
}

// UpdateSessionExpired marks a session as expired.
func (r *Repo) UpdateSessionExpired(ctx context.Context, sessionID string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET status='expired' WHERE id=$1", sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpdateSessionExpired: %w", err)
	}
	return nil
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

// IncrementResetCount atomically increments the reset counter for a session.
func (r *Repo) IncrementResetCount(ctx context.Context, sessionID string) error {
	if _, err := r.pool.Exec(ctx,
		"UPDATE lab_sessions SET reset_count = reset_count + 1 WHERE id=$1", sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.IncrementResetCount: %w", err)
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

// ─── Concurrency helpers ─────────────────────────────────────────────────────

// CountActiveSessions returns the number of active sessions for an org.
func (r *Repo) CountActiveSessions(ctx context.Context, orgID string) (int, error) {
	var count int
	if err := r.pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM lab_sessions WHERE org_id=$1 AND status IN ('provisioning','running','paused')",
		orgID,
	).Scan(&count); err != nil {
		return 0, fmt.Errorf("labs.Repo.CountActiveSessions: %w", err)
	}
	return count, nil
}

// CountActiveSessionsForUser returns the number of active sessions a user has
// across all labs.
func (r *Repo) CountActiveSessionsForUser(ctx context.Context, userID string) (int, error) {
	var count int
	if err := r.pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM lab_sessions WHERE user_id=$1 AND status IN ('provisioning','running','paused')",
		userID,
	).Scan(&count); err != nil {
		return 0, fmt.Errorf("labs.Repo.CountActiveSessionsForUser: %w", err)
	}
	return count, nil
}

// ─── Task completions ────────────────────────────────────────────────────────

// GetTaskCompletions returns all task completion records for a session, ordered
// by task_id.
func (r *Repo) GetTaskCompletions(ctx context.Context, sessionID string) ([]LabTaskCompletion, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT id, session_id, task_id, status, attempts, hints_used, completed_at FROM lab_task_completions WHERE session_id=$1 ORDER BY task_id",
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
		"INSERT INTO lab_task_completions (session_id, task_id) VALUES ($1,$2) ON CONFLICT (session_id, task_id) DO NOTHING",
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
		"UPDATE lab_task_completions SET attempts = attempts + 1 WHERE session_id=$1 AND task_id=$2 RETURNING attempts",
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
		"UPDATE lab_task_completions SET status='passed', completed_at=now() WHERE session_id=$1 AND task_id=$2 AND status='pending'",
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
		"UPDATE lab_task_completions SET status='skipped' WHERE session_id=$1 AND task_id=$2 AND status='pending'",
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
		"UPDATE lab_task_completions SET hints_used = hints_used + 1 WHERE session_id=$1 AND task_id=$2 RETURNING hints_used",
		sessionID, taskID,
	).Scan(&hintsUsed); err != nil {
		return 0, fmt.Errorf("labs.Repo.IncrementHintsUsed: %w", err)
	}
	return hintsUsed, nil
}

// CountPassedNonOptionalTasks counts how many of the given task IDs have a
// passed completion record for the session.
func (r *Repo) CountPassedNonOptionalTasks(ctx context.Context, sessionID string, nonOptionalTaskIDs []string) (int, error) {
	if len(nonOptionalTaskIDs) == 0 {
		return 0, nil
	}
	var count int
	if err := r.pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM lab_task_completions WHERE session_id=$1 AND task_id = ANY($2) AND status='passed'",
		sessionID, nonOptionalTaskIDs,
	).Scan(&count); err != nil {
		return 0, fmt.Errorf("labs.Repo.CountPassedNonOptionalTasks: %w", err)
	}
	return count, nil
}

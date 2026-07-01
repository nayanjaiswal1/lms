package labs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// VerifyResult is the payload returned to the caller after a task verify attempt.
type VerifyResult struct {
	Passed           bool   `json:"passed"`
	Attempts         int    `json:"attempts"`
	ScoreAdded       int    `json:"score_added"`
	Stdout           string `json:"stdout,omitempty"`
	Stderr           string `json:"stderr,omitempty"`
	SessionCompleted bool   `json:"session_completed"`
}

// Service holds the business logic for the labs domain.
type Service struct {
	repo      *Repo
	container *ContainerService
	rdb       *redis.Client
	pool      *pgxpool.Pool
	piston    *labPiston
}

// NewService wires up the labs service.
func NewService(repo *Repo, container *ContainerService, rdb *redis.Client, pool *pgxpool.Pool, piston *labPiston) *Service {
	return &Service{repo: repo, container: container, rdb: rdb, pool: pool, piston: piston}
}

// wsTokenClaims is the JWT payload issued by MintWSToken.
type wsTokenClaims struct {
	SessionID string `json:"session_id"`
	UserID    string `json:"user_id"`
	jwt.RegisteredClaims
}

// ─── StartSession ─────────────────────────────────────────────────────────────

// StartSession provisions a new lab session for the given user. Idempotent: a
// non-empty idempotencyKey causes a duplicate request to return the original
// session unchanged. When an active session already exists for the same
// user+lab, the existing session is returned rather than an error.
func (s *Service) StartSession(ctx context.Context, labID, userID, orgID string, isTest bool, idempotencyKey string) (*LabSession, error) {
	// 1. Load lab and verify it exists in this org.
	lab, err := s.repo.GetLab(ctx, labID, orgID)
	if err != nil {
		return nil, err
	}

	// 2. Require a published version before allowing session starts.
	if !lab.IsPublished || lab.PublishedVersionID == nil {
		return nil, ErrLabNotPublished
	}

	// 3. Check idempotency key — return the existing session if present.
	if idempotencyKey != "" {
		if val, redisErr := s.rdb.Get(ctx, "lab:idem:"+idempotencyKey).Result(); redisErr == nil && val != "" {
			existing, err := s.repo.GetSessionByID(ctx, val)
			if err != nil {
				return nil, fmt.Errorf("labs.Service.StartSession: resolve idempotency: %w", err)
			}
			return existing, nil
		}
	}

	// 4. Load org config (falls back to platform defaults on missing row).
	orgCfg, err := s.repo.GetOrgConfig(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.StartSession: get org config: %w", err)
	}

	// 5. Advisory lock + concurrency checks + insert — all in one transaction.
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.StartSession: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Hold a transaction-scoped advisory lock keyed on the org. Any concurrent
	// StartSession call for the same org blocks here until the first commits.
	if _, err := tx.Exec(ctx, "SELECT pg_advisory_xact_lock(hashtext($1)::bigint)", orgID); err != nil {
		return nil, fmt.Errorf("labs.Service.StartSession: advisory lock: %w", err)
	}

	if !isTest {
		var orgCount int
		if err := tx.QueryRow(ctx,
			"SELECT COUNT(*) FROM lab_sessions WHERE org_id=$1 AND status IN ('provisioning','running','paused')",
			orgID,
		).Scan(&orgCount); err != nil {
			return nil, fmt.Errorf("labs.Service.StartSession: count org sessions: %w", err)
		}
		if orgCount >= orgCfg.MaxConcurrentSessions {
			return nil, ErrCapacityReached
		}

		var userCount int
		if err := tx.QueryRow(ctx,
			"SELECT COUNT(*) FROM lab_sessions WHERE user_id=$1 AND status IN ('provisioning','running','paused')",
			userID,
		).Scan(&userCount); err != nil {
			return nil, fmt.Errorf("labs.Service.StartSession: count user sessions: %w", err)
		}
		if userCount >= 2 {
			return nil, ErrCapacityReached
		}
	}

	// Return the existing active session if one is found — no error for the caller.
	var activeSessionID string
	scanErr := tx.QueryRow(ctx,
		"SELECT id FROM lab_sessions WHERE user_id=$1 AND lab_id=$2 AND status IN ('provisioning','running','paused') LIMIT 1",
		userID, labID,
	).Scan(&activeSessionID)
	if scanErr == nil {
		existing, err := s.repo.GetSessionByID(ctx, activeSessionID)
		if err != nil {
			return nil, fmt.Errorf("labs.Service.StartSession: fetch active session: %w", err)
		}
		return existing, nil
	}
	if !errors.Is(scanErr, pgx.ErrNoRows) {
		return nil, fmt.Errorf("labs.Service.StartSession: check active session: %w", scanErr)
	}

	expiresAt := time.Now().Add(time.Duration(orgCfg.MaxSessionDuration) * time.Minute)
	session, err := s.repo.CreateSession(ctx, tx, CreateSessionParams{
		LabID:         labID,
		TaskVersionID: *lab.PublishedVersionID,
		UserID:        userID,
		OrgID:         orgID,
		ExpiresAt:     expiresAt,
		IsTest:        isTest,
	})
	if err != nil {
		if errors.Is(err, ErrSessionActive) {
			// Unique index fired concurrently — fetch the winner.
			existing, err := s.repo.GetActiveSessionForLab(ctx, userID, labID)
			if err != nil {
				return nil, fmt.Errorf("labs.Service.StartSession: resolve race: %w", err)
			}
			return existing, nil
		}
		return nil, fmt.Errorf("labs.Service.StartSession: create session: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("labs.Service.StartSession: commit: %w", err)
	}

	// 6. Persist idempotency key for 10 minutes.
	if idempotencyKey != "" {
		if err := s.rdb.Set(ctx, "lab:idem:"+idempotencyKey, session.ID, 10*time.Minute).Err(); err != nil {
			slog.Error("labs.Service.StartSession: store idempotency key", "error", err)
		}
	}

	// 7. Code-type labs need no container — mark running immediately.
	//    All other types provision a Docker container asynchronously.
	if lab.LabType == LabTypeCode {
		if err := s.repo.UpdateSessionStatus(ctx, session.ID, SessionStatusRunning); err != nil {
			slog.Error("labs.Service.StartSession: set code lab running", "session_id", session.ID, "error", err)
		}
		session.Status = SessionStatusRunning
	} else {
		go s.provisionContainer(context.Background(), session, lab)
	}

	return session, nil
}

// provisionContainer runs in a goroutine. It starts the Docker container,
// records the coordinates in the DB, and publishes a readiness event via Redis.
func (s *Service) provisionContainer(ctx context.Context, session *LabSession, lab *LabDefinition) {
	ctx, cancel := context.WithTimeout(ctx, ProvisionTimeoutSeconds*time.Second)
	defer cancel()

	var setupScript string
	if lab.SetupScript != nil {
		setupScript = *lab.SetupScript
	}

	containerID, containerHost, err := s.container.Start(ctx, session.ID, session.ResetCount, lab.Environment, setupScript)
	if err != nil {
		slog.Error("labs.Service.provisionContainer: start container", "session_id", session.ID, "error", err)
		bgCtx := context.Background()
		if updateErr := s.repo.UpdateSessionStatus(bgCtx, session.ID, SessionStatusFailed); updateErr != nil {
			slog.Error("labs.Service.provisionContainer: mark failed", "session_id", session.ID, "error", updateErr)
		}
		if pubErr := s.rdb.Publish(bgCtx, "lab:events:"+session.ID, "failed").Err(); pubErr != nil {
			slog.Error("labs.Service.provisionContainer: publish failed", "session_id", session.ID, "error", pubErr)
		}
		return
	}

	bgCtx := context.Background()
	if err := s.repo.UpdateSessionRunning(bgCtx, session.ID, containerID, containerHost); err != nil {
		slog.Error("labs.Service.provisionContainer: update running", "session_id", session.ID, "error", err)
	}
	if err := s.rdb.Publish(bgCtx, "lab:events:"+session.ID, "ready").Err(); err != nil {
		slog.Error("labs.Service.provisionContainer: publish ready", "session_id", session.ID, "error", err)
	}
}

// ─── GetSession ───────────────────────────────────────────────────────────────

// GetSession loads a session and its task completions. The user_id check in
// GetSession enforces IDOR protection.
func (s *Service) GetSession(ctx context.Context, sessionID, userID string) (*LabSession, []LabTaskCompletion, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, nil, err
	}
	completions, err := s.repo.GetTaskCompletions(ctx, sessionID)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.GetSession: completions: %w", err)
	}
	return session, completions, nil
}

// ─── MintWSToken ──────────────────────────────────────────────────────────────

// MintWSToken issues a short-lived JWT for authenticating the WebSocket
// connection to the in-browser terminal. The token is stored in Redis so the
// terminal proxy can verify it independently.
func (s *Service) MintWSToken(ctx context.Context, sessionID, userID, jwtSecret, jwtIssuer string) (string, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return "", err
	}
	if session.Status != SessionStatusRunning {
		return "", ErrSessionNotRunning
	}

	now := time.Now()
	claims := wsTokenClaims{
		SessionID: sessionID,
		UserID:    userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(5 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(now),
			Issuer:    jwtIssuer,
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(jwtSecret))
	if err != nil {
		return "", fmt.Errorf("labs.Service.MintWSToken: sign: %w", err)
	}

	if err := s.rdb.Set(ctx, "lab:wstoken:"+tokenStr, sessionID, 5*time.Minute).Err(); err != nil {
		slog.Error("labs.Service.MintWSToken: store token", "session_id", sessionID, "error", err)
	}

	return tokenStr, nil
}

// ─── EndSession ───────────────────────────────────────────────────────────────

// EndSession terminates an active session. It computes whether all required
// (non-optional) tasks were passed and marks the session completed or expired
// accordingly.
func (s *Service) EndSession(ctx context.Context, sessionID, userID string) error {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return err
	}

	switch session.Status {
	case SessionStatusCompleted, SessionStatusExpired, SessionStatusFailed, SessionStatusTerminatedAbuse:
		return ErrSessionTerminal
	}

	// Load the frozen task list from the pinned version to compute required tasks.
	tasks, err := s.repo.GetPublishedVersion(ctx, session.TaskVersionID)
	if err != nil {
		return fmt.Errorf("labs.Service.EndSession: get task version: %w", err)
	}

	nonOptionalIDs := make([]string, 0, len(tasks))
	for _, t := range tasks {
		if !t.IsOptional {
			nonOptionalIDs = append(nonOptionalIDs, t.ID)
		}
	}

	passedCount, err := s.repo.CountPassedNonOptionalTasks(ctx, sessionID, nonOptionalIDs)
	if err != nil {
		return fmt.Errorf("labs.Service.EndSession: count passed: %w", err)
	}

	terminalStatus := SessionStatusExpired
	if len(nonOptionalIDs) == 0 || passedCount >= len(nonOptionalIDs) {
		terminalStatus = SessionStatusCompleted
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("labs.Service.EndSession: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if terminalStatus == SessionStatusCompleted {
		if err := s.repo.UpdateSessionCompleted(ctx, tx, sessionID, session.Score); err != nil {
			return fmt.Errorf("labs.Service.EndSession: update completed: %w", err)
		}
	} else {
		if _, err := tx.Exec(ctx, "UPDATE lab_sessions SET status='expired' WHERE id=$1", sessionID); err != nil {
			return fmt.Errorf("labs.Service.EndSession: update expired: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("labs.Service.EndSession: commit: %w", err)
	}

	if session.ContainerID != nil {
		go s.container.Kill(context.Background(), *session.ContainerID)
	}

	return nil
}

// ─── ResetSession ─────────────────────────────────────────────────────────────

// ResetSession clears all task completions and zeroes the session score,
// consuming one of the lab's allowed resets.
func (s *Service) ResetSession(ctx context.Context, sessionID, userID string) (*LabSession, []LabTaskCompletion, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, nil, err
	}
	if session.Status != SessionStatusRunning {
		return nil, nil, ErrSessionNotRunning
	}

	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.ResetSession: get lab: %w", err)
	}
	if session.ResetCount >= lab.MaxResets {
		return nil, nil, ErrMaxResetsReached
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.ResetSession: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := s.repo.ResetTaskCompletions(ctx, tx, sessionID); err != nil {
		return nil, nil, err
	}
	if err := s.repo.ZeroSessionScore(ctx, tx, sessionID); err != nil {
		return nil, nil, err
	}
	if _, err := tx.Exec(ctx,
		"UPDATE lab_sessions SET reset_count = reset_count + 1 WHERE id=$1", sessionID,
	); err != nil {
		return nil, nil, fmt.Errorf("labs.Service.ResetSession: increment reset: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("labs.Service.ResetSession: commit: %w", err)
	}

	refreshed, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.ResetSession: reload: %w", err)
	}
	return refreshed, []LabTaskCompletion{}, nil
}

// ─── WaitForReadiness ────────────────────────────────────────────────────────

// ─── VerifyTask ───────────────────────────────────────────────────────────────

// VerifyTask verifies a single code-lab task by running the student's code
// through Piston. Attempts are incremented atomically, the task is marked
// passed and the session score updated on success, and a full-completion
// check is performed inside a single DB transaction.
func (s *Service) VerifyTask(ctx context.Context, sessionID, taskID, userID, code, language string) (*VerifyResult, error) {
	// 1. IDOR + running check.
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	if session.Status != SessionStatusRunning {
		return nil, ErrSessionNotRunning
	}

	// 2. Rate-limit per (session, task): one attempt every VerifyRateLimitSeconds.
	rateLimitKey := fmt.Sprintf("lab:verify:rate:%s:%s", sessionID, taskID)
	set, rErr := s.rdb.SetNX(ctx, rateLimitKey, 1, time.Duration(VerifyRateLimitSeconds)*time.Second).Result()
	if rErr != nil {
		slog.Error("labs.Service.VerifyTask: rate limit check", "error", rErr)
	} else if !set {
		return nil, ErrRateLimited
	}

	// 3. Load the pinned task snapshot for this session.
	tasks, err := s.repo.GetPublishedVersion(ctx, session.TaskVersionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: get version: %w", err)
	}
	var task *TaskSnapshot
	for i := range tasks {
		if tasks[i].ID == taskID {
			task = &tasks[i]
			break
		}
	}
	if task == nil {
		return nil, ErrNotFound
	}

	// 4. Ensure a completion row exists (idempotent upsert).
	if err := s.repo.EnsureTaskCompletion(ctx, sessionID, taskID); err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: ensure completion: %w", err)
	}

	// 5. Atomically increment attempts (read-modify-write free — DB does it).
	attempts, err := s.repo.IncrementTaskAttempts(ctx, sessionID, taskID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: increment attempts: %w", err)
	}

	// 6. Execute: concatenate student code + verification harness into one file.
	combined := code + "\n\n" + task.VerificationScript
	execCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	passed, stdout, stderr, execErr := s.piston.Execute(execCtx, language, combined)
	if execErr != nil {
		if errors.Is(execErr, ErrExecutorUnavailable) {
			return nil, ErrExecutorUnavailable
		}
		slog.Error("labs.Service.VerifyTask: execute", "error", execErr)
		return &VerifyResult{Passed: false, Attempts: attempts, Stderr: execErr.Error()}, nil
	}

	if !passed {
		return &VerifyResult{Passed: false, Attempts: attempts, Stdout: stdout, Stderr: stderr}, nil
	}

	// 7. On pass: mark passed + update score in one transaction; check full completion.
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: get lab: %w", err)
	}

	completionRows, err := s.repo.GetTaskCompletions(ctx, sessionID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: get completions: %w", err)
	}
	var hintsUsed int
	for _, c := range completionRows {
		if c.TaskID == taskID {
			hintsUsed = c.HintsUsed
			break
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	scoreAdded, err := s.repo.MarkTaskPassed(ctx, tx, sessionID, taskID, task.Points, hintsUsed, lab.HintPenaltyPct)
	if err != nil {
		if errors.Is(err, ErrTaskAlreadyPassed) {
			return &VerifyResult{Passed: true, Attempts: attempts, Stdout: stdout, Stderr: stderr}, nil
		}
		return nil, fmt.Errorf("labs.Service.VerifyTask: mark passed: %w", err)
	}

	// Full-completion check: SELECT FOR UPDATE guards against two concurrent verifies
	// both flipping the session to completed.
	var lockedID string
	if err := tx.QueryRow(ctx, "SELECT id FROM lab_sessions WHERE id=$1 FOR UPDATE", sessionID).Scan(&lockedID); err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: lock session: %w", err)
	}

	nonOptionalIDs := make([]string, 0, len(tasks))
	for _, t := range tasks {
		if !t.IsOptional {
			nonOptionalIDs = append(nonOptionalIDs, t.ID)
		}
	}
	passedCount, err := s.repo.CountPassedNonOptionalTasks(ctx, sessionID, nonOptionalIDs)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: count passed: %w", err)
	}

	sessionCompleted := len(nonOptionalIDs) > 0 && passedCount >= len(nonOptionalIDs)
	if sessionCompleted {
		newScore := session.Score + scoreAdded
		if err := s.repo.UpdateSessionCompleted(ctx, tx, sessionID, newScore); err != nil {
			return nil, fmt.Errorf("labs.Service.VerifyTask: complete session: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: commit: %w", err)
	}

	return &VerifyResult{
		Passed:           true,
		Attempts:         attempts,
		ScoreAdded:       scoreAdded,
		Stdout:           stdout,
		SessionCompleted: sessionCompleted,
	}, nil
}

// ─── WaitForReadiness ────────────────────────────────────────────────────────

// WaitForReadiness streams Server-Sent Events until the session container is
// ready or has failed. It subscribes to a Redis channel published by the
// provisioning goroutine and polls the DB every 2 s as a fallback in case the
// pub/sub message was missed.
func (s *Service) WaitForReadiness(ctx context.Context, w http.ResponseWriter, sessionID string) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	// Fast path: session may already be running or failed before we even subscribe.
	if session, err := s.repo.GetSessionByID(ctx, sessionID); err == nil {
		switch session.Status {
		case SessionStatusRunning:
			fmt.Fprintf(w, "data: {\"type\":\"ready\"}\n\n")
			flusher.Flush()
			return
		case SessionStatusFailed:
			fmt.Fprintf(w, "data: {\"type\":\"failed\"}\n\n")
			flusher.Flush()
			return
		}
	}

	pubsub := s.rdb.Subscribe(ctx, "lab:events:"+sessionID)
	defer pubsub.Close()

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-pubsub.Channel():
			if !ok {
				return
			}
			switch msg.Payload {
			case "ready":
				fmt.Fprintf(w, "data: {\"type\":\"ready\"}\n\n")
				flusher.Flush()
				return
			case "failed":
				fmt.Fprintf(w, "data: {\"type\":\"failed\"}\n\n")
				flusher.Flush()
				return
			}
		case <-ticker.C:
			session, err := s.repo.GetSessionByID(ctx, sessionID)
			if err != nil {
				slog.Error("labs.Service.WaitForReadiness: poll session", "session_id", sessionID, "error", err)
				return
			}
			switch session.Status {
			case SessionStatusRunning:
				fmt.Fprintf(w, "data: {\"type\":\"ready\"}\n\n")
				flusher.Flush()
				return
			case SessionStatusFailed:
				fmt.Fprintf(w, "data: {\"type\":\"failed\"}\n\n")
				flusher.Flush()
				return
			}
		}
	}
}

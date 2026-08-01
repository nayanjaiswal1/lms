package labs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"slices"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/notifications"
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

// RepoPreparer is the optional dependency behind the Batch 3 lab-container
// auto-clone hook — satisfied by *gitlab.Service, nil when GitLab isn't
// configured for this deploy. Defined here (in labs, the consumer) rather
// than imported from internal/gitlab, the same nil-safe-optional-dependency
// shape assessment.New's SandboxRuntime param already uses: PrepareLabRepo
// returns an empty script with a nil error to mean "skip, nothing to clone"
// (no project_team_id on the session, no GitLab connection for this user,
// GitLab not configured at all, etc.) — that is not an error, only a
// non-nil error is. The returned script is run verbatim via the session's
// own container.Exec.
type RepoPreparer interface {
	PrepareLabRepo(ctx context.Context, sessionID, userID, labID string) (script string, err error)
}

// Service holds the business logic for the labs domain.
type Service struct {
	repo          *Repo
	container     ContainerRuntime
	rdb           *redis.Client
	pool          *pgxpool.Pool
	piston        *labPiston
	coursesSvc    *courses.Service
	repoPreparer  RepoPreparer
	notifications *notifications.Service
}

// NewService wires up the labs service. coursesSvc completes the course module
// wrapping a lab (if any) once its session finishes — see VerifyTask.
// repoPreparer may be nil (GitLab integration not configured for this
// deploy) — see RepoPreparer's own doc comment. notifSvc backs
// notifyRepeatedProvisionFailures (org owners/admins, in-app + email on a
// lab's provisioning circuit breaker tripping).
func NewService(repo *Repo, container ContainerRuntime, rdb *redis.Client, pool *pgxpool.Pool, piston *labPiston, coursesSvc *courses.Service, repoPreparer RepoPreparer, notifSvc *notifications.Service) *Service {
	return &Service{repo: repo, container: container, rdb: rdb, pool: pool, piston: piston, coursesSvc: coursesSvc, repoPreparer: repoPreparer, notifications: notifSvc}
}

// WSTokenType is the wsTokenClaims.Type value labproxy requires. labproxy
// and the main API share one JWT signing secret (LABPROXY_JWT_SECRET =
// JWT_SECRET) with only the Issuer string distinguishing a lab WS token from
// a main-app access token — a config slip that points both processes at the
// same issuer string would otherwise make an ordinary login token pass
// validateWSToken. A dedicated `typ` claim, checked in addition to Issuer,
// closes that gap: it's a value that only ever appears on a token minted by
// MintWSToken, never on any other token type this codebase issues.
const WSTokenType = "lab_ws"

// wsTokenClaims is the JWT payload issued by MintWSToken.
type wsTokenClaims struct {
	SessionID string `json:"session_id"`
	UserID    string `json:"user_id"`
	Type      string `json:"typ"`
	jwt.RegisteredClaims
}

// ─── StartSession ─────────────────────────────────────────────────────────────

// StartSession provisions a new lab session for the given user. Idempotent: a
// non-empty idempotencyKey causes a duplicate request to return the original
// session, but ONLY while that session is still non-terminal — see the
// idempotency-key check below for why a terminal hit falls through to a
// fresh start instead of being returned. When an active session already
// exists for the same user+lab, the existing session is returned rather than
// an error.
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

	// 3. Check idempotency key — return the existing session if present AND
	// still non-terminal. The cached session ID lives for 10 minutes
	// (matching typical client retry/backoff windows), but a session's own
	// lifecycle is usually much shorter than that: it's entirely possible to
	// start, finish, and end a short lab well within the same 10-minute
	// window. Returning a completed/expired/failed session here would hand
	// the caller a dead container_id it can never reconnect to — the
	// idempotency cache exists to dedupe an in-flight start, not to resurrect
	// one that already ran its course. A terminal hit clears the stale key
	// and falls through to provisioning a genuinely new session instead.
	if idempotencyKey != "" {
		if val, redisErr := s.rdb.Get(ctx, "lab:idem:"+idempotencyKey).Result(); redisErr == nil && val != "" {
			existing, err := s.repo.GetSessionByID(ctx, val)
			if err != nil && !errors.Is(err, ErrNotFound) {
				return nil, fmt.Errorf("labs.Service.StartSession: resolve idempotency: %w", err)
			}
			if err == nil && isNonTerminalStatus(existing.Status) {
				return existing, nil
			}
			// Session is terminal, or the row is simply gone — either way the
			// cached ID no longer points at anything worth returning.
			if delErr := s.rdb.Del(ctx, "lab:idem:"+idempotencyKey).Err(); delErr != nil {
				slog.Warn("labs.Service.StartSession: clear stale idempotency key", "error", delErr)
			}
		}
	}

	// 4. Load org config (falls back to platform defaults on missing row).
	orgCfg, err := s.repo.GetOrgConfig(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.StartSession: get org config: %w", err)
	}

	// 4b. Image allowlist. An image whose ImageProfile.RequiresOrgAllowlist
	// is true (see ContainerRuntime.Classify — nested-Docker images today)
	// is never a platform default — it requires an explicit allowed_images
	// entry regardless of how large that list otherwise is. For an ordinary
	// image, an empty allowed_images list means "no restriction" (today's
	// existing behavior, now actually enforced rather than merely loaded and
	// ignored); a non-empty list restricts to it.
	if s.container.Classify(lab.Environment).RequiresOrgAllowlist {
		if !slices.Contains(orgCfg.AllowedImages, lab.Environment) {
			return nil, ErrImageNotAllowed
		}
	} else if len(orgCfg.AllowedImages) > 0 && !slices.Contains(orgCfg.AllowedImages, lab.Environment) {
		return nil, ErrImageNotAllowed
	}

	// 4c. Circuit breaker: refuse new sessions for a lab that's been failing
	// to provision repeatedly (broken image/setup_script) instead of letting
	// every student's retry burn another doomed container on the Docker
	// host. Instructor test sessions bypass this — that's exactly how the
	// instructor is expected to diagnose and fix the lab.
	if !isTest {
		failures, err := s.repo.CountRecentProvisionFailures(ctx, labID, ProvisionFailureCircuitBreakerWindow)
		if err != nil {
			return nil, fmt.Errorf("labs.Service.StartSession: count recent provision failures: %w", err)
		}
		if failures >= ProvisionFailureCircuitBreakerThreshold {
			s.notifyRepeatedProvisionFailures(context.Background(), labID, orgID)
			return nil, ErrLabProvisioningUnstable
		}
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

		// A user may only have one lab active at a time. Starting the same lab
		// again is still allowed below (it resumes the existing session) —
		// this only blocks starting a *different* lab while one is active.
		var hasOtherActiveSession bool
		if err := tx.QueryRow(ctx,
			`SELECT EXISTS (
				SELECT 1 FROM lab_sessions
				WHERE user_id=$1 AND lab_id<>$2 AND status IN ('provisioning','running','paused')
			)`,
			userID, labID,
		).Scan(&hasOtherActiveSession); err != nil {
			return nil, fmt.Errorf("labs.Service.StartSession: check other active session: %w", err)
		}
		if hasOtherActiveSession {
			return nil, ErrUserHasActiveSession
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

	// expires_at is the HARD wall-clock deadline described in docs/labs.md:
	// min(lab.max_duration, org.max_session_duration). Using the org cap
	// alone (the previous behavior) let every lab run for up to the org's
	// full 120-minute ceiling regardless of what the instructor actually
	// configured — a 30-minute lab silently held its container 4x longer
	// than intended.
	sessionMinutes := min(lab.MaxDuration, orgCfg.MaxSessionDuration)
	expiresAt := time.Now().Add(time.Duration(sessionMinutes) * time.Minute)
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

// provisionContainer runs in a goroutine. It first tries to claim a
// pre-warmed sandbox from the pool (near-instant); on a miss it cold-starts a
// container, records the coordinates in the DB, and publishes a readiness
// event via Redis.
func (s *Service) provisionContainer(ctx context.Context, session *LabSession, lab *LabDefinition) {
	// ProvisionTimeoutSeconds bounds the container work only. The bookkeeping
	// that follows it — marking the session failed/running and publishing the
	// event WaitForReadiness is streaming to the browser — must run on the
	// caller's (uncancelled) ctx instead: doing it on the expired provisionCtx
	// meant that whenever provisioning ran out its budget, the "failed" write
	// and the "failed" publish BOTH failed with "context deadline exceeded",
	// so the row stayed 'provisioning' and the student's lab-launch spinner
	// hung with no signal at all until the reaper flipped it a further
	// ProvisionReapGraceSeconds later. The timeout must never be able to
	// suppress the report of its own expiry.
	provisionCtx, cancel := context.WithTimeout(ctx, ProvisionTimeoutSeconds*time.Second)
	defer cancel()

	// Warm-pool fast path. Only first provisions (reset_count 0) qualify:
	// resets must rebuild from the original image anyway, and a reset user
	// already waited once. A claimed-but-dead container falls through to a
	// normal cold start; its row is deleted so the reconciler re-provisions.
	if session.ResetCount == 0 {
		if warm, err := s.repo.ClaimWarmContainer(provisionCtx, session.LabID, session.TaskVersionID, session.ID); err != nil {
			slog.Error("labs.Service.provisionContainer: claim warm", "session_id", session.ID, "error", err)
		} else if warm != nil {
			if s.container.IsRunning(provisionCtx, warm.ContainerID) {
				if err := s.repo.UpdateSessionRunning(ctx, session.ID, warm.ContainerID, warm.ContainerHost); err != nil {
					slog.Error("labs.Service.provisionContainer: update running (warm)", "session_id", session.ID, "error", err)
				}
				s.runRepoClone(ctx, session, warm.ContainerID)
				if err := s.rdb.Publish(ctx, "lab:events:"+session.ID, "ready").Err(); err != nil {
					slog.Error("labs.Service.provisionContainer: publish ready (warm)", "session_id", session.ID, "error", err)
				}
				return
			}
			slog.Warn("labs.Service.provisionContainer: warm container dead at claim, cold-starting", "session_id", session.ID, "warm_id", warm.ID)
			if err := s.repo.DeleteWarmContainer(ctx, warm.ID); err != nil {
				slog.Error("labs.Service.provisionContainer: delete dead warm row", "warm_id", warm.ID, "error", err)
			}
			_ = s.container.Kill(provisionCtx, warm.ContainerID)
		}
	}

	var setupScript string
	if lab.SetupScript != nil {
		setupScript = *lab.SetupScript
	}

	containerID, containerHost, err := s.container.Start(provisionCtx, session.ID, session.ResetCount, lab.Environment, setupScript)
	if err != nil {
		slog.Error("labs.Service.provisionContainer: start container", "session_id", session.ID, "error", err)
		errText := err.Error()
		if updateErr := s.repo.UpdateSessionFailed(ctx, session.ID, EndReasonProvisionFailed, &errText); updateErr != nil {
			slog.Error("labs.Service.provisionContainer: mark failed", "session_id", session.ID, "error", updateErr)
		}
		s.notifyRepeatedProvisionFailures(context.Background(), session.LabID, session.OrgID)
		if pubErr := s.rdb.Publish(ctx, "lab:events:"+session.ID, "failed").Err(); pubErr != nil {
			slog.Error("labs.Service.provisionContainer: publish failed", "session_id", session.ID, "error", pubErr)
		}
		return
	}

	if err := s.repo.UpdateSessionRunning(ctx, session.ID, containerID, containerHost); err != nil {
		slog.Error("labs.Service.provisionContainer: update running", "session_id", session.ID, "error", err)
	}
	s.runRepoClone(ctx, session, containerID)
	if err := s.rdb.Publish(ctx, "lab:events:"+session.ID, "ready").Err(); err != nil {
		slog.Error("labs.Service.provisionContainer: publish ready", "session_id", session.ID, "error", err)
	}
}

// notifyRepeatedProvisionFailures checks whether labID has crossed
// ProvisionFailureCircuitBreakerThreshold failures within
// ProvisionFailureCircuitBreakerWindow and, if so, notifies the org's
// owners/admins (in-app + email) so a broken lab image or setup_script gets
// human attention instead of silently eating every student's attempt.
// Called from two places — StartSession's circuit-breaker gate (a session
// was just refused) and provisionContainer's failure path (a session just
// failed) — both pass context.Background() since neither wants the
// notification's own success to depend on (or block) the caller's request
// lifecycle. DedupeKey is bucketed to one email per admin per window, so a
// lab hammered by retries for hours doesn't re-notify on every single
// failure — notifications.Service's UNIQUE(user_id, dedupe_key) does the
// collapsing, no extra state needed here.
func (s *Service) notifyRepeatedProvisionFailures(ctx context.Context, labID, orgID string) {
	if s.notifications == nil {
		return
	}

	failures, err := s.repo.CountRecentProvisionFailures(ctx, labID, ProvisionFailureCircuitBreakerWindow)
	if err != nil {
		slog.Error("labs.Service.notifyRepeatedProvisionFailures: count failures", "lab_id", labID, "error", err)
		return
	}
	if failures < ProvisionFailureCircuitBreakerThreshold {
		return
	}

	lab, err := s.repo.GetLab(ctx, labID, orgID)
	if err != nil {
		slog.Error("labs.Service.notifyRepeatedProvisionFailures: get lab", "lab_id", labID, "error", err)
		return
	}

	recipients, err := s.repo.OrgOwnersAndAdmins(ctx, orgID)
	if err != nil {
		slog.Error("labs.Service.notifyRepeatedProvisionFailures: get recipients", "org_id", orgID, "error", err)
		return
	}
	if len(recipients) == 0 {
		return
	}

	windowBucket := time.Now().UTC().Truncate(ProvisionFailureCircuitBreakerWindow).Unix()
	body := fmt.Sprintf(
		"\"%s\" has failed to provision %d times in the last %s and is temporarily blocked from starting new sessions until fixed. Check the lab's image and setup_script.",
		lab.Title, failures, ProvisionFailureCircuitBreakerWindow,
	)

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		slog.Error("labs.Service.notifyRepeatedProvisionFailures: begin tx", "error", err)
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()

	err = s.notifications.NotifyMany(ctx, tx, notifications.New{
		OrgID:      orgID,
		Type:       "lab_provisioning_unstable",
		Title:      fmt.Sprintf("Lab \"%s\" is repeatedly failing to start", lab.Title),
		Body:       &body,
		EntityType: strPtr("lab_definition"),
		EntityID:   &labID,
		Priority:   notifications.PriorityHigh,
		DedupeKey:  fmt.Sprintf("lab-provision-incident:%s:%d", labID, windowBucket),
		AlsoEmail:  true,
	}, recipients)
	if err != nil {
		slog.Error("labs.Service.notifyRepeatedProvisionFailures: notify", "lab_id", labID, "error", err)
		return
	}
	if err := tx.Commit(ctx); err != nil {
		slog.Error("labs.Service.notifyRepeatedProvisionFailures: commit", "error", err)
	}
}

func strPtr(s string) *string { return &s }

// repoCloneTimeoutSec bounds how long the auto-clone script may run inside
// the container before runRepoClone gives up and marks the session
// repo_clone_status='failed' — a slow or hung clone must never block the
// student from getting a working terminal (the "ready" publish still fires
// right after this returns, on both provisionContainer paths).
const repoCloneTimeoutSec = 45

// runRepoClone is the Batch 3 lab-container auto-clone hook: if a
// RepoPreparer is configured, ask it for a clone script and run it inside
// the session's own container before the student ever sees it. A nil
// RepoPreparer, an empty script (RepoPreparer's own "nothing to clone"
// signal — no project_team_id on this session, no GitLab connection for
// this user, etc.), or a script that fails to run all record
// repo_clone_status accordingly but never fail the session itself — per
// kind-herding-cookie.md §5, a broken clone must still hand the student a
// working terminal.
func (s *Service) runRepoClone(ctx context.Context, session *LabSession, containerID string) {
	if s.repoPreparer == nil {
		if err := s.repo.UpdateSessionRepoClone(ctx, session.ID, RepoCloneStatusSkipped, nil); err != nil {
			slog.Error("labs.Service.runRepoClone: record skipped (no preparer)", "session_id", session.ID, "error", err)
		}
		return
	}

	script, err := s.repoPreparer.PrepareLabRepo(ctx, session.ID, session.UserID, session.LabID)
	if err != nil {
		msg := err.Error()
		if updErr := s.repo.UpdateSessionRepoClone(ctx, session.ID, RepoCloneStatusFailed, &msg); updErr != nil {
			slog.Error("labs.Service.runRepoClone: record failed (prepare)", "session_id", session.ID, "error", updErr)
		}
		slog.Error("labs.Service.runRepoClone: prepare lab repo failed", "session_id", session.ID, "error", err)
		return
	}
	if script == "" {
		if err := s.repo.UpdateSessionRepoClone(ctx, session.ID, RepoCloneStatusSkipped, nil); err != nil {
			slog.Error("labs.Service.runRepoClone: record skipped (nothing to clone)", "session_id", session.ID, "error", err)
		}
		return
	}

	// Bound the exec itself here rather than inheriting whatever budget the
	// caller had left: repoCloneTimeoutSec is enforced by a `timeout` inside
	// the container, which does nothing if the docker exec never returns at
	// the CLI level. The surrounding status writes deliberately stay on ctx
	// so a clone that does blow this budget still records why.
	execCtx, cancel := context.WithTimeout(ctx, (repoCloneTimeoutSec+15)*time.Second)
	defer cancel()

	_, stderr, exitCode, execErr := s.container.Exec(execCtx, containerID, script, repoCloneTimeoutSec)
	if execErr != nil {
		msg := execErr.Error()
		if updErr := s.repo.UpdateSessionRepoClone(ctx, session.ID, RepoCloneStatusFailed, &msg); updErr != nil {
			slog.Error("labs.Service.runRepoClone: record failed (exec)", "session_id", session.ID, "error", updErr)
		}
		slog.Error("labs.Service.runRepoClone: exec clone script failed", "session_id", session.ID, "error", execErr)
		return
	}
	if exitCode != 0 {
		msg := fmt.Sprintf("clone script exited %d: %s", exitCode, stderr)
		if updErr := s.repo.UpdateSessionRepoClone(ctx, session.ID, RepoCloneStatusFailed, &msg); updErr != nil {
			slog.Error("labs.Service.runRepoClone: record failed (exit code)", "session_id", session.ID, "error", updErr)
		}
		return
	}

	if err := s.repo.UpdateSessionRepoClone(ctx, session.ID, RepoCloneStatusCloned, nil); err != nil {
		slog.Error("labs.Service.runRepoClone: record cloned", "session_id", session.ID, "error", err)
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

// ─── ListActiveSessions ────────────────────────────────────────────────────────

// ListActiveSessions returns the user's currently active lab sessions across
// all labs, so the frontend can show a persistent resume/end surface that
// survives a page refresh or a fresh login.
func (s *Service) ListActiveSessions(ctx context.Context, userID string) ([]ActiveLabSession, error) {
	sessions, err := s.repo.ListActiveSessions(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.ListActiveSessions: %w", err)
	}
	return sessions, nil
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
	if err := s.requireSessionLive(ctx, session); err != nil {
		return "", err
	}
	// Minting a WS token is the one action guaranteed to happen before every
	// terminal (re)connect and every preview (re)load — the frontend always
	// calls this to get a fresh token first (tokens are 5-minute JWTs; see
	// use-lab-terminal.ts / use-lab-preview.ts). That makes it the natural,
	// single place to resume a paused container: by the time the client
	// dials labproxy, the session is already 'running' and the container is
	// already unpaused, so labproxy itself never needs Docker/K8s API access
	// to do this — see cmd/labproxy's proxy.go/preview.go, which now just
	// reject a still-paused session rather than attempting their own resume.
	if session.Status == SessionStatusPaused {
		if err := s.ensureContainerResumed(ctx, session); err != nil {
			return "", fmt.Errorf("labs.Service.MintWSToken: resume: %w", err)
		}
	}
	// requireSessionLive alone also accepts 'provisioning' (no container yet
	// — nothing for the proxy to dial); the pause branch above only advances
	// 'paused' to 'running', so anything still not 'running' at this point
	// (i.e. 'provisioning') is rejected explicitly rather than handed a token
	// for a container that doesn't exist.
	if session.Status != SessionStatusRunning {
		return "", ErrSessionNotRunning
	}

	now := time.Now()
	claims := wsTokenClaims{
		SessionID: sessionID,
		UserID:    userID,
		Type:      WSTokenType,
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

	// Stored so labproxy can verify the token independently — a second
	// factor alongside the JWT signature, checked on every WS upgrade and
	// preview request (see cmd/labproxy's validateWSToken callers). The
	// session's DB status is still the authoritative revocation source (an
	// ended session's WS connections and preview requests are rejected the
	// moment status leaves 'running', regardless of token validity) — this
	// registry additionally lets a single leaked token be revoked with one
	// DEL, without waiting on or affecting the session it belongs to.
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

	passedCount, err := s.repo.CountPassedNonOptionalTasks(ctx, s.pool, sessionID, nonOptionalIDs)
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
		if _, err := s.repo.UpdateSessionCompleted(ctx, tx, sessionID); err != nil {
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

	// completed_at is now committed (for the completed branch; the expired
	// branch has none, so the usage query falls back to now() — see
	// RecordSessionContainerUsage), so the billed duration is accurate as of
	// this point.
	if err := s.repo.RecordSessionContainerUsage(ctx, sessionID); err != nil {
		slog.Error("labs.Service.EndSession: record usage", "session_id", sessionID, "error", err)
	}

	if session.ContainerID != nil {
		go s.container.Kill(context.Background(), *session.ContainerID)
	}

	return nil
}

// ─── ResetSession ─────────────────────────────────────────────────────────────

// ResetSession clears all task completions and zeroes the session score,
// consuming one of the lab's allowed resets. For container-backed lab types
// this ALSO re-provisions the container (docs/labs.md: "staged: new
// container healthy before old is killed") — a student's polluted
// filesystem/services otherwise survive a "reset" untouched, since every
// task's verification_script checks real container state. Code labs have no
// container to touch and only reset the scoreboard.
func (s *Service) ResetSession(ctx context.Context, sessionID, userID string) (*LabSession, []LabTaskCompletion, error) {
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, nil, err
	}
	if err := s.requireSessionLive(ctx, session); err != nil {
		return nil, nil, err
	}
	if session.Status != SessionStatusRunning && session.Status != SessionStatusPaused {
		return nil, nil, ErrSessionNotRunning
	}

	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.ResetSession: get lab: %w", err)
	}
	if session.ResetCount >= lab.MaxResets {
		return nil, nil, ErrMaxResetsReached
	}

	if lab.LabType == LabTypeCode {
		return s.resetCodeSession(ctx, session, userID)
	}
	return s.resetContainerSession(ctx, session, lab, userID)
}

// resetCodeSession is ResetSession's path for code labs: no container
// exists, so only the scoreboard resets.
func (s *Service) resetCodeSession(ctx context.Context, session *LabSession, userID string) (*LabSession, []LabTaskCompletion, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.resetCodeSession: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := s.repo.ResetTaskCompletions(ctx, tx, session.ID); err != nil {
		return nil, nil, err
	}
	if err := s.repo.ZeroSessionScore(ctx, tx, session.ID); err != nil {
		return nil, nil, err
	}
	if _, err := tx.Exec(ctx,
		"UPDATE lab_sessions SET reset_count = reset_count + 1 WHERE id=$1", session.ID,
	); err != nil {
		return nil, nil, fmt.Errorf("labs.Service.resetCodeSession: increment reset: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("labs.Service.resetCodeSession: commit: %w", err)
	}

	refreshed, err := s.repo.GetSession(ctx, session.ID, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.resetCodeSession: reload: %w", err)
	}
	return refreshed, []LabTaskCompletion{}, nil
}

// resetContainerSession is ResetSession's path for terminal/guided/
// playground/sandbox labs. Staged: the replacement container is started and
// confirmed BEFORE any DB state changes — a start failure here leaves the
// student's existing container, progress, and score completely untouched
// (returns ErrResetFailed; the reset attempt simply didn't consume anything).
// Only once the replacement is healthy does one transaction atomically wipe
// task completions/score and swap the session onto the new container's
// coordinates; the old container is killed only after that swap is durable.
func (s *Service) resetContainerSession(ctx context.Context, session *LabSession, lab *LabDefinition, userID string) (*LabSession, []LabTaskCompletion, error) {
	newResetCount := session.ResetCount + 1
	var setupScript string
	if lab.SetupScript != nil {
		setupScript = *lab.SetupScript
	}

	// Named "mindforge-lab-{sessionID}-{newResetCount}" — distinct from the
	// current container's "-{session.ResetCount}" name, exactly the
	// collision this suffix scheme exists to avoid (docs/labs.md).
	newContainerID, newContainerHost, startErr := s.container.Start(ctx, session.ID, newResetCount, lab.Environment, setupScript)
	if startErr != nil {
		slog.Error("labs.Service.resetContainerSession: start replacement container", "session_id", session.ID, "error", startErr)
		return nil, nil, ErrResetFailed
	}

	if err := s.swapResetContainer(ctx, session, newContainerID, newContainerHost, newResetCount); err != nil {
		_ = s.container.Kill(context.Background(), newContainerID)
		return nil, nil, err
	}

	// The new container is authoritative in the DB from this point — only
	// now is it safe to remove the old one.
	if session.ContainerID != nil {
		go s.container.Kill(context.Background(), *session.ContainerID)
	}

	// Fresh container, fresh clone — the same auto-clone hook StartSession
	// runs, so a reset student's repo starter state matches a first-time
	// session's instead of staying permanently empty after their first reset.
	s.runRepoClone(ctx, session, newContainerID)

	refreshed, err := s.repo.GetSession(ctx, session.ID, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("labs.Service.resetContainerSession: reload: %w", err)
	}
	return refreshed, []LabTaskCompletion{}, nil
}

// swapResetContainer runs the DB half of a staged reset in one transaction:
// wipe task completions, zero the score, and point the session at the new
// container's coordinates (incrementing reset_count, clearing any pause).
func (s *Service) swapResetContainer(ctx context.Context, session *LabSession, containerID, containerHost string, resetCount int) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("labs.Service.swapResetContainer: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if err := s.repo.ResetTaskCompletions(ctx, tx, session.ID); err != nil {
		return err
	}
	if err := s.repo.ZeroSessionScore(ctx, tx, session.ID); err != nil {
		return err
	}
	if err := s.repo.SwapSessionContainer(ctx, tx, session.ID, containerID, containerHost, resetCount); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("labs.Service.swapResetContainer: commit: %w", err)
	}
	return nil
}

// ─── WaitForReadiness ────────────────────────────────────────────────────────

// ─── VerifyTask ───────────────────────────────────────────────────────────────

// VerifyTask is the public entrypoint for both lab families. It performs the
// checks and bookkeeping shared by every lab type (IDOR/status check, rate
// limit, pinned-snapshot lookup, completion-row upsert, atomic attempt
// increment, lab lookup), then dispatches on lab.LabType to the code-runner
// path (Piston) or the container-exec path (docker exec inside the session's
// already-running container).
func (s *Service) VerifyTask(ctx context.Context, sessionID, taskID, userID, code string) (*VerifyResult, error) {
	// 1. IDOR + status check. Paused is allowed here (not just running): a
	//    container-lab session may be paused when the student comes back to
	//    verify — verifyContainerTask resumes the container before exec'ing
	//    into it. Code labs never reach a paused status today, so this is a
	//    no-op widening for that path.
	session, err := s.repo.GetSession(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	if err := s.requireSessionLive(ctx, session); err != nil {
		return nil, err
	}
	// requireSessionLive alone also accepts 'provisioning' (no container/
	// executor ready yet); verification needs one of the two live-and-ready
	// states.
	if session.Status != SessionStatusRunning && session.Status != SessionStatusPaused {
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

	// 4+5. Completion-row upsert + atomic attempt increment (shared with
	// SubmitAll's batch loop).
	attempts, err := s.bumpTaskAttempt(ctx, sessionID, taskID)
	if err != nil {
		return nil, err
	}

	// Load the lab once so both branches can dispatch on lab_type and, on
	// pass, resolve hint penalty / module-completion wiring without a second
	// fetch inside the branch itself.
	lab, err := s.repo.GetLab(ctx, session.LabID, session.OrgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.VerifyTask: get lab: %w", err)
	}

	if lab.LabType == LabTypeCode {
		if lab.Language == nil {
			return nil, fmt.Errorf("labs.Service.VerifyTask: code lab %s has no language configured", lab.ID)
		}
		return s.verifyCodeTask(ctx, session, lab, tasks, task, code, *lab.Language, attempts)
	}
	return s.verifyContainerTask(ctx, session, lab, tasks, task, attempts)
}

// bumpTaskAttempt ensures a completion row exists for the task (idempotent
// upsert) and atomically increments its attempt counter, returning the new
// attempt count. Shared by the single-task verify path and SubmitAll's batch.
func (s *Service) bumpTaskAttempt(ctx context.Context, sessionID, taskID string) (int, error) {
	if err := s.repo.EnsureTaskCompletion(ctx, sessionID, taskID); err != nil {
		return 0, fmt.Errorf("labs.Service.bumpTaskAttempt: ensure completion: %w", err)
	}
	attempts, err := s.repo.IncrementTaskAttempts(ctx, sessionID, taskID)
	if err != nil {
		return 0, fmt.Errorf("labs.Service.bumpTaskAttempt: increment attempts: %w", err)
	}
	return attempts, nil
}

// verifyCodeTask verifies a code-lab task by running the student's code
// through Piston, executed under the lab's own authoritative language
// (never a client-supplied value — see HandleVerifyTask).
func (s *Service) verifyCodeTask(ctx context.Context, session *LabSession, lab *LabDefinition, tasks []TaskSnapshot, task *TaskSnapshot, code, language string, attempts int) (*VerifyResult, error) {
	// Execute: concatenate student code + verification harness into one file.
	combined := code + "\n\n" + task.VerificationScript
	execCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	passed, stdout, stderr, execErr := s.piston.Execute(execCtx, language, combined)
	if execErr != nil {
		if errors.Is(execErr, ErrExecutorUnavailable) {
			return nil, ErrExecutorUnavailable
		}
		slog.Error("labs.Service.verifyCodeTask: execute", "error", execErr)
		return &VerifyResult{Passed: false, Attempts: attempts, Stderr: execErr.Error()}, nil
	}

	if !passed {
		return &VerifyResult{Passed: false, Attempts: attempts, Stdout: stdout, Stderr: stderr}, nil
	}

	return s.finalizeTaskPass(ctx, session, lab, tasks, task.ID, task.Points, attempts, stdout, stderr)
}

// verifyContainerTask verifies a terminal/guided/playground-lab task by
// running task.VerificationScript inside the session's already-running Docker
// container via `docker exec`. A playground lab has no tasks to verify per
// docs/labs.md, so in practice this path only fires for terminal and guided
// labs; the ContainerID nil-guard below is defense-in-depth for an otherwise
// unreachable state (a running/paused non-code session with no container).
func (s *Service) verifyContainerTask(ctx context.Context, session *LabSession, lab *LabDefinition, tasks []TaskSnapshot, task *TaskSnapshot, attempts int) (*VerifyResult, error) {
	if err := s.ensureContainerResumed(ctx, session); err != nil {
		return nil, fmt.Errorf("labs.Service.verifyContainerTask: %w", err)
	}

	stdout, stderr, exitCode, err := s.container.Exec(ctx, *session.ContainerID, task.VerificationScript, 10)
	if err != nil {
		slog.Error("labs.Service.verifyContainerTask: exec", "session", session.ID, "task", task.ID, "error", err)
		return &VerifyResult{Passed: false, Attempts: attempts, Stderr: err.Error()}, nil
	}
	if exitCode != 0 {
		return &VerifyResult{Passed: false, Attempts: attempts, Stdout: stdout, Stderr: stderr}, nil
	}

	return s.finalizeTaskPass(ctx, session, lab, tasks, task.ID, task.Points, attempts, stdout, stderr)
}

// requireSessionLive is the shared precondition for every session-touching
// endpoint: the session must be non-terminal AND still within its hard
// expires_at deadline. Checking status alone (the previous behavior) left a
// window of up to one minute — the lab.expire_sessions cron interval —
// during which a session past its deadline still looked "running" to every
// request-time check, so verify/exec/terminal traffic kept working well
// past the wall-clock cap docs/labs.md calls HARD. A session found expired
// here is closed out immediately (container killed, status flipped, exactly
// what the reaper would have done) so this and every subsequent request see
// consistent state right away instead of waiting for the next tick.
func (s *Service) requireSessionLive(ctx context.Context, session *LabSession) error {
	if !isNonTerminalStatus(session.Status) {
		return ErrSessionNotRunning
	}
	if time.Now().Before(session.ExpiresAt) {
		// This is the one call site every session-touching endpoint funnels
		// through (verify, file ops, run/submit, ws-token mint, reset) — the
		// natural single place to bump the idle heartbeat. The lab proxy's
		// own 5s WS heartbeat previously was the ONLY writer of
		// last_active_at, so a student editing files in the sandbox IDE with
		// the terminal tab closed, or any code-type lab (no WS at all), read
		// as idle and got paused/reaped mid-work. Best-effort: a failed
		// heartbeat write must never fail the request it's riding along with.
		if err := s.repo.UpdateLastActiveAt(ctx, session.ID); err != nil {
			slog.Error("labs.Service.requireSessionLive: update heartbeat", "session_id", session.ID, "error", err)
		}
		return nil
	}
	if err := s.repo.UpdateSessionExpired(ctx, session.ID, EndReasonTimeLimit); err != nil {
		slog.Error("labs.Service.requireSessionLive: mark expired", "session_id", session.ID, "error", err)
	}
	if err := s.repo.RecordSessionContainerUsage(ctx, session.ID); err != nil {
		slog.Error("labs.Service.requireSessionLive: record usage", "session_id", session.ID, "error", err)
	}
	if session.ContainerID != nil {
		go s.container.Kill(context.Background(), *session.ContainerID)
	}
	session.Status = SessionStatusExpired
	return ErrSessionExpired
}

// ensureContainerResumed guards every container-touching session operation
// (verify, file read/write/rename/delete, validate, resources) against a
// nil container and a paused container. A paused container can't be exec'd
// into — docker exec would hang against a suspended process tree — so this
// resumes it first, mirroring the same unpause + status-flip the lab proxy
// performs on WS reconnect (docs/labs.md, "Verify on a paused container").
// Mutates session.Status in place on resume so callers see the live value
// without a second fetch.
func (s *Service) ensureContainerResumed(ctx context.Context, session *LabSession) error {
	if session.ContainerID == nil {
		return fmt.Errorf("session %s has no container", session.ID)
	}
	if session.Status == SessionStatusPaused {
		if err := s.container.Unpause(ctx, *session.ContainerID); err != nil {
			return fmt.Errorf("unpause: %w", err)
		}
		// Folds the just-ended pause into the cumulative paused_seconds cost
		// counter and clears paused_at — see migration 011's column comment.
		if err := s.repo.ResumeFromPause(ctx, session.ID); err != nil {
			return fmt.Errorf("update status: %w", err)
		}
		session.Status = SessionStatusRunning
		session.PausedAt = nil
	}
	return nil
}

// finalizeTaskPass is the shared success tail for both verification paths,
// extracted verbatim from the pre-dispatcher VerifyTask body: mark the task
// passed and update the session score inside one transaction, then — guarded
// by a row lock so two concurrent verifies can't both flip the session — check
// whether every non-optional task in the pinned snapshot is now passed and, if
// so, mark the session completed. The embedding course module is completed
// non-fatally outside the transaction (the lab session itself is already
// committed by that point).
func (s *Service) finalizeTaskPass(ctx context.Context, session *LabSession, lab *LabDefinition, tasks []TaskSnapshot, taskID string, points, attempts int, stdout, stderr string) (*VerifyResult, error) {
	completionRows, err := s.repo.GetTaskCompletions(ctx, session.ID)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.finalizeTaskPass: get completions: %w", err)
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
		return nil, fmt.Errorf("labs.Service.finalizeTaskPass: begin tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	scoreAdded, err := s.repo.MarkTaskPassed(ctx, tx, session.ID, taskID, points, hintsUsed, lab.HintPenaltyPct)
	if err != nil {
		if errors.Is(err, ErrTaskAlreadyPassed) {
			return &VerifyResult{Passed: true, Attempts: attempts, Stdout: stdout, Stderr: stderr}, nil
		}
		return nil, fmt.Errorf("labs.Service.finalizeTaskPass: mark passed: %w", err)
	}

	// Full-completion check: SELECT FOR UPDATE guards against two concurrent verifies
	// both flipping the session to completed.
	var lockedID string
	if err := tx.QueryRow(ctx, "SELECT id FROM lab_sessions WHERE id=$1 FOR UPDATE", session.ID).Scan(&lockedID); err != nil {
		return nil, fmt.Errorf("labs.Service.finalizeTaskPass: lock session: %w", err)
	}

	nonOptionalIDs := make([]string, 0, len(tasks))
	for _, t := range tasks {
		if !t.IsOptional {
			nonOptionalIDs = append(nonOptionalIDs, t.ID)
		}
	}
	// Query via tx, not s.pool: this must see the MarkTaskPassed row just
	// written above in this same uncommitted transaction, which a separate
	// pool connection would not observe yet.
	passedCount, err := s.repo.CountPassedNonOptionalTasks(ctx, tx, session.ID, nonOptionalIDs)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.finalizeTaskPass: count passed: %w", err)
	}

	sessionCompleted := len(nonOptionalIDs) > 0 && passedCount >= len(nonOptionalIDs)
	if sessionCompleted {
		// UpdateSessionCompleted no longer takes a score to write — it
		// RETURNs the row's current value instead. MarkTaskPassed above
		// already did `score = score + scoreAdded` atomically in this same
		// transaction; writing session.Score+scoreAdded here (the caller's
		// in-memory snapshot, taken whenever the request started) used to
		// silently clobber whatever a concurrent verify for a different task
		// had just added, since the FOR UPDATE lock above is taken AFTER
		// MarkTaskPassed's write, not before it.
		if _, err := s.repo.UpdateSessionCompleted(ctx, tx, session.ID); err != nil {
			return nil, fmt.Errorf("labs.Service.finalizeTaskPass: complete session: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("labs.Service.finalizeTaskPass: commit: %w", err)
	}

	if sessionCompleted {
		if err := s.repo.RecordSessionContainerUsage(ctx, session.ID); err != nil {
			slog.Error("labs.Service.finalizeTaskPass: record usage", "session_id", session.ID, "error", err)
		}
	}

	// Complete the embedding course module (non-fatal: the lab session itself
	// is already committed above). Standalone/course-scoped labs with no
	// module_id are skipped — there is no module to mark complete.
	if sessionCompleted && s.coursesSvc != nil && lab.ModuleID != nil && lab.CourseID != nil {
		if _, _, err := s.coursesSvc.CompleteModule(ctx, session.UserID, session.OrgID, *lab.ModuleID, *lab.CourseID); err != nil {
			slog.Error("labs.Service.finalizeTaskPass: complete embedding module", "session", session.ID, "module", *lab.ModuleID, "err", err)
		}
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

// waitForReadinessDeadline hard-bounds one SSE connection. Provisioning
// itself is bounded by ProvisionTimeoutSeconds and the stuck-provisioning
// reaper by that plus ProvisionReapGraceSeconds — this adds its own margin on
// top so a client that's still connected genuinely gets an answer (or a
// clean disconnect) rather than the handler goroutine running forever on a
// status this loop never learns has gone terminal.
const waitForReadinessDeadline = time.Duration(ProvisionTimeoutSeconds+ProvisionReapGraceSeconds+30) * time.Second

// WaitForReadiness streams Server-Sent Events until the session leaves
// 'provisioning' — for any reason. It subscribes to a Redis channel
// published by the provisioning goroutine and polls the DB every 2 s as a
// fallback in case the pub/sub message was missed. Terminating only on
// 'running' or 'failed' (the previous behavior) left every OTHER terminal
// status — 'completed'/'expired'/'terminated_abuse', reachable if a session
// is reaped or ended while still being waited on — stuck polling the DB and
// holding a Redis subscription open for as long as the client stayed
// connected; waitForReadinessDeadline below is the hard backstop for that
// same reason. Every non-'running' terminal status reports "failed" to the
// client: the wire protocol (and every current frontend listener) only
// distinguishes ready/failed, and "session ended without ever becoming
// ready" is accurately a failure to become ready from the waiting client's
// point of view.
func (s *Service) WaitForReadiness(ctx context.Context, w http.ResponseWriter, sessionID string) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	ctx, cancel := context.WithTimeout(ctx, waitForReadinessDeadline)
	defer cancel()

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	emit := func(eventType string) {
		fmt.Fprintf(w, "data: {\"type\":%q}\n\n", eventType)
		flusher.Flush()
	}
	// terminalEvent reports the SSE event for a session status, and whether
	// the wait is over. Non-terminal ('provisioning') keeps the loop going.
	terminalEvent := func(status string) (event string, done bool) {
		switch status {
		case SessionStatusRunning:
			return "ready", true
		case SessionStatusProvisioning:
			return "", false
		default:
			return "failed", true
		}
	}

	// Fast path: session may already be terminal before we even subscribe.
	if session, err := s.repo.GetSessionByID(ctx, sessionID); err == nil {
		if event, done := terminalEvent(session.Status); done {
			emit(event)
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
				emit("ready")
				return
			case "failed":
				emit("failed")
				return
			}
		case <-ticker.C:
			session, err := s.repo.GetSessionByID(ctx, sessionID)
			if err != nil {
				slog.Error("labs.Service.WaitForReadiness: poll session", "session_id", sessionID, "error", err)
				return
			}
			if event, done := terminalEvent(session.Status); done {
				emit(event)
				return
			}
		}
	}
}

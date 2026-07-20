package labs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// ─── Warm container pool ─────────────────────────────────────────────────────
//
// Storage layer for the demand-driven warm pool. Three tables:
//   lab_warm_containers    — one row per pre-warmed sandbox (warming/ready/claimed)
//   lab_warm_pool_configs  — per-lab operator config (auto/fixed/off, caps)
//   lab_warm_pool_decisions— audit log: every scaling decision + the exact
//                            signal snapshot it was computed from
// The planner (warmpool.go) is the only writer of decisions; StartSession's
// fast path (service.go provisionContainer) is the only claimer.

// ClaimedWarmContainer is the result of atomically claiming one ready warm
// sandbox for a session.
type ClaimedWarmContainer struct {
	ID            string
	ContainerID   string
	ContainerHost string
}

// ClaimWarmContainer atomically claims the oldest ready warm container for
// the given lab + task version and binds it to sessionID. FOR UPDATE SKIP
// LOCKED makes concurrent claims across API replicas race-free: each caller
// either gets its own row or (nil, nil) when the pool is empty.
func (r *Repo) ClaimWarmContainer(ctx context.Context, labID, taskVersionID, sessionID string) (*ClaimedWarmContainer, error) {
	var c ClaimedWarmContainer
	err := r.pool.QueryRow(ctx, `
		UPDATE lab_warm_containers
		SET status='claimed', session_id=$3, claimed_at=now()
		WHERE id = (
			SELECT id FROM lab_warm_containers
			WHERE lab_id=$1 AND task_version_id=$2 AND status='ready'
			ORDER BY created_at
			LIMIT 1
			FOR UPDATE SKIP LOCKED
		)
		RETURNING id, container_id, container_host`,
		labID, taskVersionID, sessionID,
	).Scan(&c.ID, &c.ContainerID, &c.ContainerHost)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("labs.Repo.ClaimWarmContainer: %w", err)
	}
	return &c, nil
}

// DeleteWarmContainer removes a warm-pool row, e.g. after its container was
// found dead at claim time. The container itself is the caller's problem.
func (r *Repo) DeleteWarmContainer(ctx context.Context, id string) error {
	if _, err := r.pool.Exec(ctx, `DELETE FROM lab_warm_containers WHERE id=$1`, id); err != nil {
		return fmt.Errorf("labs.Repo.DeleteWarmContainer: %w", err)
	}
	return nil
}

// InsertWarmContainer creates a 'warming' row and returns its id — the id
// doubles as the container name suffix ("mindforge-warm-<id>") so the cleanup
// job can map orphaned containers back to rows.
func (r *Repo) InsertWarmContainer(ctx context.Context, labID, taskVersionID, image string) (string, error) {
	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO lab_warm_containers (lab_id, task_version_id, image, status)
		VALUES ($1, $2, $3, 'warming')
		RETURNING id`,
		labID, taskVersionID, image,
	).Scan(&id)
	if err != nil {
		return "", fmt.Errorf("labs.Repo.InsertWarmContainer: %w", err)
	}
	return id, nil
}

// MarkWarmContainerReady records a successfully provisioned sandbox's
// coordinates and flips the row to 'ready', making it claimable.
func (r *Repo) MarkWarmContainerReady(ctx context.Context, id, containerID, containerHost string) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE lab_warm_containers
		SET status='ready', container_id=$2, container_host=$3, ready_at=now()
		WHERE id=$1 AND status='warming'`,
		id, containerID, containerHost,
	); err != nil {
		return fmt.Errorf("labs.Repo.MarkWarmContainerReady: %w", err)
	}
	return nil
}

// WarmPoolLab is one pool-eligible lab (published, container-backed) with its
// effective config and current pool occupancy for the published version.
type WarmPoolLab struct {
	LabID         string  `json:"lab_id"`
	Title         string  `json:"title"`
	LabType       string  `json:"lab_type"`
	Image         string  `json:"image"`
	SetupScript   *string `json:"-"`
	TaskVersionID string  `json:"task_version_id"`
	Mode          string  `json:"mode"`
	FixedSize     int     `json:"fixed_size"`
	MaxSize       int     `json:"max_size"`
	Ready         int     `json:"ready"`
	Warming       int     `json:"warming"`
	Claimed       int     `json:"claimed"`
}

// ListWarmPoolLabs returns every lab the warm pool can serve: published,
// container-backed (code labs never get containers), with a published task
// version. Absent config row = mode 'auto', max 5.
func (r *Repo) ListWarmPoolLabs(ctx context.Context) ([]WarmPoolLab, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT l.id, l.title, l.lab_type, l.environment, l.setup_script, l.published_version_id,
		       COALESCE(c.mode, 'auto'), COALESCE(c.fixed_size, 0), COALESCE(c.max_size, 5),
		       COALESCE(w.ready, 0), COALESCE(w.warming, 0), COALESCE(w.claimed, 0)
		FROM lab_definitions l
		LEFT JOIN lab_warm_pool_configs c ON c.lab_id = l.id
		LEFT JOIN LATERAL (
			SELECT count(*) FILTER (WHERE wc.status='ready'   AND wc.task_version_id = l.published_version_id) AS ready,
			       count(*) FILTER (WHERE wc.status='warming' AND wc.task_version_id = l.published_version_id) AS warming,
			       count(*) FILTER (WHERE wc.status='claimed') AS claimed
			FROM lab_warm_containers wc WHERE wc.lab_id = l.id
		) w ON true
		WHERE l.is_published = true
		  AND l.lab_type <> $1
		  AND l.published_version_id IS NOT NULL
		ORDER BY l.title`,
		LabTypeCode,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListWarmPoolLabs: %w", err)
	}
	defer rows.Close()

	var out []WarmPoolLab
	for rows.Next() {
		var l WarmPoolLab
		if err := rows.Scan(&l.LabID, &l.Title, &l.LabType, &l.Image, &l.SetupScript, &l.TaskVersionID,
			&l.Mode, &l.FixedSize, &l.MaxSize, &l.Ready, &l.Warming, &l.Claimed); err != nil {
			return nil, fmt.Errorf("labs.Repo.ListWarmPoolLabs: scan: %w", err)
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

// ─── Demand signals ──────────────────────────────────────────────────────────

// CountPlatformActiveUsers approximates "users with the app open right now":
// distinct users with lab activity or an access-token refresh inside the
// window. Refresh tokens rotate periodically while a client is open, so this
// catches users browsing courses who haven't touched a lab yet — the exact
// population that might start one.
func (r *Repo) CountPlatformActiveUsers(ctx context.Context, window time.Duration) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT count(DISTINCT user_id) FROM (
			SELECT user_id FROM refresh_tokens
			WHERE revoked_at IS NULL AND (created_at > $1 OR rotated_at > $1)
			UNION
			SELECT user_id FROM lab_sessions WHERE last_active_at > $1
		) u`,
		time.Now().Add(-window),
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("labs.Repo.CountPlatformActiveUsers: %w", err)
	}
	return n, nil
}

// CountRecentStartsByLab returns real (non-test) session starts per lab in
// the trailing window — the strongest "demand is happening now" signal.
func (r *Repo) CountRecentStartsByLab(ctx context.Context, window time.Duration) (map[string]int, error) {
	return r.labCountQuery(ctx, `
		SELECT lab_id, count(*)::int
		FROM lab_sessions
		WHERE started_at > $1 AND is_test = false
		GROUP BY lab_id`,
		time.Now().Add(-window))
}

// CountEnrolledActiveByLab returns, per lab, how many currently-active users
// are enrolled (uncompleted) in the course that contains the lab's module —
// the population that could plausibly open this lab next.
func (r *Repo) CountEnrolledActiveByLab(ctx context.Context, window time.Duration) (map[string]int, error) {
	return r.labCountQuery(ctx, `
		SELECT l.id, count(DISTINCT e.user_id)::int
		FROM lab_definitions l
		JOIN course_modules m ON m.id = l.module_id
		JOIN enrollments e ON e.course_id = m.course_id AND e.completed_at IS NULL
		WHERE l.is_published = true
		  AND e.user_id IN (
			SELECT user_id FROM refresh_tokens
			WHERE revoked_at IS NULL AND (created_at > $1 OR rotated_at > $1)
			UNION
			SELECT user_id FROM lab_sessions WHERE last_active_at > $1
		  )
		GROUP BY l.id`,
		time.Now().Add(-window))
}

// HistExpectedStartsByLab estimates starts in the upcoming hour from the same
// hour-of-week over the trailing 4 weeks (average per week). Windows that
// straddle midnight under-count slightly — acceptable for a conservative
// planner that treats history as a secondary signal.
func (r *Repo) HistExpectedStartsByLab(ctx context.Context) (map[string]float64, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT lab_id, count(*)::float / 4.0
		FROM lab_sessions
		WHERE started_at > now() - interval '28 days'
		  AND is_test = false
		  AND extract(isodow FROM started_at) = extract(isodow FROM now())
		  AND started_at::time >= now()::time
		  AND started_at::time <  (now() + interval '60 minutes')::time
		GROUP BY lab_id`)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.HistExpectedStartsByLab: %w", err)
	}
	defer rows.Close()

	out := map[string]float64{}
	for rows.Next() {
		var id string
		var v float64
		if err := rows.Scan(&id, &v); err != nil {
			return nil, fmt.Errorf("labs.Repo.HistExpectedStartsByLab: scan: %w", err)
		}
		out[id] = v
	}
	return out, rows.Err()
}

// CountScheduledStartsByLab returns, per lab, how many students are on a
// schedule that opens this lab within the next hour: batch cohorts whose
// batch starts_at falls in the window, plus module-level unlock times
// (course_modules.starts_at) counted against uncompleted enrollments.
func (r *Repo) CountScheduledStartsByLab(ctx context.Context, window time.Duration) (map[string]int, error) {
	horizon := time.Now().Add(window)
	batch, err := r.labCountQuery(ctx, `
		SELECT l.id, count(DISTINCT bm.user_id)::int
		FROM lab_definitions l
		JOIN course_modules m ON m.id = l.module_id
		JOIN batch_courses bc ON bc.course_id = m.course_id
		JOIN batches b ON b.id = bc.batch_id AND b.status = 'active'
		  AND b.starts_at BETWEEN now() AND $1
		JOIN batch_members bm ON bm.batch_id = b.id
		WHERE l.is_published = true
		GROUP BY l.id`, horizon)
	if err != nil {
		return nil, err
	}
	module, err := r.labCountQuery(ctx, `
		SELECT l.id, count(DISTINCT e.user_id)::int
		FROM lab_definitions l
		JOIN course_modules m ON m.id = l.module_id
		  AND m.starts_at BETWEEN now() AND $1
		JOIN enrollments e ON e.course_id = m.course_id AND e.completed_at IS NULL
		WHERE l.is_published = true
		GROUP BY l.id`, horizon)
	if err != nil {
		return nil, err
	}
	for id, n := range module {
		if n > batch[id] {
			batch[id] = n
		}
	}
	return batch, nil
}

func (r *Repo) labCountQuery(ctx context.Context, sql string, args ...any) (map[string]int, error) {
	rows, err := r.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.labCountQuery: %w", err)
	}
	defer rows.Close()

	out := map[string]int{}
	for rows.Next() {
		var id string
		var n int
		if err := rows.Scan(&id, &n); err != nil {
			return nil, fmt.Errorf("labs.Repo.labCountQuery: scan: %w", err)
		}
		out[id] = n
	}
	return out, rows.Err()
}

// ─── Pool lifecycle (reconciler) ─────────────────────────────────────────────

// StaleWarmContainer is a pool row that no longer serves any purpose.
type StaleWarmContainer struct {
	ID          string
	ContainerID *string
	Status      string
	Kill        bool // true when the reconciler owns removing the container
}

// ListStaleWarmContainers finds rows to retire:
//   - ready/warming rows whose lab was unpublished/deleted or whose task
//     version is no longer the published one (kill container + delete row)
//   - claimed rows whose session ended (delete row only — the session
//     lifecycle owns that container)
//   - warming rows stuck longer than stuckAfter (delete row; the orphan
//     cleanup job removes any half-started container by name)
func (r *Repo) ListStaleWarmContainers(ctx context.Context, stuckAfter time.Duration) ([]StaleWarmContainer, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT w.id, w.container_id, w.status,
		       (w.status IN ('ready','warming')) AS kill
		FROM lab_warm_containers w
		LEFT JOIN lab_definitions l ON l.id = w.lab_id
		LEFT JOIN lab_sessions s ON s.id = w.session_id
		WHERE (w.status IN ('ready','warming')
		         AND (l.id IS NULL OR l.is_published = false
		              OR l.published_version_id IS DISTINCT FROM w.task_version_id))
		   OR (w.status = 'claimed'
		         AND (s.id IS NULL OR s.status IN ('completed','expired','failed','terminated_abuse')))
		   OR (w.status = 'warming' AND w.created_at < now() - $1::interval)
		LIMIT 100`,
		fmt.Sprintf("%d seconds", int(stuckAfter.Seconds())),
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListStaleWarmContainers: %w", err)
	}
	defer rows.Close()

	var out []StaleWarmContainer
	for rows.Next() {
		var s StaleWarmContainer
		if err := rows.Scan(&s.ID, &s.ContainerID, &s.Status, &s.Kill); err != nil {
			return nil, fmt.Errorf("labs.Repo.ListStaleWarmContainers: scan: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ListExcessReadyWarmContainers returns the oldest ready containers beyond
// keep for a lab+version, for scale-down.
func (r *Repo) ListExcessReadyWarmContainers(ctx context.Context, labID, taskVersionID string, keep int) ([]StaleWarmContainer, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, container_id, status, true AS kill
		FROM lab_warm_containers
		WHERE lab_id=$1 AND task_version_id=$2 AND status='ready'
		ORDER BY created_at DESC
		OFFSET $3`,
		labID, taskVersionID, keep,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListExcessReadyWarmContainers: %w", err)
	}
	defer rows.Close()

	var out []StaleWarmContainer
	for rows.Next() {
		var s StaleWarmContainer
		if err := rows.Scan(&s.ID, &s.ContainerID, &s.Status, &s.Kill); err != nil {
			return nil, fmt.Errorf("labs.Repo.ListExcessReadyWarmContainers: scan: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// WarmContainerExists reports whether a pool row with this id exists — used
// by the orphan cleanup job to decide if a "mindforge-warm-<id>" container is
// still owned by the pool.
func (r *Repo) WarmContainerExists(ctx context.Context, id string) (bool, error) {
	var exists bool
	if err := r.pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM lab_warm_containers WHERE id=$1)`, id,
	).Scan(&exists); err != nil {
		return false, fmt.Errorf("labs.Repo.WarmContainerExists: %w", err)
	}
	return exists, nil
}

// ─── Operator config ─────────────────────────────────────────────────────────

// UpsertWarmPoolConfig sets a lab's pool mode/sizes. Validation (mode enum,
// size bounds) is enforced both here by DB CHECKs and by the admin handler.
func (r *Repo) UpsertWarmPoolConfig(ctx context.Context, labID, mode string, fixedSize, maxSize int, updatedBy string) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO lab_warm_pool_configs (lab_id, mode, fixed_size, max_size, updated_by, updated_at)
		VALUES ($1, $2, $3, $4, $5, now())
		ON CONFLICT (lab_id) DO UPDATE
		SET mode=$2, fixed_size=$3, max_size=$4, updated_by=$5, updated_at=now()`,
		labID, mode, fixedSize, maxSize, updatedBy,
	); err != nil {
		return fmt.Errorf("labs.Repo.UpsertWarmPoolConfig: %w", err)
	}
	return nil
}

// ─── Decision audit log ──────────────────────────────────────────────────────

// WarmPoolDecision is one scaling decision: what was decided (target), what
// it replaced (previous_target), when (decided_at), and based on which exact
// inputs (raw JSON signal snapshot) and reasoning (human-readable).
type WarmPoolDecision struct {
	ID             string    `json:"id"`
	LabID          string    `json:"lab_id"`
	DecidedAt      time.Time `json:"decided_at"`
	Mode           string    `json:"mode"`
	Target         int       `json:"target"`
	PreviousTarget int       `json:"previous_target"`
	Inputs         []byte    `json:"inputs"`
	Reason         string    `json:"reason"`
}

// InsertWarmPoolDecision appends one decision to the audit log.
func (r *Repo) InsertWarmPoolDecision(ctx context.Context, d WarmPoolDecision) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO lab_warm_pool_decisions (lab_id, mode, target, previous_target, inputs, reason)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		d.LabID, d.Mode, d.Target, d.PreviousTarget, d.Inputs, d.Reason,
	); err != nil {
		return fmt.Errorf("labs.Repo.InsertWarmPoolDecision: %w", err)
	}
	return nil
}

// LatestWarmPoolDecisions returns the most recent decision per lab.
func (r *Repo) LatestWarmPoolDecisions(ctx context.Context) (map[string]WarmPoolDecision, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT ON (lab_id)
		       id, lab_id, decided_at, mode, target, previous_target, inputs, reason
		FROM lab_warm_pool_decisions
		ORDER BY lab_id, decided_at DESC`)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.LatestWarmPoolDecisions: %w", err)
	}
	defer rows.Close()

	out := map[string]WarmPoolDecision{}
	for rows.Next() {
		var d WarmPoolDecision
		if err := rows.Scan(&d.ID, &d.LabID, &d.DecidedAt, &d.Mode, &d.Target, &d.PreviousTarget, &d.Inputs, &d.Reason); err != nil {
			return nil, fmt.Errorf("labs.Repo.LatestWarmPoolDecisions: scan: %w", err)
		}
		out[d.LabID] = d
	}
	return out, rows.Err()
}

// ListWarmPoolDecisions returns a lab's decision history, newest first.
func (r *Repo) ListWarmPoolDecisions(ctx context.Context, labID string, limit int) ([]WarmPoolDecision, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, lab_id, decided_at, mode, target, previous_target, inputs, reason
		FROM lab_warm_pool_decisions
		WHERE lab_id=$1
		ORDER BY decided_at DESC
		LIMIT $2`,
		labID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListWarmPoolDecisions: %w", err)
	}
	defer rows.Close()

	var out []WarmPoolDecision
	for rows.Next() {
		var d WarmPoolDecision
		if err := rows.Scan(&d.ID, &d.LabID, &d.DecidedAt, &d.Mode, &d.Target, &d.PreviousTarget, &d.Inputs, &d.Reason); err != nil {
			return nil, fmt.Errorf("labs.Repo.ListWarmPoolDecisions: scan: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// PruneWarmPoolDecisions drops audit rows older than the retention window so
// the log stays bounded (one row per lab per change + 15-min heartbeats).
func (r *Repo) PruneWarmPoolDecisions(ctx context.Context, olderThan time.Duration) error {
	if _, err := r.pool.Exec(ctx,
		`DELETE FROM lab_warm_pool_decisions WHERE decided_at < $1`,
		time.Now().Add(-olderThan),
	); err != nil {
		return fmt.Errorf("labs.Repo.PruneWarmPoolDecisions: %w", err)
	}
	return nil
}

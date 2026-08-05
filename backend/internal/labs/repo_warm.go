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
//   lab_warm_containers     — one row per pre-warmed sandbox (warming/ready/claimed)
//   lab_warm_pool_decisions — audit log: every scaling decision + the exact
//                             signal snapshot it was computed from
//   lab_image_warmup_stats  — measured warm-start latency per image (EWMA)
//
// Everything here is keyed by IMAGE, never by lab. A warm sandbox pre-pays its
// image's boot cost and nothing else; the lab-specific work (starter files,
// setup_script) is applied at claim time by Service.prepareLabEnvironment, so
// any ready container of the right image serves any lab that uses it. See
// migration 013_warm_pool_by_image.sql for what this replaced and why.
//
// The planner (warmpool.go) is the only writer of decisions and stats;
// StartSession's fast path (service.go provisionContainer) is the only claimer.

// ClaimedWarmContainer is the result of atomically claiming one ready warm
// sandbox for a session.
type ClaimedWarmContainer struct {
	ID            string
	ContainerID   string
	ContainerHost string
}

// ClaimWarmContainer atomically claims the oldest ready warm container for the
// given image and binds it to sessionID. FOR UPDATE SKIP LOCKED makes
// concurrent claims across API replicas race-free: each caller either gets its
// own row or (nil, nil) when the pool is empty.
//
// Image is the whole key. A container is never reserved for one lab, so a
// student opening any of the fourteen labs that share mindforge/lab-k8s can
// claim any warm k8s sandbox — the reason a single pool now covers what used
// to need fourteen.
func (r *Repo) ClaimWarmContainer(ctx context.Context, image, sessionID string) (*ClaimedWarmContainer, error) {
	var c ClaimedWarmContainer
	err := r.pool.QueryRow(ctx, `
		UPDATE lab_warm_containers
		SET status='claimed', session_id=$2, claimed_at=now()
		WHERE id = (
			SELECT id FROM lab_warm_containers
			WHERE image=$1 AND status='ready'
			ORDER BY created_at
			LIMIT 1
			FOR UPDATE SKIP LOCKED
		)
		RETURNING id, container_id, container_host`,
		image, sessionID,
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
func (r *Repo) InsertWarmContainer(ctx context.Context, image string) (string, error) {
	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO lab_warm_containers (image, status)
		VALUES ($1, 'warming')
		RETURNING id`,
		image,
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

// WarmPoolImage is one pool-eligible sandbox image with its current occupancy
// and measured warm-start latency. LabCount is how many published labs use it
// — never an input to sizing (demand is measured from sessions, not catalog
// size), only context for the admin view.
type WarmPoolImage struct {
	Image         string  `json:"image"`
	LabCount      int     `json:"lab_count"`
	Ready         int     `json:"ready"`
	Warming       int     `json:"warming"`
	Claimed       int     `json:"claimed"`
	WarmupSeconds float64 `json:"warmup_seconds"`
	WarmupSamples int64   `json:"warmup_samples"`
}

// warmPoolImagesQuery is shared by ListWarmPoolImages (planner, platform-wide)
// and ListWarmPoolImagesForOrg (admin API, org-scoped) — identical column list
// and joins, differing only in whether an org_id filter is appended.
//
// Note what is NOT here versus the per-lab predecessor: no published_version_id
// correlation on the occupancy counts. A warm container no longer pins a task
// version, so republishing a lab cannot strand its pool — that entire class of
// churn disappeared with the key change.
const warmPoolImagesQuery = `
	SELECT l.environment,
	       count(DISTINCT l.id)::int,
	       COALESCE(w.ready, 0), COALESCE(w.warming, 0), COALESCE(w.claimed, 0),
	       COALESCE(st.ewma_seconds, 0), COALESCE(st.samples, 0)
	FROM lab_definitions l
	LEFT JOIN (
		SELECT image,
		       count(*) FILTER (WHERE status='ready')::int   AS ready,
		       count(*) FILTER (WHERE status='warming')::int AS warming,
		       count(*) FILTER (WHERE status='claimed')::int AS claimed
		FROM lab_warm_containers
		GROUP BY image
	) w ON w.image = l.environment
	LEFT JOIN lab_image_warmup_stats st ON st.image = l.environment
	WHERE l.is_published = true
	  AND l.lab_type <> $1
	  AND l.published_version_id IS NOT NULL`

const warmPoolImagesGroupBy = `
	GROUP BY l.environment, w.ready, w.warming, w.claimed, st.ewma_seconds, st.samples
	ORDER BY l.environment`

func scanWarmPoolImageRows(rows pgx.Rows) ([]WarmPoolImage, error) {
	defer rows.Close()
	var out []WarmPoolImage
	for rows.Next() {
		var i WarmPoolImage
		if err := rows.Scan(&i.Image, &i.LabCount, &i.Ready, &i.Warming, &i.Claimed,
			&i.WarmupSeconds, &i.WarmupSamples); err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		out = append(out, i)
	}
	return out, rows.Err()
}

// ListWarmPoolImages returns every pool-eligible image across ALL orgs — the
// planner's view, since warm containers are shared infrastructure the
// reconciler sizes platform-wide. NOT org-scoped: only call this from
// WarmPoolPlanner.Tick (internal, no HTTP caller). Any endpoint reachable by an
// org admin must use ListWarmPoolImagesForOrg instead.
func (r *Repo) ListWarmPoolImages(ctx context.Context) ([]WarmPoolImage, error) {
	rows, err := r.pool.Query(ctx, warmPoolImagesQuery+warmPoolImagesGroupBy, LabTypeCode)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListWarmPoolImages: %w", err)
	}
	out, err := scanWarmPoolImageRows(rows)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListWarmPoolImages: %w", err)
	}
	return out, nil
}

// ListWarmPoolImagesForOrg is ListWarmPoolImages restricted to images the given
// org actually uses — the admin-API view. The pool itself is platform-wide, so
// the occupancy numbers are the real shared ones; the org filter only decides
// which image rows a given admin is shown, keeping another org's exclusive
// images out of the response.
func (r *Repo) ListWarmPoolImagesForOrg(ctx context.Context, orgID string) ([]WarmPoolImage, error) {
	rows, err := r.pool.Query(ctx, warmPoolImagesQuery+" AND l.org_id = $2"+warmPoolImagesGroupBy, LabTypeCode, orgID)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListWarmPoolImagesForOrg: %w", err)
	}
	out, err := scanWarmPoolImageRows(rows)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ListWarmPoolImagesForOrg: %w", err)
	}
	return out, nil
}

// ─── Demand signals ──────────────────────────────────────────────────────────
//
// Every signal is aggregated per IMAGE (lab_sessions joined to
// lab_definitions.environment). Aggregating at the image level is not just a
// key change — it makes the signals statistically usable. Per lab, a typical
// lab saw 0-2 starts an hour, so the sizing formula was reading noise; summed
// across the fourteen labs sharing an image it reads actual arrival rate.

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

// CountRecentStartsByImage returns real (non-test) session starts per image in
// the trailing window — the strongest "demand is happening now" signal, and the
// arrival rate the Little's Law target is computed from.
func (r *Repo) CountRecentStartsByImage(ctx context.Context, window time.Duration) (map[string]int, error) {
	return r.imageCountQuery(ctx, `
		SELECT l.environment, count(*)::int
		FROM lab_sessions s
		JOIN lab_definitions l ON l.id = s.lab_id
		WHERE s.started_at > $1 AND s.is_test = false
		GROUP BY l.environment`,
		time.Now().Add(-window))
}

// CountEnrolledActiveByImage returns, per image, how many currently-active
// users are enrolled (uncompleted) in a course containing a lab that uses it —
// the population that could plausibly open one of those labs next.
func (r *Repo) CountEnrolledActiveByImage(ctx context.Context, window time.Duration) (map[string]int, error) {
	return r.imageCountQuery(ctx, `
		SELECT l.environment, count(DISTINCT e.user_id)::int
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
		GROUP BY l.environment`,
		time.Now().Add(-window))
}

// HistExpectedStartsByImage estimates starts in the upcoming hour from the same
// hour-of-week over the trailing 4 weeks (average per week). Windows that
// straddle midnight under-count slightly — acceptable for a conservative
// planner that treats history as a secondary signal.
func (r *Repo) HistExpectedStartsByImage(ctx context.Context) (map[string]float64, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT l.environment, count(*)::float / 4.0
		FROM lab_sessions s
		JOIN lab_definitions l ON l.id = s.lab_id
		WHERE s.started_at > now() - interval '28 days'
		  AND s.is_test = false
		  AND extract(isodow FROM s.started_at) = extract(isodow FROM now())
		  AND s.started_at::time >= now()::time
		  AND s.started_at::time <  (now() + interval '60 minutes')::time
		GROUP BY l.environment`)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.HistExpectedStartsByImage: %w", err)
	}
	defer rows.Close()

	out := map[string]float64{}
	for rows.Next() {
		var image string
		var v float64
		if err := rows.Scan(&image, &v); err != nil {
			return nil, fmt.Errorf("labs.Repo.HistExpectedStartsByImage: scan: %w", err)
		}
		out[image] = v
	}
	return out, rows.Err()
}

// CountScheduledStartsByImage returns, per image, how many students are on a
// schedule that opens a lab using that image within the next hour: batch
// cohorts whose batch starts_at falls in the window, plus module-level unlock
// times (course_modules.starts_at) counted against uncompleted enrollments.
//
// This is the one signal that must not be averaged away — a batch of 40
// students starting at 09:00 is a known, dated spike, and it is exactly what a
// demand-driven pool exists to absorb.
func (r *Repo) CountScheduledStartsByImage(ctx context.Context, window time.Duration) (map[string]int, error) {
	horizon := time.Now().Add(window)
	batch, err := r.imageCountQuery(ctx, `
		SELECT l.environment, count(DISTINCT bm.user_id)::int
		FROM lab_definitions l
		JOIN course_modules m ON m.id = l.module_id
		JOIN content_assignments ca ON ca.content_type = 'course' AND ca.content_id = m.course_id AND ca.assignee_type = 'batch'
		JOIN batches b ON b.id = ca.assignee_id AND b.status = 'active'
		  AND b.starts_at BETWEEN now() AND $1
		JOIN batch_members bm ON bm.batch_id = b.id
		WHERE l.is_published = true
		GROUP BY l.environment`, horizon)
	if err != nil {
		return nil, err
	}
	module, err := r.imageCountQuery(ctx, `
		SELECT l.environment, count(DISTINCT e.user_id)::int
		FROM lab_definitions l
		JOIN course_modules m ON m.id = l.module_id
		  AND m.starts_at BETWEEN now() AND $1
		JOIN enrollments e ON e.course_id = m.course_id AND e.completed_at IS NULL
		WHERE l.is_published = true
		GROUP BY l.environment`, horizon)
	if err != nil {
		return nil, err
	}
	for image, n := range module {
		if n > batch[image] {
			batch[image] = n
		}
	}
	return batch, nil
}

func (r *Repo) imageCountQuery(ctx context.Context, sql string, args ...any) (map[string]int, error) {
	rows, err := r.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.imageCountQuery: %w", err)
	}
	defer rows.Close()

	out := map[string]int{}
	for rows.Next() {
		var image string
		var n int
		if err := rows.Scan(&image, &n); err != nil {
			return nil, fmt.Errorf("labs.Repo.imageCountQuery: scan: %w", err)
		}
		out[image] = n
	}
	return out, rows.Err()
}

// ─── Measured warm-start latency ─────────────────────────────────────────────

// RecordWarmupSample folds one observed warm-start duration into the image's
// exponentially weighted moving average. Called after every successful warm
// start, so the planner sizes from what the fleet actually does rather than a
// hardcoded guess — an image that gets slower (a heavier base, a busier host)
// grows its pool on its own, and a fast image stops holding containers it never
// needed.
//
// EWMA rather than a plain average so a permanent change in warm-start cost is
// tracked within a few dozen samples instead of being drowned by months of
// history; alpha is WarmupEWMAAlpha.
func (r *Repo) RecordWarmupSample(ctx context.Context, image string, seconds float64) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO lab_image_warmup_stats (image, ewma_seconds, samples, updated_at)
		VALUES ($1, $2, 1, now())
		ON CONFLICT (image) DO UPDATE
		SET ewma_seconds = lab_image_warmup_stats.ewma_seconds * (1 - $3) + $2 * $3,
		    samples      = lab_image_warmup_stats.samples + 1,
		    updated_at   = now()`,
		image, seconds, WarmupEWMAAlpha,
	); err != nil {
		return fmt.Errorf("labs.Repo.RecordWarmupSample: %w", err)
	}
	return nil
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
//   - ready/warming rows whose image is no longer used by ANY published,
//     container-backed lab (kill container + delete row)
//   - claimed rows whose session ended (delete row only — the session
//     lifecycle owns that container)
//   - warming rows stuck longer than stuckAfter (delete row; the orphan
//     cleanup job removes any half-started container by name)
//
// The first case used to also fire whenever a lab was republished, because a
// warm container pinned one task_version_id. It no longer can: a container
// carries no lab or version, so it goes stale only when its image genuinely
// leaves the published catalog.
func (r *Repo) ListStaleWarmContainers(ctx context.Context, stuckAfter time.Duration) ([]StaleWarmContainer, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT w.id, w.container_id, w.status,
		       (w.status IN ('ready','warming')) AS kill
		FROM lab_warm_containers w
		LEFT JOIN lab_sessions s ON s.id = w.session_id
		WHERE (w.status IN ('ready','warming')
		         AND NOT EXISTS (
		             SELECT 1 FROM lab_definitions l
		             WHERE l.environment = w.image
		               AND l.is_published = true
		               AND l.lab_type <> $2
		               AND l.published_version_id IS NOT NULL))
		   OR (w.status = 'claimed'
		         AND (s.id IS NULL OR s.status IN ('completed','expired','failed','terminated_abuse')))
		   OR (w.status = 'warming' AND w.created_at < now() - $1::interval)
		LIMIT 100`,
		fmt.Sprintf("%d seconds", int(stuckAfter.Seconds())), LabTypeCode,
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

// ListExcessReadyWarmContainers returns up to limit of the OLDEST ready
// containers for an image — scale-down candidates. Pool members are fungible
// (same image, no lab binding), so "oldest first" is only a recycling
// preference, never a correctness requirement. The caller computes limit as
// Ready-target; a non-positive limit returns no rows. Selection here is NOT the
// removal itself — see DeleteReadyWarmContainer, which re-checks status='ready'
// atomically at delete time so a container a student claims between this SELECT
// and that DELETE is never destroyed out from under their session.
func (r *Repo) ListExcessReadyWarmContainers(ctx context.Context, image string, limit int) ([]StaleWarmContainer, error) {
	if limit <= 0 {
		return nil, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, container_id, status, true AS kill
		FROM lab_warm_containers
		WHERE image=$1 AND status='ready'
		ORDER BY created_at ASC
		LIMIT $2`,
		image, limit,
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

// DeleteReadyWarmContainer atomically deletes a warm-pool row ONLY if it is
// still 'ready' — the scale-down counterpart to ClaimWarmContainer's
// FOR UPDATE SKIP LOCKED claim. Without this atomicity, a container listed
// by ListExcessReadyWarmContainers could be claimed by a student's
// StartSession in the window between that SELECT and this DELETE, and the
// reconciler would then kill a container a live session now depends on.
// deleted=false means exactly that race happened: the row is already gone
// (or already claimed) and the caller must NOT call runtime.Kill on the
// container it looked up before this call.
func (r *Repo) DeleteReadyWarmContainer(ctx context.Context, id string) (containerID *string, deleted bool, err error) {
	err = r.pool.QueryRow(ctx,
		`DELETE FROM lab_warm_containers WHERE id=$1 AND status='ready' RETURNING container_id`,
		id,
	).Scan(&containerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("labs.Repo.DeleteReadyWarmContainer: %w", err)
	}
	return containerID, true, nil
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

// ─── Decision audit log ──────────────────────────────────────────────────────

// WarmPoolDecision is one scaling decision: what was decided (target), what
// it replaced (previous_target), when (decided_at), and based on which exact
// inputs (raw JSON signal snapshot) and reasoning (human-readable).
type WarmPoolDecision struct {
	ID             string    `json:"id"`
	Image          string    `json:"image"`
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
		INSERT INTO lab_warm_pool_decisions (image, mode, target, previous_target, inputs, reason)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		d.Image, d.Mode, d.Target, d.PreviousTarget, d.Inputs, d.Reason,
	); err != nil {
		return fmt.Errorf("labs.Repo.InsertWarmPoolDecision: %w", err)
	}
	return nil
}

// LatestWarmPoolDecisions returns the most recent decision per image.
func (r *Repo) LatestWarmPoolDecisions(ctx context.Context) (map[string]WarmPoolDecision, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT ON (image)
		       id, image, decided_at, mode, target, previous_target, inputs, reason
		FROM lab_warm_pool_decisions
		ORDER BY image, decided_at DESC`)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.LatestWarmPoolDecisions: %w", err)
	}
	defer rows.Close()

	out := map[string]WarmPoolDecision{}
	for rows.Next() {
		var d WarmPoolDecision
		if err := rows.Scan(&d.ID, &d.Image, &d.DecidedAt, &d.Mode, &d.Target, &d.PreviousTarget, &d.Inputs, &d.Reason); err != nil {
			return nil, fmt.Errorf("labs.Repo.LatestWarmPoolDecisions: scan: %w", err)
		}
		out[d.Image] = d
	}
	return out, rows.Err()
}

// PruneWarmPoolDecisions drops audit rows older than the retention window so
// the log stays bounded (one row per image per change + heartbeats).
func (r *Repo) PruneWarmPoolDecisions(ctx context.Context, olderThan time.Duration) error {
	if _, err := r.pool.Exec(ctx,
		`DELETE FROM lab_warm_pool_decisions WHERE decided_at < $1`,
		time.Now().Add(-olderThan),
	); err != nil {
		return fmt.Errorf("labs.Repo.PruneWarmPoolDecisions: %w", err)
	}
	return nil
}

package handlers

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/opsalert"
)

const opsDigestWindow = 24 * time.Hour

// OpsDigestHandler implements jobs.Handler for HandlerOpsDigest: a daily
// summary of dead jobs, failed runs and queue depth. Super admins get the
// platform-wide numbers, each org's owners/admins get their org's own. Scopes
// with all-zero numbers are skipped.
type OpsDigestHandler struct {
	pool  *pgxpool.Pool
	alert *opsalert.Service
}

// NewOpsDigestHandler constructs an OpsDigestHandler.
func NewOpsDigestHandler(pool *pgxpool.Pool, alert *opsalert.Service) *OpsDigestHandler {
	return &OpsDigestHandler{pool: pool, alert: alert}
}

type opsDigestStats struct {
	deadByHandler map[string]int
	failedRuns    int
	queueDepth    int
}

func (s opsDigestStats) empty() bool {
	return len(s.deadByHandler) == 0 && s.failedRuns == 0 && s.queueDepth == 0
}

func (s opsDigestStats) body() string {
	handlers := make([]string, 0, len(s.deadByHandler))
	dead := 0
	for h, n := range s.deadByHandler {
		handlers = append(handlers, h)
		dead += n
	}
	sort.Strings(handlers)
	parts := make([]string, 0, len(handlers))
	for _, h := range handlers {
		parts = append(parts, fmt.Sprintf("%s: %d", h, s.deadByHandler[h]))
	}
	byHandler := "none"
	if len(parts) > 0 {
		byHandler = strings.Join(parts, ", ")
	}
	return fmt.Sprintf("Dead jobs (24h): %d (%s). Failed runs (24h): %d. Queue depth: %d.",
		dead, byHandler, s.failedRuns, s.queueDepth)
}

// Handle sends the platform digest, then one digest per org with job activity.
func (h *OpsDigestHandler) Handle(ctx context.Context, _ jobs.Job) error {
	day := time.Now().UTC().Format("2006-01-02")

	platform, err := h.stats(ctx, nil)
	if err != nil {
		return err
	}
	if !platform.empty() {
		if err := h.alert.NotifyPlatformAdmins(ctx, digestAlert("platform", day, platform)); err != nil {
			return fmt.Errorf("handlers.ops_digest: notify platform: %w", err)
		}
	}

	rows, err := h.pool.Query(ctx,
		`SELECT DISTINCT org_id FROM jobs WHERE org_id IS NOT NULL AND deleted_at IS NULL
		   AND (status IN ('queued', 'pending') OR updated_at > NOW() - make_interval(secs => $1))`,
		opsDigestWindow.Seconds())
	if err != nil {
		return fmt.Errorf("handlers.ops_digest: list orgs: %w", err)
	}
	var orgIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return fmt.Errorf("handlers.ops_digest: scan org: %w", err)
		}
		orgIDs = append(orgIDs, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return fmt.Errorf("handlers.ops_digest: iterate orgs: %w", err)
	}

	for _, orgID := range orgIDs {
		st, err := h.stats(ctx, &orgID)
		if err != nil {
			return err
		}
		if st.empty() {
			continue
		}
		if err := h.alert.NotifyOrgAdmins(ctx, orgID, digestAlert(orgID, day, st)); err != nil {
			return fmt.Errorf("handlers.ops_digest: notify org %s: %w", orgID, err)
		}
	}
	return nil
}

func digestAlert(scope, day string, st opsDigestStats) opsalert.Alert {
	return opsalert.Alert{
		Type: opsalert.TypeDigest, Title: "Daily job health digest", Body: st.body(),
		LinkURL: opsalert.AdminJobsLink, Priority: notifications.PriorityLow,
		DedupeKey: fmt.Sprintf("opsdigest:%s:%s", scope, day),
	}
}

// stats gathers the 24h numbers; orgID nil means platform-wide.
func (h *OpsDigestHandler) stats(ctx context.Context, orgID *string) (opsDigestStats, error) {
	st := opsDigestStats{deadByHandler: map[string]int{}}
	secs := opsDigestWindow.Seconds()

	rows, err := h.pool.Query(ctx,
		`SELECT handler, COUNT(*) FROM jobs
		 WHERE status = 'dead' AND deleted_at IS NULL AND updated_at > NOW() - make_interval(secs => $1)
		   AND ($2::uuid IS NULL OR org_id = $2)
		 GROUP BY handler`, secs, orgID)
	if err != nil {
		return st, fmt.Errorf("handlers.ops_digest: dead by handler: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var handler string
		var n int
		if err := rows.Scan(&handler, &n); err != nil {
			return st, fmt.Errorf("handlers.ops_digest: scan dead: %w", err)
		}
		st.deadByHandler[handler] = n
	}
	if err := rows.Err(); err != nil {
		return st, fmt.Errorf("handlers.ops_digest: iterate dead: %w", err)
	}

	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM job_runs r JOIN jobs j ON j.id = r.job_id
		 WHERE r.status = 'failed' AND r.finished_at > NOW() - make_interval(secs => $1)
		   AND ($2::uuid IS NULL OR j.org_id = $2)`, secs, orgID,
	).Scan(&st.failedRuns); err != nil {
		return st, fmt.Errorf("handlers.ops_digest: failed runs: %w", err)
	}
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM jobs
		 WHERE status = 'queued' AND job_type = 'one_time' AND deleted_at IS NULL
		   AND ($1::uuid IS NULL OR org_id = $1)`, orgID,
	).Scan(&st.queueDepth); err != nil {
		return st, fmt.Errorf("handlers.ops_digest: queue depth: %w", err)
	}
	return st, nil
}

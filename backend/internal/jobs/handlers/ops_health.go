package handlers

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/opsalert"
)

const (
	// emailDeadRateWindow is the look-back for the SMTP-down signal.
	emailDeadRateWindow = 15 * time.Minute
	// healthAlertBucket makes each health condition alert at most once per hour.
	healthAlertBucket = time.Hour
	// stuckRunningTimeoutFactor: a running job is stuck past this multiple of its timeout.
	stuckRunningTimeoutFactor = 2
)

// OpsHealthHandler implements jobs.Handler for HandlerOpsHealth: it checks
// the job system's own health and alerts platform super admins.
type OpsHealthHandler struct {
	pool  *pgxpool.Pool
	cfg   *config.Config
	alert *opsalert.Service
}

// NewOpsHealthHandler constructs an OpsHealthHandler.
func NewOpsHealthHandler(pool *pgxpool.Pool, cfg *config.Config, alert *opsalert.Service) *OpsHealthHandler {
	return &OpsHealthHandler{pool: pool, cfg: cfg, alert: alert}
}

// Handle runs each check; one failing check does not skip the others.
func (h *OpsHealthHandler) Handle(ctx context.Context, _ jobs.Job) error {
	var firstErr error
	for _, check := range []func(context.Context) error{h.checkQueueAge, h.checkEmailDeadRate, h.checkStuckRunning} {
		if err := check(ctx); err != nil {
			slog.ErrorContext(ctx, "handlers.ops_health: check failed", "error", err)
			if firstErr == nil {
				firstErr = err
			}
		}
	}
	return firstErr
}

func (h *OpsHealthHandler) raise(ctx context.Context, condition, title, body string) error {
	bucket := time.Now().Unix() / int64(healthAlertBucket.Seconds())
	return h.alert.NotifyPlatformAdmins(ctx, opsalert.Alert{
		Type: opsalert.TypeHealth, Title: title, Body: body, LinkURL: opsalert.AdminJobsLink,
		DedupeKey: fmt.Sprintf("opshealth:%s:%d", condition, bucket),
		Priority:  notifications.PriorityHigh,
	})
}

// checkQueueAge alerts when the oldest runnable queued job waited too long.
func (h *OpsHealthHandler) checkQueueAge(ctx context.Context) error {
	var queued int
	var oldest *time.Time
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*), MIN(run_at) FROM jobs
		 WHERE status = 'queued' AND job_type = 'one_time' AND deleted_at IS NULL
		   AND run_at < NOW() - make_interval(mins => $1)`,
		h.cfg.OpsQueueStaleMinutes,
	).Scan(&queued, &oldest); err != nil {
		return fmt.Errorf("handlers.ops_health: queue age: %w", err)
	}
	if queued == 0 || oldest == nil {
		return nil
	}
	return h.raise(ctx, "queue_stale",
		fmt.Sprintf("Job queue backed up: %d jobs waiting over %d min", queued, h.cfg.OpsQueueStaleMinutes),
		fmt.Sprintf("Oldest queued job has been waiting since %s. Workers may be down or saturated.", oldest.UTC().Format(time.RFC3339)))
}

// checkEmailDeadRate alerts when most recently finished email.send jobs died.
func (h *OpsHealthHandler) checkEmailDeadRate(ctx context.Context) error {
	var dead, total int
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FILTER (WHERE status = 'dead'), COUNT(*) FROM jobs
		 WHERE handler = $1 AND status IN ('dead', 'success')
		   AND updated_at > NOW() - make_interval(secs => $2)`,
		HandlerEmailSend, emailDeadRateWindow.Seconds(),
	).Scan(&dead, &total); err != nil {
		return fmt.Errorf("handlers.ops_health: email dead rate: %w", err)
	}
	if total < h.cfg.OpsEmailDeadMinSample || dead*100 < h.cfg.OpsEmailDeadRatePercent*total {
		return nil
	}
	return h.raise(ctx, "email_dead_rate",
		fmt.Sprintf("Email delivery failing: %d of %d email jobs dead in %d min", dead, total, int(emailDeadRateWindow.Minutes())),
		"Likely SMTP outage or credential problem. Check the mail provider and SMTP settings.")
}

// checkStuckRunning alerts on jobs running past a multiple of their timeout.
func (h *OpsHealthHandler) checkStuckRunning(ctx context.Context) error {
	var stuck int
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM jobs
		 WHERE status = 'running' AND deleted_at IS NULL AND claimed_at IS NOT NULL
		   AND claimed_at < NOW() - make_interval(secs => timeout_ms * $1 / 1000.0)`,
		stuckRunningTimeoutFactor,
	).Scan(&stuck); err != nil {
		return fmt.Errorf("handlers.ops_health: stuck running: %w", err)
	}
	if stuck == 0 {
		return nil
	}
	return h.raise(ctx, "stuck_running",
		fmt.Sprintf("%d jobs stuck running beyond %dx their timeout", stuck, stuckRunningTimeoutFactor),
		"A worker may have hung or crashed without releasing the job.")
}

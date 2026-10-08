package handlers

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/opsalert"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/stretchr/testify/require"
)

type opsNoop struct{}

func (opsNoop) Handle(context.Context, jobs.Job) error { return nil }

// opsEnv seeds one super admin with an org and returns the alert service.
func opsEnv(t *testing.T) (*pgxpool.Pool, *opsalert.Service, *config.Config, string) {
	t.Helper()
	pool := testdb.New(t)
	ctx := context.Background()
	var org, user string
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('ops','ops-org') RETURNING id`).Scan(&org))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (email, name, platform_role) VALUES ('ops-super@ops.test','s','super_admin') RETURNING id`).Scan(&user))
	_, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1,$2,'learner')`, org, user)
	require.NoError(t, err)
	reg := jobs.NewRegistry()
	reg.Register(HandlerEmailSend, opsNoop{})
	cfg := &config.Config{OpsQueueStaleMinutes: 15, OpsEmailDeadRatePercent: 50, OpsEmailDeadMinSample: 5}
	return pool, opsalert.NewService(pool, notifications.NewService(pool, reg)), cfg, org
}

func opsExec(t *testing.T, pool *pgxpool.Pool, sql string, args ...any) {
	t.Helper()
	_, err := pool.Exec(context.Background(), sql, args...)
	require.NoError(t, err)
}

func healthCount(t *testing.T, pool *pgxpool.Pool, dedupePrefix string) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM notifications WHERE type = $1 AND dedupe_key LIKE $2`, opsalert.TypeHealth, dedupePrefix+"%").Scan(&n))
	return n
}

func TestOpsHealth_QueueAge(t *testing.T) {
	pool, svc, cfg, _ := opsEnv(t)
	h := NewOpsHealthHandler(pool, cfg, svc)
	ctx := context.Background()

	opsExec(t, pool, `INSERT INTO jobs (handler, status, run_at) VALUES ('x', 'queued', NOW() - interval '5 minutes')`)
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.Equal(t, 0, healthCount(t, pool, "opshealth:queue_stale"))

	opsExec(t, pool, `INSERT INTO jobs (handler, status, run_at) VALUES ('x', 'queued', NOW() - interval '20 minutes')`)
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.Equal(t, 1, healthCount(t, pool, "opshealth:queue_stale"), "deduped per hour bucket")
}

func TestOpsHealth_EmailDeadRate(t *testing.T) {
	pool, svc, cfg, _ := opsEnv(t)
	h := NewOpsHealthHandler(pool, cfg, svc)
	ctx := context.Background()

	for i := 0; i < 6; i++ {
		opsExec(t, pool, `INSERT INTO jobs (handler, status) VALUES ('email.send', 'success')`)
	}
	opsExec(t, pool, `INSERT INTO jobs (handler, status) VALUES ('email.send', 'dead')`)
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.Equal(t, 0, healthCount(t, pool, "opshealth:email_dead_rate"), "low rate must not fire")

	for i := 0; i < 8; i++ {
		opsExec(t, pool, `INSERT INTO jobs (handler, status) VALUES ('email.send', 'dead')`)
	}
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.Equal(t, 1, healthCount(t, pool, "opshealth:email_dead_rate"))
}

func TestOpsHealth_EmailDeadRateBelowMinSample(t *testing.T) {
	pool, svc, cfg, _ := opsEnv(t)
	for i := 0; i < 3; i++ {
		opsExec(t, pool, `INSERT INTO jobs (handler, status) VALUES ('email.send', 'dead')`)
	}
	require.NoError(t, NewOpsHealthHandler(pool, cfg, svc).Handle(context.Background(), jobs.Job{}))
	require.Equal(t, 0, healthCount(t, pool, "opshealth:email_dead_rate"))
}

func TestOpsHealth_StuckRunning(t *testing.T) {
	pool, svc, cfg, _ := opsEnv(t)
	h := NewOpsHealthHandler(pool, cfg, svc)
	ctx := context.Background()

	opsExec(t, pool, `INSERT INTO jobs (handler, status, timeout_ms, claimed_at) VALUES ('x', 'running', 60000, NOW() - interval '90 seconds')`)
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.Equal(t, 0, healthCount(t, pool, "opshealth:stuck_running"), "within 2x timeout")

	opsExec(t, pool, `INSERT INTO jobs (handler, status, timeout_ms, claimed_at) VALUES ('x', 'running', 60000, NOW() - interval '3 minutes')`)
	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.Equal(t, 1, healthCount(t, pool, "opshealth:stuck_running"))
}

func TestOpsDigest_SkipsWhenEmptyAndSummarisesOtherwise(t *testing.T) {
	pool, svc, _, org := opsEnv(t)
	h := NewOpsDigestHandler(pool, svc)
	ctx := context.Background()

	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	var n int
	require.NoError(t, pool.QueryRow(ctx, `SELECT COUNT(*) FROM notifications`).Scan(&n))
	require.Equal(t, 0, n, "all-zero digest must be skipped")

	var admin string
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('oa@ops.test','oa') RETURNING id`).Scan(&admin))
	opsExec(t, pool, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1,$2,'admin')`, org, admin)
	opsExec(t, pool, `INSERT INTO jobs (handler, status, org_id) VALUES ('retention.purge', 'dead', $1)`, org)
	opsExec(t, pool, `INSERT INTO jobs (handler, status) VALUES ('email.send', 'dead')`)

	require.NoError(t, h.Handle(ctx, jobs.Job{}))
	require.NoError(t, h.Handle(ctx, jobs.Job{}))

	require.NoError(t, pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE type = $1 AND user_id = $2 AND body LIKE '%retention.purge: 1%'`,
		opsalert.TypeDigest, admin).Scan(&n))
	require.Equal(t, 1, n, "org admin gets only their org's numbers, once per day")
	require.NoError(t, pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE type = $1 AND body LIKE '%email.send: 1%' AND body LIKE '%retention.purge: 1%'`,
		opsalert.TypeDigest).Scan(&n))
	require.Equal(t, 1, n, "super admin gets the platform-wide digest")
}

package opsalert_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/opsalert"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/stretchr/testify/require"
)

type noopHandler struct{}

func (noopHandler) Handle(context.Context, jobs.Job) error { return nil }

func newSvc(t *testing.T) (*opsalert.Service, *pgxpool.Pool) {
	t.Helper()
	pool := testdb.New(t)
	reg := jobs.NewRegistry()
	reg.Register("email.send", noopHandler{})
	return opsalert.NewService(pool, notifications.NewService(pool, reg)), pool
}

func seedOrg(t *testing.T, pool *pgxpool.Pool, slug string) string {
	t.Helper()
	var id string
	require.NoError(t, pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ($1, $1) RETURNING id`, slug).Scan(&id))
	return id
}

func seedUser(t *testing.T, pool *pgxpool.Pool, name, platformRole string) string {
	t.Helper()
	var id string
	require.NoError(t, pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, platform_role) VALUES ($1, $2, $3) RETURNING id`,
		name+"@ops-alert.test", name, platformRole).Scan(&id))
	return id
}

func join(t *testing.T, pool *pgxpool.Pool, orgID, userID, role, joinedAt string) {
	t.Helper()
	_, err := pool.Exec(context.Background(),
		`INSERT INTO org_members (org_id, user_id, role, joined_at) VALUES ($1, $2, $3, $4::timestamptz)`,
		orgID, userID, role, joinedAt)
	require.NoError(t, err)
}

func insertDead(t *testing.T, pool *pgxpool.Pool, handler string, orgID *string, n int) {
	t.Helper()
	for i := 0; i < n; i++ {
		_, err := pool.Exec(context.Background(),
			`INSERT INTO jobs (handler, status, org_id, last_error) VALUES ($1, 'dead', $2, 'boom')`, handler, orgID)
		require.NoError(t, err)
	}
}

func count(t *testing.T, pool *pgxpool.Pool, where string, args ...any) int {
	t.Helper()
	var n int
	require.NoError(t, pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM `+where, args...).Scan(&n))
	return n
}

func deadJob(handler string, orgID *string) jobs.Job {
	msg := "boom"
	return jobs.Job{ID: "00000000-0000-0000-0000-000000000001", Handler: handler, OrgID: orgID, LastError: &msg, RetryCount: 3, MaxRetries: 3}
}

func TestOrgJobRoutesToOrgOwnersAndAdminsOnly(t *testing.T) {
	svc, pool := newSvc(t)
	org := seedOrg(t, pool, "org-a")
	owner, admin, learner := seedUser(t, pool, "owner", "user"), seedUser(t, pool, "admin", "user"), seedUser(t, pool, "learner", "user")
	super := seedUser(t, pool, "super", "super_admin")
	join(t, pool, org, owner, "owner", "2024-01-01")
	join(t, pool, org, admin, "admin", "2024-01-01")
	join(t, pool, org, learner, "learner", "2024-01-01")
	join(t, pool, org, super, "learner", "2024-01-01")

	insertDead(t, pool, "some.handler", &org, 1)
	svc.OnJobDead(context.Background(), deadJob("some.handler", &org))

	require.Equal(t, 2, count(t, pool, `notifications WHERE type = $1`, opsalert.TypeJobDead))
	require.Equal(t, 1, count(t, pool, `notifications WHERE user_id = $1`, owner))
	require.Equal(t, 1, count(t, pool, `notifications WHERE user_id = $1`, admin))
	require.Equal(t, 0, count(t, pool, `notifications WHERE user_id = $1`, learner))
	require.Equal(t, 0, count(t, pool, `notifications WHERE user_id = $1`, super))
	require.Equal(t, 0, count(t, pool, `jobs WHERE handler = 'email.send'`), "normal severity must not email")
}

func TestPlatformJobRoutesToSuperAdminsWithOldestOrg(t *testing.T) {
	svc, pool := newSvc(t)
	oldOrg, newOrg := seedOrg(t, pool, "org-old"), seedOrg(t, pool, "org-new")
	super, noOrg := seedUser(t, pool, "super", "super_admin"), seedUser(t, pool, "noorg", "super_admin")
	join(t, pool, newOrg, super, "learner", "2025-01-01")
	join(t, pool, oldOrg, super, "learner", "2023-01-01")
	_ = noOrg

	insertDead(t, pool, "some.handler", nil, 1)
	svc.OnJobDead(context.Background(), deadJob("some.handler", nil))

	require.Equal(t, 1, count(t, pool, `notifications`), "super admin without an org is skipped")
	require.Equal(t, 1, count(t, pool, `notifications WHERE user_id = $1 AND org_id = $2`, super, oldOrg))
}

func TestDedupeWindowCollapsesRepeats(t *testing.T) {
	svc, pool := newSvc(t)
	org := seedOrg(t, pool, "org-a")
	admin := seedUser(t, pool, "admin", "user")
	join(t, pool, org, admin, "admin", "2024-01-01")

	for i := 0; i < 3; i++ {
		insertDead(t, pool, "some.handler", &org, 1)
		svc.OnJobDead(context.Background(), deadJob("some.handler", &org))
	}
	require.Equal(t, 1, count(t, pool, `notifications`))
}

func TestStormEmitsOneStormAlertInsteadOfPerJob(t *testing.T) {
	svc, pool := newSvc(t)
	org := seedOrg(t, pool, "org-a")
	admin := seedUser(t, pool, "admin", "user")
	join(t, pool, org, admin, "admin", "2024-01-01")
	_, err := pool.Exec(context.Background(),
		`UPDATE ops_alert_rules SET storm_threshold = 3, dedupe_window_minutes = 1 WHERE handler = '*'`)
	require.NoError(t, err)

	for i := 0; i < 6; i++ {
		insertDead(t, pool, "some.handler", &org, 1)
		svc.OnJobDead(context.Background(), deadJob("some.handler", &org))
	}
	require.Equal(t, 1, count(t, pool, `notifications WHERE type = $1`, opsalert.TypeJobStorm))
	// Only deaths before the threshold was crossed may have produced per-job alerts.
	require.LessOrEqual(t, count(t, pool, `notifications WHERE type = $1`, opsalert.TypeJobDead), 3)
	var title string
	require.NoError(t, pool.QueryRow(context.Background(),
		`SELECT title FROM notifications WHERE type = $1`, opsalert.TypeJobStorm).Scan(&title))
	require.Contains(t, title, "likely systemic outage")
}

func TestHighSeverityEnqueuesEmailExceptForEmailSend(t *testing.T) {
	svc, pool := newSvc(t)
	org := seedOrg(t, pool, "org-a")
	admin := seedUser(t, pool, "admin", "user")
	join(t, pool, org, admin, "admin", "2024-01-01")

	insertDead(t, pool, "retention.purge", &org, 1)
	svc.OnJobDead(context.Background(), deadJob("retention.purge", &org))
	require.Equal(t, 1, count(t, pool, `jobs WHERE handler = 'email.send'`))
	require.Equal(t, 1, count(t, pool, `notifications WHERE priority = 'high'`))

	insertDead(t, pool, "email.send", &org, 1)
	svc.OnJobDead(context.Background(), deadJob("email.send", &org))
	require.Equal(t, 1, count(t, pool, `jobs WHERE handler = 'email.send' AND status <> 'dead'`),
		"a dead email.send alert must not enqueue another email")
}

func TestDisabledRuleSuppresses(t *testing.T) {
	svc, pool := newSvc(t)
	org := seedOrg(t, pool, "org-a")
	admin := seedUser(t, pool, "admin", "user")
	join(t, pool, org, admin, "admin", "2024-01-01")
	_, err := svc.UpsertRule(context.Background(), opsalert.Rule{
		Handler: "quiet.handler", Severity: "normal", DedupeWindowMinutes: 15, StormThreshold: 10, StormWindowMinutes: 10, Enabled: false})
	require.NoError(t, err)

	svc.OnJobDead(context.Background(), deadJob("quiet.handler", &org))
	require.Equal(t, 0, count(t, pool, `notifications`))
}

func TestRuleValidation(t *testing.T) {
	svc, _ := newSvc(t)
	base := opsalert.Rule{Handler: "h", Severity: "normal", DedupeWindowMinutes: 15, StormThreshold: 10, StormWindowMinutes: 10, Enabled: true}
	for name, mutate := range map[string]func(*opsalert.Rule){
		"severity": func(r *opsalert.Rule) { r.Severity = "urgent" },
		"dedupe":   func(r *opsalert.Rule) { r.DedupeWindowMinutes = 0 },
		"storm":    func(r *opsalert.Rule) { r.StormThreshold = 0 },
		"window":   func(r *opsalert.Rule) { r.StormWindowMinutes = 5000 },
		"handler":  func(r *opsalert.Rule) { r.Handler = "" },
	} {
		r := base
		mutate(&r)
		_, err := svc.UpsertRule(context.Background(), r)
		require.ErrorIs(t, err, opsalert.ErrInvalidRule, fmt.Sprintf("case %s", name))
	}
	saved, err := svc.UpsertRule(context.Background(), base)
	require.NoError(t, err)
	require.Equal(t, "h", saved.Handler)
}

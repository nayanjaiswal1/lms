package handlers

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/mailer"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/redis/go-redis/v9"
)

type fakeSender struct {
	calls   atomic.Int32
	subject string
	err     error
}

func (f *fakeSender) Send(_ context.Context, _, subject, _ string, _ map[string]string) error {
	f.calls.Add(1)
	f.subject = subject
	return f.err
}

func testCfg() *config.Config {
	return &config.Config{
		Env: "production", FrontendURL: "http://x", EmailBreakerThreshold: 2,
		EmailBreakerCooldown: time.Minute, EmailThrottleBackoff: 7 * time.Minute,
		EmailOrgMaxPerMinute: 100, EmailOrgMaxPerDay: 1000,
	}
}

// deadRedis is unreachable, so breaker/quota run on their in-process fallback.
func deadRedis() *redis.Client {
	return redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1, DialTimeout: 50 * time.Millisecond})
}

func newEmailHandler(cfg *config.Config, s mailer.Sender, pool *pgxpool.Pool) *EmailHandler {
	return NewEmailHandler(cfg, s, pool, deadRedis())
}

func emailJob(orgID *string, p EmailPayload) jobs.Job {
	b, _ := json.Marshal(p)
	return jobs.Job{ID: "j1", Payload: b, OrgID: orgID}
}

func notif(to string) EmailPayload {
	return EmailPayload{Type: emailTypeNotification, To: to, TemplateData: map[string]any{"subject": "s", "body": "b"}}
}

func seedOrg(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ('Q', 'q-' || substr(md5(random()::text),1,8)) RETURNING id`).Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

func TestMalformedAddressIsPermanentWithoutSend(t *testing.T) {
	s := &fakeSender{}
	h := newEmailHandler(testCfg(), s, nil)
	for _, to := range []string{"not-an-address", "Bob <bob@x.com>", "a@"} {
		err := h.Handle(context.Background(), emailJob(nil, notif(to)))
		if !errors.As(err, new(*jobs.PermanentError)) {
			t.Fatalf("%q: want Permanent, got %v", to, err)
		}
	}
	if s.calls.Load() != 0 {
		t.Fatal("sender must not be called for a malformed address")
	}
}

// throttlingSMTP accepts connections and answers RCPT TO with 451.
func throttlingSMTP(t *testing.T) (string, *atomic.Int32) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	rcpts := new(atomic.Int32)
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				defer c.Close()
				fmt.Fprint(c, "220 fake\r\n")
				r := bufio.NewReader(c)
				for {
					line, err := r.ReadString('\n')
					if err != nil {
						return
					}
					switch cmd := strings.ToUpper(line); {
					case strings.HasPrefix(cmd, "RCPT"):
						rcpts.Add(1)
						fmt.Fprint(c, "451 4.7.1 slow down\r\n")
					case strings.HasPrefix(cmd, "QUIT"):
						fmt.Fprint(c, "221 bye\r\n")
						return
					default:
						fmt.Fprint(c, "250 ok\r\n")
					}
				}
			}()
		}
	}()
	_, port, _ := net.SplitHostPort(ln.Addr().String())
	return port, rcpts
}

func TestThrottleDefersAndBreakerOpens(t *testing.T) {
	port, rcpts := throttlingSMTP(t)
	h := newEmailHandler(testCfg(), mailer.NewSMTPSender("127.0.0.1", port, "", "", "f@x.com"), nil)
	ctx := context.Background()

	for i := 0; i < 2; i++ {
		err := h.Handle(ctx, emailJob(nil, notif("a@x.com")))
		var ra *jobs.RetryAfterError
		if !errors.As(err, &ra) || ra.After != 7*time.Minute {
			t.Fatalf("attempt %d: want RetryAfter(7m), got %v", i, err)
		}
		if errors.As(err, new(*jobs.PermanentError)) {
			t.Fatal("throttle must not be permanent")
		}
	}
	// Threshold (2) reached: breaker open, SMTP not contacted again.
	err := h.Handle(ctx, emailJob(nil, notif("a@x.com")))
	var ra *jobs.RetryAfterError
	if !errors.As(err, &ra) || !strings.Contains(err.Error(), "circuit open") {
		t.Fatalf("want circuit-open RetryAfter, got %v", err)
	}
	if rcpts.Load() != 2 {
		t.Fatalf("SMTP RCPT count = %d, want 2", rcpts.Load())
	}
}

func TestOrgQuotaBlocksThenReleases(t *testing.T) {
	pool := testdb.New(t)
	org := seedOrg(t, pool)
	cfg := testCfg()
	cfg.EmailOrgMaxPerMinute = 2
	s := &fakeSender{}
	h := newEmailHandler(cfg, s, pool)
	ctx := context.Background()
	job := emailJob(&org, notif("a@x.com"))

	for i := 0; i < 2; i++ {
		if err := h.Handle(ctx, job); err != nil {
			t.Fatalf("send %d: %v", i, err)
		}
	}
	var ra *jobs.RetryAfterError
	if err := h.Handle(ctx, job); !errors.As(err, &ra) || ra.After <= 0 || ra.After > time.Minute {
		t.Fatalf("third send should defer <=1m, got %v", err)
	}
	if s.calls.Load() != 2 {
		t.Fatalf("sender calls = %d, want 2", s.calls.Load())
	}
	// Per-org override raises the cap: the next send goes through.
	if _, err := pool.Exec(ctx, `INSERT INTO org_settings (org_id, jobs) VALUES ($1, '{"email_max_per_minute": 10}')`, org); err != nil {
		t.Fatal(err)
	}
	if err := h.Handle(ctx, job); err != nil {
		t.Fatalf("after override: %v", err)
	}
}

func TestAccountNoticeTypesSendViaSender(t *testing.T) {
	for typ, want := range map[string]string{
		emailTypeDuplicateRegistration: "You already have a MindForge account",
		emailTypePasskeyCloneAlert:     "Unusual passkey activity on your MindForge account",
	} {
		s := &fakeSender{}
		h := newEmailHandler(testCfg(), s, nil)
		if err := h.Handle(context.Background(), emailJob(nil, EmailPayload{Type: typ, To: "u@x.com"})); err != nil {
			t.Fatalf("%s: %v", typ, err)
		}
		if s.calls.Load() != 1 || s.subject != want {
			t.Fatalf("%s: calls=%d subject=%q", typ, s.calls.Load(), s.subject)
		}
	}
}

func seedInvite(t *testing.T, pool *pgxpool.Pool, org, email string) string {
	t.Helper()
	var uid, id string
	ctx := context.Background()
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('inviter-'||substr(md5(random()::text),1,8)||'@mindforge.test','I') RETURNING id`).Scan(&uid); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO org_invites (org_id, email, role, invited_by_user_id, token_hash, expires_at)
		 VALUES ($1,$2,'learner',$3,md5(random()::text), now()+interval '7 days') RETURNING id`, org, email, uid).Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

func inviteStatus(t *testing.T, pool *pgxpool.Pool, id string) (string, string) {
	t.Helper()
	var st string
	var e *string
	if err := pool.QueryRow(context.Background(), `SELECT email_status, email_error FROM org_invites WHERE id=$1`, id).Scan(&st, &e); err != nil {
		t.Fatal(err)
	}
	if e == nil {
		return st, ""
	}
	return st, *e
}

func TestOrgInviteEmailStatusTransitions(t *testing.T) {
	pool := testdb.New(t)
	org := seedOrg(t, pool)
	ctx := context.Background()
	payload := func(id, to string) EmailPayload {
		return EmailPayload{Type: emailTypeOrgInvite, To: to,
			TemplateData: map[string]any{"token": "t", "role": "learner", "invite_id": id}}
	}

	okID := seedInvite(t, pool, org, "n@x.com")
	if st, _ := inviteStatus(t, pool, okID); st != "pending" {
		t.Fatalf("default status = %s", st)
	}
	if err := newEmailHandler(testCfg(), &fakeSender{}, pool).Handle(ctx, emailJob(&org, payload(okID, "n@x.com"))); err != nil {
		t.Fatal(err)
	}
	if st, _ := inviteStatus(t, pool, okID); st != "sent" {
		t.Fatalf("status after send = %s, want sent", st)
	}

	// Permanent rejection => failed with the error recorded.
	failID := seedInvite(t, pool, org, "m@x.com")
	h := newEmailHandler(testCfg(), &fakeSender{err: jobs.Permanent(errors.New("550 mailbox unavailable"))}, pool)
	if err := h.Handle(ctx, emailJob(&org, payload(failID, "m@x.com"))); err == nil {
		t.Fatal("want error")
	}
	if st, e := inviteStatus(t, pool, failID); st != "failed" || e == "" {
		t.Fatalf("status = %s err=%q, want failed with error", st, e)
	}

	// Dead hook flips a still-pending invite to failed.
	deadID := seedInvite(t, pool, org, "d@x.com")
	pd, _ := json.Marshal(payload(deadID, "d@x.com"))
	le := "retries exhausted"
	NewEmailDeadHook(pool)(ctx, jobs.Job{Payload: pd, LastError: &le})
	if st, _ := inviteStatus(t, pool, deadID); st != "failed" {
		t.Fatalf("dead hook status = %s", st)
	}
}

func TestInviteDeadHookMarksUnsentChunkFailed(t *testing.T) {
	pool := testdb.New(t)
	org := seedOrg(t, pool)
	ctx := context.Background()
	unsent := seedInvite(t, pool, org, "u1@x.com")
	sent := seedInvite(t, pool, org, "u2@x.com")
	setInviteEmailStatus(ctx, pool, sent, inviteEmailSent, "")

	pl, _ := json.Marshal(BulkInvitePayload{OrgID: org, Emails: []string{"U1@x.com", "u2@x.com"}, Role: "learner"})
	le := "db down"
	NewInviteDeadHook(pool)(ctx, jobs.Job{Payload: pl, LastError: &le})

	if st, e := inviteStatus(t, pool, unsent); st != "failed" || !strings.Contains(e, "db down") {
		t.Fatalf("unsent: %s %q", st, e)
	}
	if st, _ := inviteStatus(t, pool, sent); st != "sent" {
		t.Fatalf("already-sent invite must stay sent, got %s", st)
	}
}

func TestInviteBulkRecordsPerInviteResult(t *testing.T) {
	pool := testdb.New(t)
	org := seedOrg(t, pool)
	ctx := context.Background()
	var owner string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('own@mindforge.test','O') RETURNING id`).Scan(&owner); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1,$2,'owner')`, org, owner); err != nil {
		t.Fatal(err)
	}
	// Dev mode: only the allowlisted address attempts real SMTP (refused port => failed);
	// the other is suppressed (treated as delivered => sent).
	cfg := &config.Config{Env: "development", FrontendURL: "http://x", EmailFrom: "f@x.com",
		SMTPHost: "127.0.0.1", SMTPPort: "1", DevEmailAllowlist: []string{"real@x.com"}}
	pl, _ := json.Marshal(BulkInvitePayload{OrgID: org, InviterID: owner, Role: "learner", Emails: []string{"real@x.com", "dev@x.com"}})
	if err := NewInviteHandler(pool, cfg).Handle(ctx, jobs.Job{Payload: pl}); err != nil {
		t.Fatal(err)
	}
	for email, want := range map[string]string{"real@x.com": "failed", "dev@x.com": "sent"} {
		var st string
		if err := pool.QueryRow(ctx, `SELECT email_status FROM org_invites WHERE org_id=$1 AND email=$2`, org, email).Scan(&st); err != nil || st != want {
			t.Fatalf("%s: status=%q err=%v want %s", email, st, err, want)
		}
	}
}

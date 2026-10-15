package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestWithinReuseGrace(t *testing.T) {
	now := time.Now()
	ago := func(d time.Duration) *time.Time { v := now.Add(-d); return &v }
	grace := 30 * time.Second

	cases := []struct {
		name      string
		rotatedAt *time.Time
		grace     time.Duration
		want      bool
	}{
		{"never rotated", nil, grace, false},
		{"just rotated", ago(time.Second), grace, true},
		{"exactly at the edge", ago(grace), grace, true},
		{"past the window", ago(grace + time.Second), grace, false},
		{"zero grace disables it", ago(time.Millisecond), 0, false},
	}
	for _, c := range cases {
		if got := withinReuseGrace(c.rotatedAt, now, c.grace); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

func TestClassifyReplay(t *testing.T) {
	now := time.Now()
	ago := func(d time.Duration) *time.Time { v := now.Add(-d); return &v }
	grace := 30 * time.Second

	cases := []struct {
		name          string
		rotatedAt     *time.Time
		successorLive bool
		want          replayAction
	}{
		{"in grace, successor live: reissue it", ago(time.Second), true, replayReissueSuccessor},
		{"in grace, successor gone: reject without revoking", ago(time.Second), false, replayReject},
		{"after grace, successor live: theft", ago(grace + time.Second), true, replayRevokeFamily},
		{"after grace, successor gone: theft", ago(grace + time.Second), false, replayRevokeFamily},
		{"revoked, never rotated: theft", nil, true, replayRevokeFamily},
	}
	for _, c := range cases {
		if got := classifyReplay(c.rotatedAt, now, grace, c.successorLive); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

func TestSuccessorRefreshTokenDeterministic(t *testing.T) {
	cfg := &config.Config{CookieSecret: "successor-test-secret"}
	a, ah := successorRefreshToken(cfg, "parent")
	b, bh := successorRefreshToken(cfg, "parent")
	if a != b || ah != bh || ah != HashToken(a) {
		t.Fatalf("successor not deterministic: %s/%s vs %s/%s", a, ah, b, bh)
	}
	if c, _ := successorRefreshToken(cfg, "other"); c == a {
		t.Fatal("different parents derived the same successor")
	}
	if d, _ := successorRefreshToken(&config.Config{CookieSecret: "other-secret"}, "parent"); d == a {
		t.Fatal("successor does not depend on the secret")
	}
}

// TestHandleRefreshReplay drives the real handler: a replay of a just-rotated
// token inside the grace window must hand back the very successor the first
// call issued (no revocation), and the same replay after the window must
// revoke the whole family.
func TestHandleRefreshReplay(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	cfg := &config.Config{
		JWTSecret:         "refresh-replay-test-jwt-secret",
		CookieSecret:      "refresh-replay-test-cookie-secret",
		AccessTokenTTL:    time.Minute,
		RefreshTokenTTL:   time.Hour,
		RefreshReuseGrace: 30 * time.Second,
		DefaultOrgID:      "00000000-0000-0000-0000-000000000001",
	}
	h := &Handler{cfg: cfg, pool: pool}

	var userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, 'U') RETURNING id`,
		"refresh-replay@"+testdomain.Domain,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	familyID, parent := seedSession(t, pool, userID, "laptop")

	refresh := func(token string) (int, string) {
		req := httptest.NewRequest(http.MethodPost, "/api/auth/refresh", nil)
		req.AddCookie(&http.Cookie{Name: "refresh_token", Value: token})
		rec := httptest.NewRecorder()
		h.HandleRefresh(rec, req)
		for _, c := range rec.Result().Cookies() {
			if c.Name == "refresh_token" {
				return rec.Code, c.Value
			}
		}
		return rec.Code, ""
	}
	liveInFamily := func() int {
		var n int
		if err := pool.QueryRow(ctx,
			`SELECT count(*) FROM refresh_tokens WHERE family_id = $1 AND revoked_at IS NULL`, familyID,
		).Scan(&n); err != nil {
			t.Fatalf("count live tokens: %v", err)
		}
		return n
	}

	code, successor := refresh(parent)
	if code != http.StatusOK || successor == "" {
		t.Fatalf("first refresh = %d cookie %q, want 200 with a refresh cookie", code, successor)
	}

	code, replayed := refresh(parent)
	if code != http.StatusOK {
		t.Fatalf("replay within grace = %d, want 200", code)
	}
	if replayed != successor {
		t.Fatalf("replay within grace set refresh_token %q, want the already-issued successor %q", replayed, successor)
	}
	if n := liveInFamily(); n != 1 {
		t.Fatalf("live tokens after in-grace replay = %d, want 1", n)
	}

	if _, err := pool.Exec(ctx,
		`UPDATE refresh_tokens SET rotated_at = rotated_at - interval '1 minute' WHERE token_hash = $1`,
		HashToken(parent),
	); err != nil {
		t.Fatalf("age rotation: %v", err)
	}
	if code, _ := refresh(parent); code != http.StatusUnauthorized {
		t.Fatalf("replay after grace = %d, want 401", code)
	}
	if n := liveInFamily(); n != 0 {
		t.Fatalf("live tokens after out-of-grace replay = %d, want 0 (family revoked)", n)
	}
	if code, _ := refresh(successor); code != http.StatusUnauthorized {
		t.Fatalf("successor after family revoke = %d, want 401", code)
	}
}

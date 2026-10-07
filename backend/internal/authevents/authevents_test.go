package authevents

import (
	"context"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

func TestTruncateIP(t *testing.T) {
	cases := map[string]string{
		"203.0.113.77:5555":    "203.0.113",
		"[2001:db8:1:2::9]:80": "2001:db8:1::",
		"not-an-ip":            "not-an-ip",
	}
	for in, want := range cases {
		if got := TruncateIP(in); got != want {
			t.Errorf("TruncateIP(%q) = %q, want %q", in, got, want)
		}
	}
}

// Emit stores a truncated IP and a UA hash; the table then refuses UPDATE and
// DELETE.
func TestEmitIsAppendOnly(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	var userID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('ev@example.com', 'Ev') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	req := httptest.NewRequest("POST", "/", nil)
	req.RemoteAddr = "203.0.113.77:5555"
	req.Header.Set("User-Agent", "test-agent")

	Emit(ctx, pool, req, userID, Login)

	var event, ip, ua string
	if err := pool.QueryRow(ctx, `SELECT event, ip, ua_hash FROM auth_events WHERE user_id = $1`, userID).Scan(&event, &ip, &ua); err != nil {
		t.Fatalf("read event: %v", err)
	}
	if event != Login || ip != "203.0.113" || ua != UAHash("test-agent") {
		t.Fatalf("unexpected row: %q %q %q", event, ip, ua)
	}
	if _, err := pool.Exec(ctx, `UPDATE auth_events SET event = 'x' WHERE user_id = $1`, userID); err == nil {
		t.Fatal("UPDATE must be denied")
	}
	if _, err := pool.Exec(ctx, `DELETE FROM auth_events WHERE user_id = $1`, userID); err == nil {
		t.Fatal("DELETE must be denied")
	}
}

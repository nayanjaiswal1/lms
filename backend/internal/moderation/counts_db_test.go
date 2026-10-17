package moderation

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// ReportCounts zero-fills every status, counts only the caller's org, and
// reports pending + reviewing as open.
func TestReportCounts(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	var orgA, orgB, user string
	for _, q := range []struct {
		dst  *string
		sql  string
		args []any
	}{
		{&orgA, `INSERT INTO organizations (slug, name) VALUES ('mod-a', 'A') RETURNING id`, nil},
		{&orgB, `INSERT INTO organizations (slug, name) VALUES ('mod-b', 'B') RETURNING id`, nil},
		{&user, `INSERT INTO users (email, name) VALUES ($1, 'Reporter') RETURNING id`, []any{"reporter@" + testdomain.Domain}},
	} {
		if err := pool.QueryRow(ctx, q.sql, q.args...).Scan(q.dst); err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	for _, r := range []struct{ org, status string }{
		{orgA, StatusPending}, {orgA, StatusPending}, {orgA, StatusReviewing}, {orgA, StatusDismissed}, {orgB, StatusPending},
	} {
		if _, err := pool.Exec(ctx,
			`INSERT INTO content_reports (org_id, reporter_id, content_type, content_id, reason, status)
			 VALUES ($1, $2, 'user', gen_random_uuid(), 'spam', $3)`, r.org, user, r.status); err != nil {
			t.Fatalf("seed report: %v", err)
		}
	}

	counts, open, err := NewService(NewRepo(pool)).ReportCounts(ctx, orgA)
	if err != nil {
		t.Fatalf("ReportCounts: %v", err)
	}
	want := map[string]int{StatusPending: 2, StatusReviewing: 1, StatusRemoved: 0, StatusDismissed: 1}
	if len(counts) != len(want) {
		t.Fatalf("counts = %v, want %v", counts, want)
	}
	for k, v := range want {
		if counts[k] != v {
			t.Errorf("counts[%s] = %d, want %d", k, counts[k], v)
		}
	}
	if open != 3 {
		t.Errorf("open = %d, want 3", open)
	}
}

package handlers

import (
	"context"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestWeeklyRecapKey(t *testing.T) {
	// 2027-01-01 still belongs to ISO week 53 of 2026.
	if got := WeeklyRecapKey(time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)); got != "2026-W53" {
		t.Errorf("got %s, want 2026-W53", got)
	}
}

// The fan-out enqueues one job per active, non-opted-out member, skips users
// who set notifications.weekly_recap=false, and is idempotent per ISO week.
func TestWeeklyRecapFanout_OptOutAndIdempotency(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	var orgID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('recap-org', 'Recap Org') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	seed := func(name, notifications string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
			name+"@"+testdomain.Domain, name).Scan(&id); err != nil {
			t.Fatalf("seed user %s: %v", name, err)
		}
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id) VALUES ($1, $2)`, orgID, id); err != nil {
			t.Fatalf("seed member %s: %v", name, err)
		}
		if notifications != "" {
			if _, err := pool.Exec(ctx, `INSERT INTO user_profiles (user_id, notifications) VALUES ($1, $2::jsonb)`, id, notifications); err != nil {
				t.Fatalf("seed profile %s: %v", name, err)
			}
		}
		return id
	}
	defaultOn := seed("default", "")
	explicitOn := seed("on", `{"weekly_recap": true}`)
	seed("off", `{"weekly_recap": false}`)

	h := NewWeeklyRecapHandler(pool)
	for run := 0; run < 2; run++ {
		if err := h.Handle(ctx, jobs.Job{}); err != nil {
			t.Fatalf("run %d: %v", run, err)
		}
	}

	rows, err := pool.Query(ctx, `SELECT payload->>'user_id' FROM jobs WHERE handler = $1`, HandlerWeeklyRecapUser)
	if err != nil {
		t.Fatalf("query jobs: %v", err)
	}
	defer rows.Close()
	got := map[string]int{}
	for rows.Next() {
		var uid string
		if err := rows.Scan(&uid); err != nil {
			t.Fatal(err)
		}
		got[uid]++
	}
	if len(got) != 2 || got[defaultOn] != 1 || got[explicitOn] != 1 {
		t.Fatalf("jobs per user = %v, want exactly one each for default and explicit-on users", got)
	}
}

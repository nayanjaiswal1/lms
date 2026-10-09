package roadmap

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/mindforge/backend/internal/testdb"
)

func TestReplan(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	userID := seedUser(t, ctx, pool)

	m1, m2, m3 := uuid.NewString(), uuid.NewString(), uuid.NewString()
	structure := `{"phases":[{"id":"` + uuid.NewString() + `","title":"P1","estimated_weeks":5,"keep":"x","milestones":[{"id":"` + uuid.NewString() + `","modules":[
	  {"id":"` + m1 + `","title":"a","estimated_minutes":120},{"id":"` + m2 + `","title":"b","estimated_minutes":240},{"id":"` + m3 + `","title":"c"}]}]}]}`
	var id string
	if err := pool.QueryRow(ctx,
		`INSERT INTO roadmaps (user_id, title, status, goal_description, timeframe_weeks, generated_at, structure)
		 VALUES ($1, 'R', 'active', 'g', 4, now() - interval '420 hours', $2::jsonb) RETURNING id`, userID, structure).Scan(&id); err != nil {
		t.Fatalf("seed: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO roadmap_module_progress (roadmap_id, module_key, completed_at) VALUES ($1, $2, now())`, id, m1); err != nil {
		t.Fatalf("seed progress: %v", err)
	}

	if _, err := repo.Replan(ctx, id, "00000000-0000-0000-0000-000000000000", time.Now()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("non-owner: want ErrNotFound, got %v", err)
	}

	rm, err := repo.Replan(ctx, id, userID, time.Now())
	if err != nil {
		t.Fatalf("Replan: %v", err)
	}
	// 2.5 weeks elapsed (ceil 3), 120 min done -> floor 120/wk pace (observed 40); 300 min left -> 3 weeks.
	if rm.TimeframeWeeks == nil || *rm.TimeframeWeeks != 6 {
		t.Fatalf("timeframe: %v", rm.TimeframeWeeks)
	}
	if rm.Phases[0].EstimatedWeeks == nil || *rm.Phases[0].EstimatedWeeks != 3 {
		t.Fatalf("phase weeks: %v", rm.Phases[0].EstimatedWeeks)
	}
	var rows int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM roadmap_module_progress WHERE roadmap_id = $1 AND completed_at IS NOT NULL`, id).Scan(&rows); err != nil || rows != 1 {
		t.Fatalf("completion rows changed: %d %v", rows, err)
	}
	var keep string
	if err := pool.QueryRow(ctx, `SELECT structure->'phases'->0->>'keep' FROM roadmaps WHERE id = $1`, id).Scan(&keep); err != nil || keep != "x" {
		t.Fatalf("unrelated structure field lost: %q %v", keep, err)
	}
	if _, err := repo.Replan(ctx, id, userID, time.Now()); !errors.Is(err, ErrNotBehind) {
		t.Fatalf("second call: want ErrNotBehind, got %v", err)
	}
}

func TestBackfillRoadmapIDs(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	userID := seedUser(t, ctx, pool)
	sqlBytes, err := os.ReadFile("../../db/migrations/002_backfill_roadmap_ids.sql")
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}

	keptID := uuid.NewString()
	structure := `{"phases":[{"title":"P","milestones":[{"id":"","title":"M","modules":[{"title":"x"},{"id":"` + keptID + `","title":"y"}]}]}]}`
	var id string
	if err := pool.QueryRow(ctx,
		`INSERT INTO roadmaps (user_id, title, status, goal_description, structure) VALUES ($1,'R','active','g',$2::jsonb) RETURNING id`,
		userID, structure).Scan(&id); err != nil {
		t.Fatalf("seed: %v", err)
	}

	check := func() (blank int, kept bool, snapshot string) {
		if err := pool.QueryRow(ctx,
			`SELECT (SELECT count(*) FROM jsonb_path_query(structure, 'strict $.**.id') v WHERE v #>> '{}' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
			        structure->'phases'->0->'milestones'->0->'modules'->1->>'id' = $2,
			        structure::text
			 FROM roadmaps WHERE id = $1`, id, keptID).Scan(&blank, &kept, &snapshot); err != nil {
			t.Fatalf("check: %v", err)
		}
		return
	}

	if _, err := pool.Exec(ctx, string(sqlBytes)); err != nil {
		t.Fatalf("run migration: %v", err)
	}
	blank, kept, first := check()
	if blank != 0 || !kept {
		t.Fatalf("non-uuid ids=%d kept=%v", blank, kept)
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM jsonb_path_query((SELECT structure FROM roadmaps WHERE id=$1), 'strict $.**.id')`, id).Scan(&count); err != nil || count != 4 {
		t.Fatalf("expected 4 ids (phase, milestone, 2 modules), got %d %v", count, err)
	}
	if _, err := pool.Exec(ctx, string(sqlBytes)); err != nil {
		t.Fatalf("rerun migration: %v", err)
	}
	if _, _, second := check(); second != first {
		t.Fatal("migration not idempotent")
	}
}

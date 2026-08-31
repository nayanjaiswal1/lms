package diary

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/whatnow"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedUser inserts the minimum users row diary_entries.user_id's FK requires.
func seedUser(t *testing.T, ctx context.Context, pool *pgxpool.Pool, email string) string {
	t.Helper()
	var userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, 'Diary User') RETURNING id`, email,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return userID
}

// TestGetOrCreateByDate_Idempotent exercises the ON CONFLICT upsert: calling
// it twice for the same user+date must return the same row, never a
// duplicate — the exact behavior UpdateContent's handler relies on to
// upsert-then-patch without a separate "does today's entry exist" check.
func TestGetOrCreateByDate_Idempotent(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	userID := seedUser(t, ctx, pool, "diary-user@example.com")

	first, err := repo.GetOrCreateByDate(ctx, userID, "2026-08-11")
	if err != nil {
		t.Fatalf("GetOrCreateByDate first: %v", err)
	}
	second, err := repo.GetOrCreateByDate(ctx, userID, "2026-08-11")
	if err != nil {
		t.Fatalf("GetOrCreateByDate second: %v", err)
	}
	if first.ID != second.ID {
		t.Errorf("expected the same entry id both calls, got %q then %q", first.ID, second.ID)
	}

	var count int
	if err := pool.QueryRow(ctx,
		`SELECT count(*) FROM diary_entries WHERE user_id = $1 AND entry_date = '2026-08-11'`, userID,
	).Scan(&count); err != nil {
		t.Fatalf("count rows: %v", err)
	}
	if count != 1 {
		t.Errorf("expected exactly 1 row for user+date, got %d", count)
	}
}

// TestServiceApplyHighlights_HabitAndDedup exercises Service.applyHighlights
// (the core of the diary_analyze job) against a real database: a "habit"
// span resolves against the caller's own habit and marks it complete for the
// entry's day, and re-running the same detected span a second time (as a
// later analysis pass on an edited entry would) must NOT create a second
// What Now? task for an identical "task_new" sentence — the naive
// text-equality dedup this package documents as a known ceiling.
func TestServiceApplyHighlights_HabitAndDedup(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	userID := seedUser(t, context.Background(), pool, "diary-analyze@example.com")

	habitSvc := habit.NewService(habit.NewRepo(pool))
	h, err := habitSvc.Create(ctx, userID, habit.CreateRequest{Name: "Drink water", Cadence: habit.CadenceDaily})
	if err != nil {
		t.Fatalf("create habit: %v", err)
	}

	tasksSvc := whatnow.NewService(whatnow.NewRepo(pool))
	svc := NewService(NewRepo(pool), &ai.NoopProvider{}, habitSvc, tasksSvc)

	entry := Entry{ID: "unused-in-this-path", UserID: userID, EntryDate: "2026-08-11"}
	detected := []Highlight{
		{Start: 0, End: 20, Text: "drank a glass of water", Kind: HighlightHabit, RefID: h.ID},
		{Start: 25, End: 45, Text: "pick up fresh coffee beans", Kind: HighlightTaskNew},
	}

	first, err := svc.applyHighlights(ctx, entry, detected, []habit.Habit{h}, nil)
	if err != nil {
		t.Fatalf("applyHighlights first pass: %v", err)
	}
	if len(first) != 2 {
		t.Fatalf("expected 2 resolved highlights, got %d: %+v", len(first), first)
	}

	view, err := habitSvc.MonthView(ctx, userID, "2026-08")
	if err != nil {
		t.Fatalf("MonthView: %v", err)
	}
	completed := false
	for _, c := range view.Completions {
		if c.HabitID == h.ID && c.PeriodStart == "2026-08-11" {
			completed = true
		}
	}
	if !completed {
		t.Errorf("expected habit %s completed for 2026-08-11, completions: %+v", h.ID, view.Completions)
	}

	tasksAfterFirst, err := tasksSvc.GetInbox(ctx, userID)
	if err != nil {
		t.Fatalf("GetInbox after first pass: %v", err)
	}
	if len(tasksAfterFirst) != 1 {
		t.Fatalf("expected exactly 1 captured task after first pass, got %d: %+v", len(tasksAfterFirst), tasksAfterFirst)
	}

	// Second pass: same detected spans, but entry.Highlights now carries the
	// first pass's resolved output — the dedup path a real re-analysis after
	// a content edit would take.
	entry.Highlights = first
	second, err := svc.applyHighlights(ctx, entry, detected, []habit.Habit{h}, nil)
	if err != nil {
		t.Fatalf("applyHighlights second pass: %v", err)
	}
	if len(second) != 2 {
		t.Fatalf("expected 2 resolved highlights on second pass too, got %d", len(second))
	}

	tasksAfterSecond, err := tasksSvc.GetInbox(ctx, userID)
	if err != nil {
		t.Fatalf("GetInbox after second pass: %v", err)
	}
	if len(tasksAfterSecond) != 1 {
		t.Errorf("expected dedup to skip re-capturing the identical task_new sentence, got %d tasks: %+v", len(tasksAfterSecond), tasksAfterSecond)
	}
}

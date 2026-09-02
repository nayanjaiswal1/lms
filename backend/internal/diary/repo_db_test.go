package diary

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/testdb"
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

// seedOrg inserts the minimum organizations row a self-course's org_id FK
// requires — only the "learned"/"goal" highlight paths (which route into
// courses) need this; the habit/task-only tests above don't.
func seedOrg(t *testing.T, ctx context.Context, pool *pgxpool.Pool, slug string) string {
	t.Helper()
	var orgID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ($1, 'Diary Test Org') RETURNING id`, slug,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	return orgID
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
// (the core of Service.Apply) against a real database: a "habit"
// span resolves against the caller's own habit and marks it complete for the
// entry's day, and re-running the same detected span a second time (as a
// later analysis pass on an edited entry would) must NOT create a second
// diary-owned task for an identical "task_new" sentence — the naive
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

	repo := NewRepo(pool)
	svc := NewService(repo, &ai.NoopProvider{}, habitSvc, courses.NewRepo(pool))

	entry, err := repo.GetOrCreateByDate(ctx, userID, "2026-08-11")
	if err != nil {
		t.Fatalf("get or create entry: %v", err)
	}
	detected := []Highlight{
		{Start: 0, End: 20, Text: "drank a glass of water", Kind: HighlightHabit, RefID: h.ID},
		{Start: 25, End: 45, Text: "pick up fresh coffee beans", Kind: HighlightTaskNew},
	}

	first, err := svc.applyHighlights(ctx, entry, "", detected, []habit.Habit{h}, nil)
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

	tasksAfterFirst, err := repo.ListOpenTasks(ctx, userID)
	if err != nil {
		t.Fatalf("ListOpenTasks after first pass: %v", err)
	}
	if len(tasksAfterFirst) != 1 {
		t.Fatalf("expected exactly 1 captured task after first pass, got %d: %+v", len(tasksAfterFirst), tasksAfterFirst)
	}

	// Second pass: same detected spans, but entry.Highlights now carries the
	// first pass's resolved output — the dedup path a real re-analysis after
	// a content edit would take.
	entry.Highlights = first
	second, err := svc.applyHighlights(ctx, entry, "", detected, []habit.Habit{h}, nil)
	if err != nil {
		t.Fatalf("applyHighlights second pass: %v", err)
	}
	if len(second) != 2 {
		t.Fatalf("expected 2 resolved highlights on second pass too, got %d", len(second))
	}

	tasksAfterSecond, err := repo.ListOpenTasks(ctx, userID)
	if err != nil {
		t.Fatalf("ListOpenTasks after second pass: %v", err)
	}
	if len(tasksAfterSecond) != 1 {
		t.Errorf("expected dedup to skip re-capturing the identical task_new sentence, got %d tasks: %+v", len(tasksAfterSecond), tasksAfterSecond)
	}
}

// TestServicePreview_AIUnavailable covers Preview's guard clause: with no AI
// provider configured (NoopProvider, the same "LLM_PROVIDER=disabled"
// fallback production uses), Preview must fail fast with ErrAIUnavailable
// rather than touching the DB or the frontend showing a stuck loading state.
func TestServicePreview_AIUnavailable(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	userID := seedUser(t, ctx, pool, "diary-preview@example.com")

	svc := NewService(NewRepo(pool), &ai.NoopProvider{}, habit.NewService(habit.NewRepo(pool)), courses.NewRepo(pool))
	_, err := svc.Preview(ctx, userID, "2026-08-11", "went to the gym")
	if !errors.Is(err, ErrAIUnavailable) {
		t.Fatalf("expected ErrAIUnavailable, got %v", err)
	}
}

// TestServiceApply_HabitWithMetadata exercises the public Apply entry point
// end to end (vocabulary load + applyHighlights + SaveAnalysis): a "habit"
// span for a Sleep-type habit carrying extracted metadata must both mark the
// day's completion AND write the metadata onto that same completion, with an
// unknown/hallucinated field key silently dropped rather than failing the
// whole apply.
func TestServiceApply_HabitWithMetadata(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	userID := seedUser(t, ctx, pool, "diary-apply@example.com")

	habitSvc := habit.NewService(habit.NewRepo(pool))
	sleep, err := habitSvc.Create(ctx, userID, habit.CreateRequest{Name: "Sleep", Cadence: habit.CadenceDaily, Type: habit.HabitTypeSleep})
	if err != nil {
		t.Fatalf("create sleep habit: %v", err)
	}

	svc := NewService(NewRepo(pool), &ai.NoopProvider{}, habitSvc, courses.NewRepo(pool))
	entry, err := svc.repo.GetOrCreateByDate(ctx, userID, "2026-08-11")
	if err != nil {
		t.Fatalf("get or create entry: %v", err)
	}
	entry.Content = "slept at 23:30, woke up at 07:00"

	resolved, err := svc.Apply(ctx, entry, "", []Highlight{
		{
			Start: 0, End: len(entry.Content), Text: entry.Content, Kind: HighlightHabit, RefID: sleep.ID,
			Metadata: map[string]any{"slept_at": "23:30", "woke_up": "07:00", "made_up_field": "should be dropped"},
		},
	})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if len(resolved) != 1 {
		t.Fatalf("expected 1 resolved highlight, got %d: %+v", len(resolved), resolved)
	}

	view, err := habitSvc.MonthView(ctx, userID, "2026-08")
	if err != nil {
		t.Fatalf("MonthView: %v", err)
	}
	var got habit.Completion
	found := false
	for _, c := range view.Completions {
		if c.HabitID == sleep.ID && c.PeriodStart == "2026-08-11" {
			got, found = c, true
		}
	}
	if !found {
		t.Fatalf("expected sleep habit completed for 2026-08-11, completions: %+v", view.Completions)
	}
	if got.Metadata["slept_at"] != "23:30" || got.Metadata["woke_up"] != "07:00" {
		t.Errorf("expected known metadata fields saved, got %+v", got.Metadata)
	}
	if _, ok := got.Metadata["made_up_field"]; ok {
		t.Errorf("expected unknown metadata field dropped, got %+v", got.Metadata)
	}

	stored, err := svc.repo.GetByDate(ctx, userID, "2026-08-11")
	if err != nil {
		t.Fatalf("GetByDate after apply: %v", err)
	}
	if stored.AnalyzedHash != ContentHash(entry.Content) {
		t.Errorf("expected analyzed_hash to match applied content, got %q", stored.AnalyzedHash)
	}
}

// TestServiceApplyHighlights_LearnedRoutesIntoLearningLog exercises the
// "learned" highlight path end to end: the first pass creates the writer's
// "Learning Log" self-course, a "Backend" section, and a module for the
// span's title; re-running an AI response with the same category/title
// against different text (FindSimilarModuleInCourse's fuzzy match, not the
// exact-text dedup the other highlight kinds use) appends to that module
// instead of creating a sibling duplicate.
func TestServiceApplyHighlights_LearnedRoutesIntoLearningLog(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	userID := seedUser(t, ctx, pool, "diary-learned@example.com")
	orgID := seedOrg(t, ctx, pool, "diary-learned-org")

	repo := NewRepo(pool)
	courseRepo := courses.NewRepo(pool)
	svc := NewService(repo, &ai.NoopProvider{}, habit.NewService(habit.NewRepo(pool)), courseRepo)

	entry, err := repo.GetOrCreateByDate(ctx, userID, "2026-08-11")
	if err != nil {
		t.Fatalf("get or create entry: %v", err)
	}

	first, err := svc.applyHighlights(ctx, entry, orgID, []Highlight{
		{Start: 0, End: 10, Text: "Redis pub/sub does not persist messages.", Kind: HighlightLearned, Category: "Backend", Title: "Redis pub/sub"},
	}, nil, nil)
	if err != nil {
		t.Fatalf("applyHighlights (learned, first pass): %v", err)
	}
	if len(first) != 1 || first[0].RefID == "" {
		t.Fatalf("expected 1 resolved highlight with a module ref_id, got %+v", first)
	}

	course, err := courseRepo.GetOrCreateLearningLogCourse(ctx, orgID, userID)
	if err != nil {
		t.Fatalf("GetOrCreateLearningLogCourse: %v", err)
	}
	module, err := courseRepo.GetModule(ctx, orgID, first[0].RefID)
	if err != nil {
		t.Fatalf("GetModule: %v", err)
	}
	if module.CourseID != course.ID {
		t.Errorf("expected module under the Learning Log course, got course_id=%s want %s", module.CourseID, course.ID)
	}

	// Second pass: a differently-worded span under the same category/title —
	// should append into the SAME module, not create a second one.
	second, err := svc.applyHighlights(ctx, entry, orgID, []Highlight{
		{Start: 0, End: 10, Text: "Also: Redis pub/sub messages are lost if no subscriber is listening.", Kind: HighlightLearned, Category: "Backend", Title: "Redis pub/sub"},
	}, nil, nil)
	if err != nil {
		t.Fatalf("applyHighlights (learned, second pass): %v", err)
	}
	if len(second) != 1 || second[0].RefID != first[0].RefID {
		t.Fatalf("expected the second pass to resolve to the SAME module id, got %+v want ref_id %s", second, first[0].RefID)
	}
	updated, err := courseRepo.GetModule(ctx, orgID, second[0].RefID)
	if err != nil {
		t.Fatalf("GetModule after second pass: %v", err)
	}
	if updated.ContentBody == nil || !strings.Contains(*updated.ContentBody, "no subscriber") {
		t.Errorf("expected the second pass's text appended to the module content, got %+v", updated.ContentBody)
	}
}

// TestServiceApplyHighlights_GoalCreatesHabit exercises the "goal" highlight
// path: a stated new recurring intention with no matching existing habit
// creates one with the detected cadence, and a second detection whose title
// closely matches an existing habit name is a no-op (the cheap
// substring-match safety net in matchExistingHabit) rather than a duplicate.
func TestServiceApplyHighlights_GoalCreatesHabit(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	userID := seedUser(t, ctx, pool, "diary-goal@example.com")

	habitSvc := habit.NewService(habit.NewRepo(pool))
	svc := NewService(NewRepo(pool), &ai.NoopProvider{}, habitSvc, courses.NewRepo(pool))

	resolved, err := svc.applyHighlights(ctx, Entry{UserID: userID, EntryDate: "2026-08-11"}, "", []Highlight{
		{Start: 0, End: 30, Text: "I want to start stretching every morning.", Kind: HighlightGoal, Title: "Stretching", Cadence: "daily"},
	}, nil, nil)
	if err != nil {
		t.Fatalf("applyHighlights (goal): %v", err)
	}
	if len(resolved) != 1 || resolved[0].RefID == "" {
		t.Fatalf("expected 1 resolved highlight with a habit ref_id, got %+v", resolved)
	}
	created, err := habitSvc.Get(ctx, userID, resolved[0].RefID)
	if err != nil {
		t.Fatalf("Get created habit: %v", err)
	}
	if created.Name != "Stretching" || created.Cadence != habit.CadenceDaily {
		t.Errorf("expected a daily 'Stretching' habit, got %+v", created)
	}

	// A second detection whose title closely matches the habit just created
	// must not create a duplicate.
	again, err := svc.applyHighlights(ctx, Entry{UserID: userID, EntryDate: "2026-08-12"}, "", []Highlight{
		{Start: 0, End: 20, Text: "Stretched again today.", Kind: HighlightGoal, Title: "stretching", Cadence: "daily"},
	}, []habit.Habit{created}, nil)
	if err != nil {
		t.Fatalf("applyHighlights (goal, near-duplicate title): %v", err)
	}
	if len(again) != 1 || again[0].RefID != created.ID {
		t.Fatalf("expected the near-duplicate goal to resolve to the EXISTING habit id %s, got %+v", created.ID, again)
	}
}

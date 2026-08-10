package whatnow

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedUser inserts the minimum users row whatnow_tasks.user_id's FK requires.
func seedUser(t *testing.T, ctx context.Context, pool *pgxpool.Pool) string {
	t.Helper()
	var userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('shelf-user@example.com', 'Shelf User') RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return userID
}

// TestInsertAndUpdateScheduledStart exercises InsertTask/UpdateTask/GetTask
// and ListScheduledForDay (repo.go) against a real database. service_test.go's
// TestApplyPatchScheduledStart only checks the in-memory merge that syncs
// scheduledStart -> ScheduledStart; it never reaches UpdateTask's actual
// column write or scanTask's read-back formatting, which is the code path
// that shipped the "new calendar events landed in the backlog" bug this test
// guards against regressing.
func TestInsertAndUpdateScheduledStart(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	userID := seedUser(t, ctx, pool)

	created, err := repo.InsertTask(ctx, userID, Task{
		Title:  "Plan the sprint",
		Status: StatusPlanned,
	})
	if err != nil {
		t.Fatalf("InsertTask: %v", err)
	}
	if created.scheduledStart != nil {
		t.Fatalf("expected new task to have no scheduled_start, got %v", created.scheduledStart)
	}

	start := time.Date(2026, 8, 11, 9, 0, 0, 0, time.UTC)
	created.scheduledStart = &start
	if err := repo.UpdateTask(ctx, created); err != nil {
		t.Fatalf("UpdateTask: %v", err)
	}

	reloaded, err := repo.GetTask(ctx, created.ID, userID)
	if err != nil {
		t.Fatalf("GetTask: %v", err)
	}
	// pgx scans timestamptz into the driver's local time.Location, so the
	// offset in the RFC3339 string legitimately varies by host — compare the
	// instant, not the literal text.
	gotStart, err := time.Parse(time.RFC3339, reloaded.ScheduledStart)
	if err != nil {
		t.Fatalf("parse reloaded ScheduledStart %q: %v", reloaded.ScheduledStart, err)
	}
	if !gotStart.Equal(start) {
		t.Errorf("expected ScheduledStart %v after UpdateTask, got %v", start, gotStart)
	}

	dayStart := time.Date(2026, 8, 11, 0, 0, 0, 0, time.UTC)
	dayEnd := dayStart.Add(24 * time.Hour)
	scheduled, err := repo.ListScheduledForDay(ctx, userID, dayStart, dayEnd)
	if err != nil {
		t.Fatalf("ListScheduledForDay: %v", err)
	}
	if len(scheduled) != 1 || scheduled[0].ID != created.ID {
		t.Fatalf("expected ListScheduledForDay to return the task, got %+v", scheduled)
	}

	byStatus, err := repo.ListByStatuses(ctx, userID, []TaskStatus{StatusPlanned})
	if err != nil {
		t.Fatalf("ListByStatuses: %v", err)
	}
	if len(byStatus) != 1 || byStatus[0].ID != created.ID {
		t.Fatalf("expected ListByStatuses to return the task, got %+v", byStatus)
	}
}

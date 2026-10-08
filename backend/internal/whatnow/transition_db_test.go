package whatnow

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// TestPatchStatusTransitions: completing a task through PATCH stamps
// completed_at and reports what it unblocked; patching a decayed task back to
// inbox revives it; an unknown status is rejected.
func TestPatchStatusTransitions(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	svc := NewService(repo)
	userID := seedUser(t, ctx, pool)

	first, err := repo.InsertTask(ctx, userID, Task{Title: "Outline", Status: StatusActive})
	if err != nil {
		t.Fatalf("insert first: %v", err)
	}
	next, err := repo.InsertTask(ctx, userID, Task{Title: "Draft", Status: StatusInbox})
	if err != nil {
		t.Fatalf("insert next: %v", err)
	}
	next.DependsOn = []string{first.ID} // InsertTask leaves depends_on to UpdateTask
	if err := repo.UpdateTask(ctx, next); err != nil {
		t.Fatalf("link dependency: %v", err)
	}

	done := StatusDone
	res, err := svc.PatchTask(ctx, userID, first.ID, TaskPatch{Status: &done})
	if err != nil {
		t.Fatalf("complete: %v", err)
	}
	if res.CompletedAt == "" || len(res.UnlockedTasks) != 1 || res.UnlockedTasks[0].ID != next.ID {
		t.Fatalf("complete result = %+v, want completed_at and %s unlocked", res, next.ID)
	}

	decayed := StatusDecayed
	if _, err := svc.PatchTask(ctx, userID, next.ID, TaskPatch{Status: &decayed}); err != nil {
		t.Fatalf("decay: %v", err)
	}
	inbox := StatusInbox
	if _, err := svc.PatchTask(ctx, userID, next.ID, TaskPatch{Status: &inbox}); err != nil {
		t.Fatalf("revive: %v", err)
	}
	revived, err := repo.GetTask(ctx, next.ID, userID)
	if err != nil || revived.revivedAt == nil || revived.Status != StatusInbox {
		t.Fatalf("revived task = %+v, %v", revived, err)
	}

	bogus := TaskStatus("finished")
	if _, err := svc.PatchTask(ctx, userID, next.ID, TaskPatch{Status: &bogus}); !errors.Is(err, ErrInvalidStatus) {
		t.Fatalf("bogus status: err = %v, want ErrInvalidStatus", err)
	}
}

package journal

import (
	"testing"

	"github.com/mindforge/backend/internal/whatnow"
)

// TestCompletedTaskEntries exercises the pure projection/filter logic behind
// ListEntries' day-timeline merge (see handler.go) without a database — the
// filter rules (no real subcategory on a task, category must be exactly
// "Task", search matches title) are easy to get backwards, and a bad
// CompletedAt should degrade to "skip that task" rather than crash the
// whole /api/journal response.
func TestCompletedTaskEntries(t *testing.T) {
	tasks := []whatnow.Task{
		{ID: "t1", Title: "Ship the release notes", Category: "Work", CompletedAt: "2026-08-11T09:00:00Z"},
		{ID: "t2", Title: "Read a chapter", Category: "", CompletedAt: "2026-08-10T21:30:00Z"},
		{ID: "t3", Title: "Still open", Category: "Work", CompletedAt: ""},
		{ID: "t4", Title: "Bad timestamp", Category: "Work", CompletedAt: "not-a-time"},
	}

	t.Run("no filter merges all completed, skipping unset/bad timestamps", func(t *testing.T) {
		out := completedTaskEntries(tasks, ListEntriesFilter{}, "user-1")
		if len(out) != 2 {
			t.Fatalf("expected 2 projected entries, got %d: %+v", len(out), out)
		}
		if out[0].Source != "task" || out[0].SourceTaskID != "t1" || out[0].EntryDate != "2026-08-11" {
			t.Errorf("unexpected first entry: %+v", out[0])
		}
		if out[0].UserID != "user-1" {
			t.Errorf("expected projected entry to carry the caller's userID, got %q", out[0].UserID)
		}
		// A task with no category falls back to "Completed" as its subcategory.
		if out[1].Subcategory != "Completed" {
			t.Errorf("expected fallback subcategory \"Completed\", got %q", out[1].Subcategory)
		}
	})

	t.Run("subcategory filter excludes all tasks", func(t *testing.T) {
		out := completedTaskEntries(tasks, ListEntriesFilter{Subcategory: "Redis"}, "user-1")
		if len(out) != 0 {
			t.Errorf("expected subcategory filter to exclude every task, got %+v", out)
		}
	})

	t.Run("category filter other than Task excludes all tasks", func(t *testing.T) {
		out := completedTaskEntries(tasks, ListEntriesFilter{Category: "Backend"}, "user-1")
		if len(out) != 0 {
			t.Errorf("expected non-Task category filter to exclude every task, got %+v", out)
		}
	})

	t.Run("category filter Task keeps tasks", func(t *testing.T) {
		out := completedTaskEntries(tasks, ListEntriesFilter{Category: "Task"}, "user-1")
		if len(out) != 2 {
			t.Errorf("expected Category=Task to keep both completed tasks, got %d", len(out))
		}
	})

	t.Run("search matches title case-insensitively", func(t *testing.T) {
		out := completedTaskEntries(tasks, ListEntriesFilter{Search: "release"}, "user-1")
		if len(out) != 1 || out[0].SourceTaskID != "t1" {
			t.Errorf("expected search to match only t1, got %+v", out)
		}
	})
}

package whatnow

import "testing"

// ponytail: no test infra exists in this package yet — this is the one
// runnable check for the new ScheduledStart branch, not a new test pattern.
func TestApplyPatchScheduledStart(t *testing.T) {
	var task Task

	iso := "2026-07-09T09:00:00Z"
	applyPatch(&task, TaskPatch{ScheduledStart: &iso})
	if task.scheduledStart == nil {
		t.Fatal("expected scheduledStart to be set")
	}
	if got := task.scheduledStart.Format("2006-01-02T15:04:05Z"); got != iso {
		t.Fatalf("expected scheduledStart %q, got %q", iso, got)
	}
	// The exported wire field must be synced too — it is otherwise only
	// populated by the repo scan, and a stale value here made PATCH responses
	// omit the schedule (new calendar events landed in the backlog).
	if task.ScheduledStart != iso {
		t.Fatalf("expected exported ScheduledStart %q, got %q", iso, task.ScheduledStart)
	}

	applyPatch(&task, TaskPatch{})
	if task.scheduledStart == nil {
		t.Fatal("expected nil patch field to leave scheduledStart unchanged")
	}

	empty := ""
	applyPatch(&task, TaskPatch{ScheduledStart: &empty})
	if task.scheduledStart != nil {
		t.Fatal("expected scheduledStart to be cleared")
	}
	if task.ScheduledStart != "" {
		t.Fatal("expected exported ScheduledStart to be cleared")
	}
}

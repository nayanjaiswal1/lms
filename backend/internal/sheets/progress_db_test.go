package sheets

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// TestPatchProgressAppliesAllFields: one PATCH sets status, notes and the star
// together; revision_at alone then reschedules the done item.
func TestPatchProgressAppliesAllFields(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()
	var userID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('progress@`+testdomain.Domain+`', 'P') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}

	done, starred := "done", true
	due := time.Now().Add(72 * time.Hour).Truncate(time.Second)
	notes := json.RawMessage(`{"type":"doc"}`)
	item, err := repo.PatchProgress(ctx, userID, "two-sum", ProgressPatch{Status: &done, RevisionAt: &due, Notes: &notes, Starred: &starred})
	if err != nil {
		t.Fatalf("patch: %v", err)
	}
	if item.Status != "done" || !item.IsStarred || string(item.Notes) == "" || item.RevisionAt == nil || !item.RevisionAt.Equal(due) {
		t.Fatalf("patched item = %+v", item)
	}

	later := due.Add(48 * time.Hour)
	item, err = repo.PatchProgress(ctx, userID, "two-sum", ProgressPatch{RevisionAt: &later})
	if err != nil || item.RevisionAt == nil || !item.RevisionAt.Equal(later) || !item.IsStarred {
		t.Fatalf("reschedule = %+v, %v", item, err)
	}
}

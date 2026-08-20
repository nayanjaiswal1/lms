package journal

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedUser inserts the minimum users row learning_journal_entries.user_id's
// FK requires.
func seedUser(t *testing.T, ctx context.Context, pool *pgxpool.Pool, email string) string {
	t.Helper()
	var userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ($1, 'Journal User') RETURNING id`, email,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return userID
}

// TestMergeEntries exercises Repo.MergeEntries against a real database: the
// kept entry's content gains the merged-away entry's content, the
// merged-away row is actually deleted, and the returned "removed" snapshot
// still carries its original (pre-merge) content — the exact data the
// frontend's Ctrl+Z undo relies on to recreate it.
func TestMergeEntries(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	userID := seedUser(t, ctx, pool, "merge-user@example.com")

	keep, err := repo.CreateEntry(ctx, userID, CreateEntryRequest{
		Category: "Backend", Subcategory: "Redis", Title: "Redis basics", Content: "Learned SET/GET.",
	})
	if err != nil {
		t.Fatalf("CreateEntry keep: %v", err)
	}
	other, err := repo.CreateEntry(ctx, userID, CreateEntryRequest{
		Category: "Backend", Subcategory: "Redis", Title: "Redis pub/sub", Content: "Learned PUBLISH/SUBSCRIBE.",
	})
	if err != nil {
		t.Fatalf("CreateEntry other: %v", err)
	}

	kept, removed, err := repo.MergeEntries(ctx, userID, keep.ID, other.ID)
	if err != nil {
		t.Fatalf("MergeEntries: %v", err)
	}
	if removed.Content != other.Content {
		t.Errorf("expected removed.Content %q to be other's original content, got %q", other.Content, removed.Content)
	}
	if kept.Content != keep.Content+"\n\n---\n\n"+other.Content {
		t.Errorf("expected kept.Content to combine both, got %q", kept.Content)
	}

	if _, err := repo.GetEntry(ctx, userID, other.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("expected merged-away entry to be deleted, GetEntry returned err=%v", err)
	}
	reloaded, err := repo.GetEntry(ctx, userID, keep.ID)
	if err != nil {
		t.Fatalf("GetEntry kept: %v", err)
	}
	if reloaded.Content != kept.Content {
		t.Errorf("expected kept entry's persisted content to match MergeEntries' return value, got %q want %q", reloaded.Content, kept.Content)
	}
}

// TestMergeEntriesCrossUserRejected ensures a caller can't merge in another
// user's entry by ID — both rows are looked up scoped to userID, so this
// should behave like the entry never existed.
func TestMergeEntriesCrossUserRejected(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	ownerID := seedUser(t, ctx, pool, "owner@example.com")
	attackerID := seedUser(t, ctx, pool, "attacker@example.com")

	victim, err := repo.CreateEntry(ctx, ownerID, CreateEntryRequest{
		Category: "Backend", Subcategory: "Redis", Title: "Victim entry", Content: "Not yours.",
	})
	if err != nil {
		t.Fatalf("CreateEntry victim: %v", err)
	}
	mine, err := repo.CreateEntry(ctx, attackerID, CreateEntryRequest{
		Category: "Backend", Subcategory: "Redis", Title: "My entry", Content: "Mine.",
	})
	if err != nil {
		t.Fatalf("CreateEntry mine: %v", err)
	}

	if _, _, err := repo.MergeEntries(ctx, attackerID, mine.ID, victim.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("expected ErrNotFound merging another user's entry, got %v", err)
	}

	// The victim's entry must survive untouched.
	if _, err := repo.GetEntry(ctx, ownerID, victim.ID); err != nil {
		t.Errorf("expected victim entry to still exist, GetEntry returned %v", err)
	}
}

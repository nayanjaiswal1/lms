package captures

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// captures has no org_id column (personal inbox, keyed by user_id), so the
// isolation boundary is the owning user: another user — in any org — gets
// ErrNotFound on read/dismiss and A's row stays untouched.
func TestCaptures_OtherUserCannotReadOrModify(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	var userA, userB string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('ca@`+testdomain.Domain+`', 'A') RETURNING id`).Scan(&userA); err != nil {
		t.Fatalf("seed user A: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('cb@`+testdomain.Domain+`', 'B') RETURNING id`).Scan(&userB); err != nil {
		t.Fatalf("seed user B: %v", err)
	}
	c, err := repo.CreateLinkCapture(ctx, userA, "https://example.com/a")
	if err != nil {
		t.Fatalf("create capture: %v", err)
	}

	if _, err := repo.GetCapture(ctx, userB, c.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("GetCapture as B: err=%v, want ErrNotFound", err)
	}
	if got, err := repo.ListCaptures(ctx, userB, ListFilter{Limit: 50}); err != nil || len(got) != 0 {
		t.Fatalf("ListCaptures as B = %d err=%v, want 0", len(got), err)
	}
	if err := repo.Dismiss(ctx, userB, c.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("Dismiss as B: err=%v, want ErrNotFound", err)
	}

	got, err := repo.GetCapture(ctx, userA, c.ID)
	if err != nil || got.Status != StatusPending {
		t.Fatalf("A's capture = %+v err=%v, want status %s untouched", got, err, StatusPending)
	}
}

// LinkPromoted writes a uuid into captures.journal_entry_id; this pins the
// cast so the statement cannot regress to a text-typed parameter.
func TestCaptures_LinkPromotedToJournalEntry(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	var userID, journalID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('cp@`+testdomain.Domain+`', 'P') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx,
		`INSERT INTO learning_journal_entries (user_id, category, subcategory, title, content) VALUES ($1, 'go', 'general', 't', 'c') RETURNING id`,
		userID,
	).Scan(&journalID); err != nil {
		t.Fatalf("seed journal entry: %v", err)
	}
	c, err := repo.CreateLinkCapture(ctx, userID, "https://example.com/p")
	if err != nil {
		t.Fatalf("create capture: %v", err)
	}

	if err := repo.LinkPromoted(ctx, userID, c.ID, journalID, ""); err != nil {
		t.Fatalf("LinkPromoted: %v", err)
	}
	got, err := repo.GetCapture(ctx, userID, c.ID)
	if err != nil {
		t.Fatalf("GetCapture: %v", err)
	}
	if got.Status != StatusPromoted {
		t.Fatalf("status = %s, want %s", got.Status, StatusPromoted)
	}
	if got.JournalEntryID == nil || *got.JournalEntryID != journalID {
		t.Fatalf("journal_entry_id = %v, want %s", got.JournalEntryID, journalID)
	}
	if got.SRSCardID != nil {
		t.Fatalf("srs_card_id = %v, want nil", got.SRSCardID)
	}
}

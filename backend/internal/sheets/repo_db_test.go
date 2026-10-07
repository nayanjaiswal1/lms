package sheets

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// TestSheetVisibility pins TEN-17: a non-system sheet is subscribable and
// previewable only by users sharing an active org with its creator.
func TestSheetVisibility(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	user := func(email string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, 'U') RETURNING id`, email).Scan(&id); err != nil {
			t.Fatalf("seed user: %v", err)
		}
		return id
	}
	org := func(slug string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ($1, $1) RETURNING id`, slug).Scan(&id); err != nil {
			t.Fatalf("seed org: %v", err)
		}
		return id
	}
	join := func(orgID, userID string) {
		if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id) VALUES ($1, $2)`, orgID, userID); err != nil {
			t.Fatalf("seed member: %v", err)
		}
	}

	owner, mate, outsider := user("own@x.io"), user("mate@x.io"), user("out@x.io")
	orgA, orgB := org("sheet-org-a"), org("sheet-org-b")
	join(orgA, owner)
	join(orgA, mate)
	join(orgB, outsider)

	sheet, err := repo.CreateSheet(ctx, owner, "private-sheet", CreateSheetRequest{Name: "Private"})
	if err != nil {
		t.Fatalf("create sheet: %v", err)
	}

	if err := repo.Subscribe(ctx, outsider, sheet.ID); !errors.Is(err, ErrNotFound) {
		t.Errorf("cross-org subscribe: want ErrNotFound, got %v", err)
	}
	if _, err := repo.GetSheetPreview(ctx, outsider, sheet.Slug); !errors.Is(err, ErrNotFound) {
		t.Errorf("cross-org preview: want ErrNotFound, got %v", err)
	}
	if err := repo.Subscribe(ctx, mate, sheet.ID); err != nil {
		t.Errorf("same-org subscribe: %v", err)
	}
	if _, err := repo.GetSheetPreview(ctx, mate, sheet.Slug); err != nil {
		t.Errorf("same-org preview: %v", err)
	}
	if err := repo.Subscribe(ctx, owner, sheet.ID); err != nil {
		t.Errorf("owner re-subscribe must be idempotent: %v", err)
	}

	var sysID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO sheets (name, slug, is_system) VALUES ('Sys', 'sys-sheet', true) RETURNING id`).Scan(&sysID); err != nil {
		t.Fatalf("seed system sheet: %v", err)
	}
	if err := repo.Subscribe(ctx, outsider, sysID); err != nil {
		t.Errorf("system sheet subscribe by anyone: %v", err)
	}
}

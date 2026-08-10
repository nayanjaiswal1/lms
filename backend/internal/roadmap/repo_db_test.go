package roadmap

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedUser inserts the minimum users row roadmaps.user_id's FK requires.
func seedUser(t *testing.T, ctx context.Context, pool *pgxpool.Pool) string {
	t.Helper()
	var userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('roadmapper@example.com', 'Roadmapper') RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return userID
}

// TestCreateShellAndGetForUser exercises CreateShell/GetForUser (repo.go)
// against a real database — the INSERT/RETURNING round trip, the
// focus_areas jsonb marshal/unmarshal, and the status defaulting to
// 'generating' aren't reachable from service_test.go's pure-Go title/matcher
// checks.
func TestCreateShellAndGetForUser(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	userID := seedUser(t, ctx, pool)

	shell, err := repo.CreateShell(ctx, Roadmap{
		UserID:          userID,
		Title:           "Backend Engineer Roadmap",
		GoalDescription: "get good at distributed systems",
		FocusAreas:      []string{"go", "databases"},
	})
	if err != nil {
		t.Fatalf("CreateShell: %v", err)
	}
	if shell.ID == "" {
		t.Fatal("expected CreateShell to populate ID")
	}
	if shell.Mode != ModeGenerated || shell.Status != StatusGenerating {
		t.Fatalf("expected mode=%q status=%q, got mode=%q status=%q", ModeGenerated, StatusGenerating, shell.Mode, shell.Status)
	}

	got, err := repo.GetForUser(ctx, shell.ID, userID)
	if err != nil {
		t.Fatalf("GetForUser: %v", err)
	}
	if got.Title != "Backend Engineer Roadmap" {
		t.Errorf("expected title %q, got %q", "Backend Engineer Roadmap", got.Title)
	}
	if len(got.FocusAreas) != 2 || got.FocusAreas[0] != "go" || got.FocusAreas[1] != "databases" {
		t.Errorf("expected focus_areas round trip [go databases], got %v", got.FocusAreas)
	}
	if len(got.Phases) != 0 {
		t.Errorf("expected no phases before generation completes, got %d", len(got.Phases))
	}

	// A shell is created already in status=generating, so SetGenerating on it
	// again must report ErrAlreadyGenerating rather than silently succeeding.
	if err := repo.SetGenerating(ctx, shell.ID, userID); !errors.Is(err, ErrAlreadyGenerating) {
		t.Fatalf("expected ErrAlreadyGenerating, got %v", err)
	}

	if _, err := repo.GetForUser(ctx, shell.ID, "00000000-0000-0000-0000-000000000000"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected ErrNotFound for wrong owner, got %v", err)
	}
}

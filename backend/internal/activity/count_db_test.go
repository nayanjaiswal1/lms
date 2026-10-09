package activity

import (
	"context"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// CountByKind groups the same events ListWindow returns, honors the window,
// and omits kinds with no events.
func TestCountByKind_WindowAndGrouping(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	var userID, orgID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('count@`+testdomain.Domain+`', 'Count') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('count-org', 'Count Org') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	var cardID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO srs_cards (user_id, front, back, source_type, due_date) VALUES ($1, 'f', 'b', 'manual', CURRENT_DATE) RETURNING id`,
		userID).Scan(&cardID); err != nil {
		t.Fatalf("seed card: %v", err)
	}
	now := time.Now().UTC()
	for _, at := range []time.Time{now.Add(-time.Hour), now.Add(-2 * time.Hour), now.Add(-30 * 24 * time.Hour)} {
		if _, err := pool.Exec(ctx,
			`INSERT INTO srs_reviews (card_id, user_id, quality, interval_days, ease_factor, reviewed_at) VALUES ($1, $2, 0, 1, 2.5, $3)`,
			cardID, userID, at); err != nil {
			t.Fatalf("seed review: %v", err)
		}
	}

	from, to := now.Add(-7*24*time.Hour), now
	counts, err := repo.CountByKind(ctx, userID, orgID, from, to)
	if err != nil {
		t.Fatalf("CountByKind: %v", err)
	}
	if len(counts) != 1 || counts[KindCardReviewed] != 2 {
		t.Fatalf("counts = %v, want only %s:2", counts, KindCardReviewed)
	}
	entries, err := repo.ListWindow(ctx, userID, orgID, from, to, 100)
	if err != nil {
		t.Fatalf("ListWindow: %v", err)
	}
	if len(entries) != counts[KindCardReviewed] {
		t.Fatalf("ListWindow has %d entries, CountByKind %d", len(entries), counts[KindCardReviewed])
	}
}

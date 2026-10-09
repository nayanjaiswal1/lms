package srs

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// The drill queue ranks a card with repeated failed reviews above an equally
// overdue clean card, excludes cards not yet due, and caps at drillLimit.
func TestGetDrillCards_RanksLapsesAndCaps(t *testing.T) {
	pool := testdb.New(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	var userID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('drill@`+testdomain.Domain+`', 'Drill') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}

	seed := func(front, due string) string {
		var id string
		if err := pool.QueryRow(ctx,
			`INSERT INTO srs_cards (user_id, front, back, source_type, due_date)
			 VALUES ($1, $2, 'b', 'manual', $3::date) RETURNING id`, userID, front, due).Scan(&id); err != nil {
			t.Fatalf("seed card %s: %v", front, err)
		}
		return id
	}
	clean := seed("clean", "2000-01-01")
	weak := seed("weak", "2000-01-01")
	future := seed("future", "2999-01-01")
	for i := 0; i < 2; i++ {
		if _, err := pool.Exec(ctx,
			`INSERT INTO srs_reviews (card_id, user_id, quality, interval_days, ease_factor) VALUES ($1, $2, 0, 1, 2.5)`,
			weak, userID); err != nil {
			t.Fatalf("seed review: %v", err)
		}
	}

	cards, err := repo.GetDrillCards(ctx, userID)
	if err != nil {
		t.Fatalf("GetDrillCards: %v", err)
	}
	if len(cards) != 2 || cards[0].ID != weak || cards[1].ID != clean {
		t.Fatalf("got %+v, want [weak, clean] and no future card %s", cards, future)
	}

	for i := 0; i < drillLimit+3; i++ {
		seed("extra", "2000-01-01")
	}
	cards, err = repo.GetDrillCards(ctx, userID)
	if err != nil {
		t.Fatalf("GetDrillCards (cap): %v", err)
	}
	if len(cards) != drillLimit {
		t.Fatalf("len = %d, want cap %d", len(cards), drillLimit)
	}
}

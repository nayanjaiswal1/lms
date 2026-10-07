package privacy

import (
	"context"
	"errors"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
	"testing"
)

func TestAIConsentGateAndNomineeExport(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool, &fakeStore{})

	var userID string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('consent@`+testdomain.Domain+`', 'C') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := RequireAIConsent(ctx, pool, userID); !errors.Is(err, ErrAIConsentRequired) {
		t.Fatalf("no consent: want ErrAIConsentRequired, got %v", err)
	}
	if err := repo.SetAIConsent(ctx, userID, true); err != nil {
		t.Fatal(err)
	}
	if err := RequireAIConsent(ctx, pool, userID); err != nil {
		t.Fatalf("after consent: %v", err)
	}
	if err := repo.SetNominee(ctx, userID, &Nominee{Name: "Asha", Relationship: "Sister", Contact: "a@b.co"}); err != nil {
		t.Fatal(err)
	}
	s, err := repo.GetSettings(ctx, userID)
	if err != nil || !s.AIConsent || s.Nominee == nil || s.Nominee.Name != "Asha" {
		t.Fatalf("settings: %+v, %v", s, err)
	}
	exported, err := repo.ExportData(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := exported["user_privacy_settings"]; !ok {
		t.Fatal("export must include the nominee settings")
	}
	if err := repo.SetAIConsent(ctx, userID, false); err != nil {
		t.Fatal(err)
	}
	if err := RequireAIConsent(ctx, pool, userID); !errors.Is(err, ErrAIConsentRequired) {
		t.Fatalf("after withdraw: want ErrAIConsentRequired, got %v", err)
	}
	if s, _ := repo.GetSettings(ctx, userID); s.Nominee == nil {
		t.Fatal("withdrawing consent must not clear the nominee")
	}
}

package sessions

import (
	"context"
	"github.com/mindforge/backend/internal/testdomain"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// seedPackPurchase creates org+user and a completed pack purchase worth
// `sessions` credits (credited to the ledger), returning ids.
func seedPackPurchase(t *testing.T, repo *Repo, sessions int) (orgID, userID, purchaseID string) {
	t.Helper()
	ctx := context.Background()
	pool := repo.pool
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('rev-org', 'Rev Org') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('rev@`+testdomain.Domain+`', 'Rev') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	var packID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO session_credit_packs (org_id, name, sessions, price_cents, currency) VALUES ($1, 'P', $2, 1000, 'USD') RETURNING id`,
		orgID, sessions).Scan(&packID); err != nil {
		t.Fatalf("seed pack: %v", err)
	}
	p, err := repo.CreatePackPurchase(ctx, PackPurchase{OrgID: orgID, UserID: userID, PackID: packID, Sessions: sessions,
		AmountCents: 1000, Currency: "USD", Provider: "stub", ProviderRef: "ref_rev"})
	if err != nil {
		t.Fatalf("create purchase: %v", err)
	}
	if ok, err := repo.CompletePurchase(ctx, p.ID, "pay_rev"); err != nil || !ok {
		t.Fatalf("complete purchase: ok=%v err=%v", ok, err)
	}
	return orgID, userID, p.ID
}

func TestReversePurchase_ClawsBackAndIsIdempotent(t *testing.T) {
	repo := NewRepo(testdb.New(t))
	ctx := context.Background()
	orgID, userID, purchaseID := seedPackPurchase(t, repo, 5)

	out, err := repo.ReversePurchase(ctx, purchaseID)
	if err != nil || !out.Reversed || out.ClawedBack != 5 || out.Shortfall != 0 {
		t.Fatalf("reverse = %+v err=%v, want full clawback", out, err)
	}
	if bal, _ := repo.CreditBalance(ctx, orgID, userID); bal != 0 {
		t.Fatalf("balance = %d, want 0", bal)
	}
	again, err := repo.ReversePurchase(ctx, purchaseID)
	if err != nil || again.Reversed {
		t.Fatalf("second reverse = %+v err=%v, want no-op", again, err)
	}
	if bal, _ := repo.CreditBalance(ctx, orgID, userID); bal != 0 {
		t.Fatalf("balance after replay = %d, want 0 (no double clawback)", bal)
	}
}

func TestReversePurchase_SpentCreditsBecomeShortfallNeverNegative(t *testing.T) {
	repo := NewRepo(testdb.New(t))
	ctx := context.Background()
	orgID, userID, purchaseID := seedPackPurchase(t, repo, 5)
	// Student spent 3 of the 5 credits.
	if _, err := repo.GrantCredits(ctx, orgID, userID, -3, "simulate booking", userID); err != nil {
		t.Fatalf("spend: %v", err)
	}

	out, err := repo.ReversePurchase(ctx, purchaseID)
	if err != nil || out.ClawedBack != 2 || out.Shortfall != 3 {
		t.Fatalf("reverse = %+v err=%v, want clawed 2 shortfall 3", out, err)
	}
	if bal, _ := repo.CreditBalance(ctx, orgID, userID); bal != 0 {
		t.Fatalf("balance = %d, want 0 (never negative)", bal)
	}
	var shortfall int
	if err := repo.pool.QueryRow(ctx, `SELECT (granted->>'reversal_shortfall')::int FROM purchases WHERE id = $1`, purchaseID).Scan(&shortfall); err != nil || shortfall != 3 {
		t.Fatalf("recorded shortfall = %d err=%v, want 3", shortfall, err)
	}
	var status string
	if err := repo.pool.QueryRow(ctx, `SELECT status FROM purchases WHERE id = $1`, purchaseID).Scan(&status); err != nil || status != PurchaseStatusRefunded {
		t.Fatalf("status = %q err=%v, want refunded", status, err)
	}
}

func TestRefundingIntentIsResolvedByReversal(t *testing.T) {
	repo := NewRepo(testdb.New(t))
	ctx := context.Background()
	_, _, purchaseID := seedPackPurchase(t, repo, 2)
	if ok, err := repo.MarkPurchaseRefunding(ctx, purchaseID); err != nil || !ok {
		t.Fatalf("mark refunding: ok=%v err=%v", ok, err)
	}
	out, err := repo.ReversePurchase(ctx, purchaseID)
	if err != nil || !out.Reversed {
		t.Fatalf("reverse from refunding = %+v err=%v", out, err)
	}
}

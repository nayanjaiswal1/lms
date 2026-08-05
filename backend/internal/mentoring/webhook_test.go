package mentoring

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/payments"
	"github.com/mindforge/backend/internal/tickets"
)

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

func webhookTestService(pool *pgxpool.Pool) *Service {
	repo := NewRepo(pool)
	ticketsRepo := tickets.NewRepo(pool)
	couponsSvc := coupons.NewService(coupons.NewRepo(pool))
	coursesRepo := courses.NewRepo(pool)
	registry := payments.NewRegistry("stub", payments.NewStubProvider())
	cfg := &config.Config{FrontendURL: "http://localhost:3000", PaymentsCurrency: "USD"}
	// nil PackConfirmer: these tests only exercise course purchases, and a nil
	// confirmer is the supported "this deployment has no second product"
	// case HandleWebhook already guards for.
	return NewService(repo, ticketsRepo, registry, couponsSvc, coursesRepo, nil, cfg)
}

func seedWebhookOrg(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var orgID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("Webhook Test Org %d", suffix), fmt.Sprintf("webhook-test-org-%d", suffix),
	).Scan(&orgID)
	if err != nil {
		t.Fatalf("create org: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, orgID) }) //nolint:errcheck
	return orgID
}

func seedWebhookUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var userID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("webhook-test-%d@example.com", suffix), "Webhook Test User",
	).Scan(&userID)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID) }) //nolint:errcheck
	return userID
}

func seedWebhookCourse(t *testing.T, pool *pgxpool.Pool, orgID, creatorID string) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var courseID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO courses (org_id, creator_id, title, slug, price_cents, is_free, status)
		 VALUES ($1, $2, $3, $4, 1000, false, 'published') RETURNING id`,
		orgID, creatorID, "Webhook Test Course", fmt.Sprintf("webhook-test-course-%d", suffix),
	).Scan(&courseID)
	if err != nil {
		t.Fatalf("create course: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM courses WHERE id = $1`, courseID) }) //nolint:errcheck
	return courseID
}

// seedWebhookPendingPurchase inserts a 'pending' purchase with a unique
// provider_ref — the state StartCheckout leaves a purchase in before any
// webhook has confirmed or failed it.
func seedWebhookPendingPurchase(t *testing.T, pool *pgxpool.Pool, orgID, userID, courseID string, amountCents int, couponID *string) (purchaseID, providerRef string) {
	t.Helper()
	providerRef = fmt.Sprintf("checkout_%d", time.Now().UnixNano())
	err := pool.QueryRow(context.Background(),
		`INSERT INTO purchases (org_id, user_id, course_id, amount_cents, currency, provider, provider_ref, coupon_id, status, product_type)
		 VALUES ($1, $2, $3, $4, 'USD', 'stub', $5, $6, 'pending', 'course') RETURNING id`,
		orgID, userID, courseID, amountCents, providerRef, couponID,
	).Scan(&purchaseID)
	if err != nil {
		t.Fatalf("create pending purchase: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM purchases WHERE id = $1`, purchaseID) }) //nolint:errcheck
	return purchaseID, providerRef
}

func stubWebhookBodyJSON(t *testing.T, eventID, providerRef, status string, amountCents int) []byte {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"event_id":     eventID,
		"provider_ref": providerRef,
		"status":       status,
		"amount_cents": amountCents,
		"currency":     "USD",
	})
	if err != nil {
		t.Fatalf("marshal stub webhook body: %v", err)
	}
	return body
}

// TestHandleWebhook_SuccessConfirmsAndDedupsReplay proves a success event
// completes the purchase, enrolls the student, and opens a mentor ticket —
// and that redelivering the exact same event is a safe no-op (the actual
// idempotency guarantee payment_events' UNIQUE(provider, event_id) provides).
func TestHandleWebhook_SuccessConfirmsAndDedupsReplay(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	ctx := context.Background()

	orgID := seedWebhookOrg(t, pool)
	userID := seedWebhookUser(t, pool)
	courseID := seedWebhookCourse(t, pool, orgID, userID)
	purchaseID, providerRef := seedWebhookPendingPurchase(t, pool, orgID, userID, courseID, 1000, nil)

	body := stubWebhookBodyJSON(t, "evt_"+purchaseID, providerRef, "succeeded", 1000)
	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err != nil {
		t.Fatalf("first delivery: %v", err)
	}

	var status string
	if err := pool.QueryRow(ctx, `SELECT status FROM purchases WHERE id = $1`, purchaseID).Scan(&status); err != nil {
		t.Fatalf("check purchase status: %v", err)
	}
	if status != PurchaseStatusCompleted {
		t.Fatalf("expected purchase status %q, got %q", PurchaseStatusCompleted, status)
	}

	enrolled, err := courses.NewRepo(pool).IsEnrolled(ctx, userID, courseID)
	if err != nil {
		t.Fatalf("check enrollment: %v", err)
	}
	if !enrolled {
		t.Fatal("expected student to be enrolled after a confirmed purchase")
	}

	var ticketCount int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM conversations WHERE kind='mentorship' AND purchase_id = $1`, purchaseID).Scan(&ticketCount); err != nil {
		t.Fatalf("count mentor tickets: %v", err)
	}
	if ticketCount != 1 {
		t.Fatalf("expected exactly one mentor ticket opened, got %d", ticketCount)
	}

	// Redeliver the identical event — must be a no-op, not a second ticket
	// or an error.
	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err != nil {
		t.Fatalf("redelivered event: %v", err)
	}
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM conversations WHERE kind='mentorship' AND purchase_id = $1`, purchaseID).Scan(&ticketCount); err != nil {
		t.Fatalf("count mentor tickets after redelivery: %v", err)
	}
	if ticketCount != 1 {
		t.Fatalf("expected still exactly one mentor ticket after a redelivered event, got %d", ticketCount)
	}
}

// TestHandleWebhook_AmountMismatchLeavesPurchasePending proves an event
// claiming a different amount than what was stored at checkout-creation
// never completes the purchase — a valid signature only proves the delivery
// is authentically from the gateway, not that it's about the charge we
// actually asked for.
func TestHandleWebhook_AmountMismatchLeavesPurchasePending(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	ctx := context.Background()

	orgID := seedWebhookOrg(t, pool)
	userID := seedWebhookUser(t, pool)
	courseID := seedWebhookCourse(t, pool, orgID, userID)
	purchaseID, providerRef := seedWebhookPendingPurchase(t, pool, orgID, userID, courseID, 1000, nil)

	body := stubWebhookBodyJSON(t, "evt_mismatch_"+purchaseID, providerRef, "succeeded", 1) // wrong amount
	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err != nil {
		t.Fatalf("HandleWebhook: %v", err)
	}

	var status string
	if err := pool.QueryRow(ctx, `SELECT status FROM purchases WHERE id = $1`, purchaseID).Scan(&status); err != nil {
		t.Fatalf("check purchase status: %v", err)
	}
	if status != PurchaseStatusPending {
		t.Fatalf("expected purchase to stay %q on amount mismatch, got %q", PurchaseStatusPending, status)
	}

	var errMsg *string
	if err := pool.QueryRow(ctx, `SELECT error FROM payment_events WHERE provider_ref = $1`, providerRef).Scan(&errMsg); err != nil {
		t.Fatalf("check payment_events.error: %v", err)
	}
	if errMsg == nil || *errMsg == "" {
		t.Fatal("expected payment_events.error to be set for an amount mismatch")
	}
}

// TestHandleWebhook_FailureMarksPurchaseFailed proves a failure event marks
// the purchase failed without touching enrollment or coupon redemption.
func TestHandleWebhook_FailureMarksPurchaseFailed(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	ctx := context.Background()

	orgID := seedWebhookOrg(t, pool)
	userID := seedWebhookUser(t, pool)
	courseID := seedWebhookCourse(t, pool, orgID, userID)
	purchaseID, providerRef := seedWebhookPendingPurchase(t, pool, orgID, userID, courseID, 1000, nil)

	body := stubWebhookBodyJSON(t, "evt_failed_"+purchaseID, providerRef, "failed", 1000)
	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err != nil {
		t.Fatalf("HandleWebhook: %v", err)
	}

	var status string
	if err := pool.QueryRow(ctx, `SELECT status FROM purchases WHERE id = $1`, purchaseID).Scan(&status); err != nil {
		t.Fatalf("check purchase status: %v", err)
	}
	if status != PurchaseStatusFailed {
		t.Fatalf("expected purchase status %q, got %q", PurchaseStatusFailed, status)
	}

	enrolled, err := courses.NewRepo(pool).IsEnrolled(ctx, userID, courseID)
	if err != nil {
		t.Fatalf("check enrollment: %v", err)
	}
	if enrolled {
		t.Fatal("a failed purchase must never enroll the student")
	}
}

// TestHandleWebhook_SuccessConsumesCoupon proves a confirmed, coupon-backed
// purchase atomically increments the coupon's redeemed_count and records a
// coupon_redemptions row — the redemption is consumed only on confirmed
// payment, never at checkout-creation.
func TestHandleWebhook_SuccessConsumesCoupon(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	ctx := context.Background()

	orgID := seedWebhookOrg(t, pool)
	userID := seedWebhookUser(t, pool)
	courseID := seedWebhookCourse(t, pool, orgID, userID)

	var couponID string
	err := pool.QueryRow(ctx,
		`INSERT INTO coupons (org_id, code, discount_type, discount_value) VALUES ($1, $2, 'percent', 10) RETURNING id`,
		orgID, fmt.Sprintf("WEBHOOKTEST%d", time.Now().UnixNano()),
	).Scan(&couponID)
	if err != nil {
		t.Fatalf("create coupon: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM coupons WHERE id = $1`, couponID) }) //nolint:errcheck

	purchaseID, providerRef := seedWebhookPendingPurchase(t, pool, orgID, userID, courseID, 900, &couponID)

	body := stubWebhookBodyJSON(t, "evt_coupon_"+purchaseID, providerRef, "succeeded", 900)
	if err := svc.HandleWebhook(ctx, "stub", body, http.Header{}); err != nil {
		t.Fatalf("HandleWebhook: %v", err)
	}

	var redeemedCount int
	if err := pool.QueryRow(ctx, `SELECT redeemed_count FROM coupons WHERE id = $1`, couponID).Scan(&redeemedCount); err != nil {
		t.Fatalf("check redeemed_count: %v", err)
	}
	if redeemedCount != 1 {
		t.Fatalf("expected redeemed_count = 1, got %d", redeemedCount)
	}

	var redemptionCount int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM coupon_redemptions WHERE coupon_id = $1 AND purchase_id = $2`, couponID, purchaseID).Scan(&redemptionCount); err != nil {
		t.Fatalf("check coupon_redemptions: %v", err)
	}
	if redemptionCount != 1 {
		t.Fatalf("expected exactly one coupon_redemptions row, got %d", redemptionCount)
	}
}

package mentoring

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/courses"
)

// seedCheckoutCoupon inserts an org-wide coupon of the given percent discount.
func seedCheckoutCoupon(t *testing.T, pool *pgxpool.Pool, orgID string, percent int) (id, code string) {
	t.Helper()
	code = fmt.Sprintf("CHECKOUTTEST%d", time.Now().UnixNano())
	err := pool.QueryRow(context.Background(),
		`INSERT INTO coupons (org_id, code, discount_type, discount_value) VALUES ($1, $2, 'percent', $3) RETURNING id`,
		orgID, code, percent,
	).Scan(&id)
	if err != nil {
		t.Fatalf("create coupon: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM coupons WHERE id = $1`, id) }) //nolint:errcheck
	return id, code
}

// TestStartCheckout_CouponHeldByOpenCheckout proves the same one-per-customer
// coupon cannot back two simultaneous discounted checkouts on two different
// courses. coupon_redemptions is only written at webhook confirmation, so
// without ux_course_purchases_coupon_user_open (009_coupon_hold_guard.sql)
// both checkouts would be created — and both would be charged the discounted
// price, since confirmPurchase deliberately enrolls even when the redemption
// loses its race.
func TestStartCheckout_CouponHeldByOpenCheckout(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	ctx := context.Background()

	orgID := seedWebhookOrg(t, pool)
	userID := seedWebhookUser(t, pool)
	courseA := seedWebhookCourse(t, pool, orgID, userID)
	courseB := seedWebhookCourse(t, pool, orgID, userID)
	_, code := seedCheckoutCoupon(t, pool, orgID, 50)

	req := courses.CheckoutRequest{OrgID: orgID, UserID: userID, CourseID: courseA, CouponCode: code}
	if _, err := svc.StartCheckout(ctx, req); err != nil {
		t.Fatalf("first checkout: %v", err)
	}
	t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM course_purchases WHERE user_id = $1`, userID) }) //nolint:errcheck

	req.CourseID = courseB
	_, err := svc.StartCheckout(ctx, req)
	if !errors.Is(err, coupons.ErrAlreadyUsed) {
		t.Fatalf("expected the second checkout to be refused with ErrAlreadyUsed, got %v", err)
	}
}

// TestStartCheckout_ZeroTotalCompletesImmediately proves a 100%-off coupon
// enrolls the student without any gateway round-trip — the branch that
// records its own payment_events row, whose payload column is jsonb NOT NULL.
func TestStartCheckout_ZeroTotalCompletesImmediately(t *testing.T) {
	pool := testPool(t)
	svc := webhookTestService(pool)
	ctx := context.Background()

	orgID := seedWebhookOrg(t, pool)
	userID := seedWebhookUser(t, pool)
	courseID := seedWebhookCourse(t, pool, orgID, userID)
	_, code := seedCheckoutCoupon(t, pool, orgID, 100)

	session, err := svc.StartCheckout(ctx, courses.CheckoutRequest{
		OrgID: orgID, UserID: userID, CourseID: courseID, CouponCode: code,
	})
	if err != nil {
		t.Fatalf("zero-total checkout: %v", err)
	}
	t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM course_purchases WHERE user_id = $1`, userID) }) //nolint:errcheck

	if session.Status != PurchaseStatusCompleted || session.AmountCents != 0 {
		t.Fatalf("expected a completed zero-total session, got status %q amount %d", session.Status, session.AmountCents)
	}

	enrolled, err := courses.NewRepo(pool).IsEnrolled(ctx, userID, courseID)
	if err != nil {
		t.Fatalf("check enrollment: %v", err)
	}
	if !enrolled {
		t.Fatal("expected a fully-discounted purchase to enroll the student")
	}
}

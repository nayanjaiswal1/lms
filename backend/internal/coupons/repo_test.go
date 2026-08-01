package coupons

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
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

func seedTestOrg(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var orgID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("Coupons Test Org %d", suffix), fmt.Sprintf("coupons-test-org-%d", suffix),
	).Scan(&orgID)
	if err != nil {
		t.Fatalf("create org: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM organizations WHERE id = $1`, orgID) }) //nolint:errcheck
	return orgID
}

func seedTestUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var userID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("coupons-test-%d@example.com", suffix), "Coupons Test User",
	).Scan(&userID)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID) }) //nolint:errcheck
	return userID
}

func seedTestCourse(t *testing.T, pool *pgxpool.Pool, orgID, creatorID string) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var courseID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO courses (org_id, creator_id, title, slug, price_cents, is_free, status)
		 VALUES ($1, $2, $3, $4, 1000, false, 'published') RETURNING id`,
		orgID, creatorID, "Coupons Test Course", fmt.Sprintf("coupons-test-course-%d", suffix),
	).Scan(&courseID)
	if err != nil {
		t.Fatalf("create course: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM courses WHERE id = $1`, courseID) }) //nolint:errcheck
	return courseID
}

func seedTestPurchase(t *testing.T, pool *pgxpool.Pool, orgID, userID, courseID string) string {
	t.Helper()
	var purchaseID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO course_purchases (org_id, user_id, course_id, amount_cents, currency, provider, provider_ref, status)
		 VALUES ($1, $2, $3, 1000, 'USD', 'stub', $4, 'completed') RETURNING id`,
		orgID, userID, courseID, fmt.Sprintf("stub_%s_%s", courseID, userID),
	).Scan(&purchaseID)
	if err != nil {
		t.Fatalf("create purchase: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM course_purchases WHERE id = $1`, purchaseID) }) //nolint:errcheck
	return purchaseID
}

func seedTestCoupon(t *testing.T, pool *pgxpool.Pool, orgID string, maxRedemptions *int) string {
	t.Helper()
	suffix := time.Now().UnixNano()
	var couponID string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO coupons (org_id, code, discount_type, discount_value, max_redemptions)
		 VALUES ($1, $2, 'percent', 10, $3) RETURNING id`,
		orgID, fmt.Sprintf("TEST%d", suffix), maxRedemptions,
	).Scan(&couponID)
	if err != nil {
		t.Fatalf("create coupon: %v", err)
	}
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM coupons WHERE id = $1`, couponID) }) //nolint:errcheck
	return couponID
}

// TestConsumeTx_ConcurrentRedemptionRespectsMaxRedemptions proves the guarded
// UPDATE ... WHERE redeemed_count < max_redemptions RETURNING closes the
// TOCTOU race a naive "SELECT to check, then INSERT" would have: firing N
// concurrent ConsumeTx calls (different users, so UNIQUE(coupon_id,user_id)
// isn't what's being tested) against a coupon capped at 1 redemption must
// yield exactly one success no matter how many goroutines race for it.
func TestConsumeTx_ConcurrentRedemptionRespectsMaxRedemptions(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgID := seedTestOrg(t, pool)
	creatorID := seedTestUser(t, pool)
	courseID := seedTestCourse(t, pool, orgID, creatorID)
	maxOne := 1
	couponID := seedTestCoupon(t, pool, orgID, &maxOne)

	const concurrency = 10
	var wg sync.WaitGroup
	successes := make(chan bool, concurrency)
	errs := make(chan error, concurrency)

	for i := 0; i < concurrency; i++ {
		userID := seedTestUser(t, pool)
		purchaseID := seedTestPurchase(t, pool, orgID, userID, courseID)
		wg.Add(1)
		go func(userID, purchaseID string) {
			defer wg.Done()
			tx, err := pool.Begin(ctx)
			if err != nil {
				errs <- err
				return
			}
			consumeErr := repo.ConsumeTx(ctx, tx, couponID, userID, purchaseID, 100)
			if consumeErr != nil {
				_ = tx.Rollback(ctx)
				if errors.Is(consumeErr, ErrExhausted) {
					successes <- false
					return
				}
				errs <- consumeErr
				return
			}
			if commitErr := tx.Commit(ctx); commitErr != nil {
				errs <- commitErr
				return
			}
			successes <- true
		}(userID, purchaseID)
	}
	wg.Wait()
	close(successes)
	close(errs)

	for err := range errs {
		t.Fatalf("unexpected error: %v", err)
	}

	successCount := 0
	for ok := range successes {
		if ok {
			successCount++
		}
	}
	if successCount != 1 {
		t.Fatalf("expected exactly 1 successful redemption out of %d concurrent attempts, got %d", concurrency, successCount)
	}

	var redeemedCount int
	if err := pool.QueryRow(ctx, `SELECT redeemed_count FROM coupons WHERE id = $1`, couponID).Scan(&redeemedCount); err != nil {
		t.Fatalf("check redeemed_count: %v", err)
	}
	if redeemedCount != 1 {
		t.Fatalf("expected coupons.redeemed_count = 1, got %d", redeemedCount)
	}
}

// TestConsumeTx_SameUserTwiceIsRejected proves UNIQUE(coupon_id, user_id)
// stops a second redemption by the same user even when max_redemptions
// would otherwise allow it.
func TestConsumeTx_SameUserTwiceIsRejected(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgID := seedTestOrg(t, pool)
	userID := seedTestUser(t, pool)
	courseID := seedTestCourse(t, pool, orgID, userID)
	couponID := seedTestCoupon(t, pool, orgID, nil) // unlimited redemptions

	purchase1 := seedTestPurchase(t, pool, orgID, userID, courseID)
	tx1, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin tx1: %v", err)
	}
	if err := repo.ConsumeTx(ctx, tx1, couponID, userID, purchase1, 100); err != nil {
		t.Fatalf("first consume: %v", err)
	}
	if err := tx1.Commit(ctx); err != nil {
		t.Fatalf("commit tx1: %v", err)
	}

	purchase2 := seedTestPurchase(t, pool, orgID, userID, courseID)
	tx2, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin tx2: %v", err)
	}
	err = repo.ConsumeTx(ctx, tx2, couponID, userID, purchase2, 100)
	_ = tx2.Rollback(ctx)
	if !errors.Is(err, ErrAlreadyUsed) {
		t.Fatalf("expected ErrAlreadyUsed on second redemption by the same user, got %v", err)
	}
}

// TestValidate_CourseScope proves a coupon restricted to specific courses
// (coupon_courses has rows) is rejected for any course not in that set, and
// that an org-wide coupon (no coupon_courses rows) is valid for any of them.
func TestValidate_CourseScope(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgID := seedTestOrg(t, pool)
	userID := seedTestUser(t, pool)
	scopedCourse := seedTestCourse(t, pool, orgID, userID)
	otherCourse := seedTestCourse(t, pool, orgID, userID)

	scopedCouponID := seedTestCoupon(t, pool, orgID, nil)
	if _, err := pool.Exec(ctx, `INSERT INTO coupon_courses (coupon_id, course_id) VALUES ($1, $2)`, scopedCouponID, scopedCourse); err != nil {
		t.Fatalf("scope coupon to course: %v", err)
	}
	var scopedCode string
	if err := pool.QueryRow(ctx, `SELECT code FROM coupons WHERE id = $1`, scopedCouponID).Scan(&scopedCode); err != nil {
		t.Fatalf("read coupon code: %v", err)
	}

	if _, err := repo.Validate(ctx, orgID, userID, scopedCourse, scopedCode); err != nil {
		t.Fatalf("expected coupon valid for its scoped course, got %v", err)
	}
	if _, err := repo.Validate(ctx, orgID, userID, otherCourse, scopedCode); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected ErrNotFound for a course outside the coupon's scope, got %v", err)
	}

	orgWideCouponID := seedTestCoupon(t, pool, orgID, nil)
	var orgWideCode string
	if err := pool.QueryRow(ctx, `SELECT code FROM coupons WHERE id = $1`, orgWideCouponID).Scan(&orgWideCode); err != nil {
		t.Fatalf("read coupon code: %v", err)
	}
	if _, err := repo.Validate(ctx, orgID, userID, otherCourse, orgWideCode); err != nil {
		t.Fatalf("expected an org-wide (no coupon_courses rows) coupon to be valid for any course, got %v", err)
	}
}

// TestCreate_RejectsCrossOrgCourseID proves an org cannot scope its coupon to
// another org's course_id — coupon_courses.course_id only has a bare FK to
// courses(id), with no org column of its own, so this has to be enforced at
// the repo boundary rather than left to the database to silently allow.
func TestCreate_RejectsCrossOrgCourseID(t *testing.T) {
	pool := testPool(t)
	repo := NewRepo(pool)
	ctx := context.Background()

	orgA := seedTestOrg(t, pool)
	orgB := seedTestOrg(t, pool)
	userB := seedTestUser(t, pool)
	courseInOrgB := seedTestCourse(t, pool, orgB, userB)

	_, err := repo.Create(ctx, Coupon{
		OrgID: orgA, Code: fmt.Sprintf("CROSSORG%d", time.Now().UnixNano()),
		DiscountType: DiscountTypePercent, DiscountValue: 10,
	}, []string{courseInOrgB})
	if !errors.Is(err, ErrInvalid) {
		t.Fatalf("expected ErrInvalid when scoping org A's coupon to org B's course, got %v", err)
	}

	var courseCount int
	if scanErr := pool.QueryRow(ctx, `SELECT COUNT(*) FROM coupon_courses WHERE course_id = $1`, courseInOrgB).Scan(&courseCount); scanErr != nil {
		t.Fatalf("count coupon_courses: %v", scanErr)
	}
	if courseCount != 0 {
		t.Fatalf("expected no coupon_courses row to have been written, got %d", courseCount)
	}

	// The whole Create call must roll back on the invalid course scope — no
	// orphaned coupon row left behind either.
	var couponCount int
	if scanErr := pool.QueryRow(ctx, `SELECT COUNT(*) FROM coupons WHERE org_id = $1`, orgA).Scan(&couponCount); scanErr != nil {
		t.Fatalf("count coupons: %v", scanErr)
	}
	if couponCount != 0 {
		t.Fatalf("expected the coupon insert to have rolled back, got %d coupons for org A", couponCount)
	}
}

package coupons

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

const couponColumns = `id, org_id, code, description, discount_type, discount_value,
	course_id, max_redemptions, redeemed_count, starts_at, expires_at,
	is_active, created_by, created_at, updated_at`

func scanCoupon(row interface{ Scan(dest ...any) error }) (Coupon, error) {
	var c Coupon
	err := row.Scan(
		&c.ID, &c.OrgID, &c.Code, &c.Description, &c.DiscountType, &c.DiscountValue,
		&c.CourseID, &c.MaxRedemptions, &c.RedeemedCount, &c.StartsAt, &c.ExpiresAt,
		&c.IsActive, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
	)
	return c, err
}

// getByCode fetches a coupon by org+code with no eligibility filtering — the
// caller (Validate) applies each rule individually so it can return a
// specific error (expired vs exhausted vs already-used) instead of one
// generic "not eligible".
func (r *Repo) getByCode(ctx context.Context, orgID, code string) (Coupon, error) {
	c, err := scanCoupon(r.pool.QueryRow(ctx,
		`SELECT `+couponColumns+` FROM coupons WHERE org_id = $1 AND upper(code) = upper($2)`,
		orgID, code,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Coupon{}, ErrNotFound
		}
		return Coupon{}, fmt.Errorf("coupons: get by code: %w", err)
	}
	return c, nil
}

// Validate is a read-only, advisory eligibility check for checkout-time
// preview — it is re-checked atomically by ConsumeTx at webhook
// confirmation, which is what actually prevents a race between two
// concurrent uses of the same coupon.
func (r *Repo) Validate(ctx context.Context, orgID, userID, courseID, code string) (Coupon, error) {
	c, err := r.getByCode(ctx, orgID, code)
	if err != nil {
		return Coupon{}, err
	}
	if !c.IsActive {
		return Coupon{}, ErrNotFound
	}
	if c.CourseID != nil && *c.CourseID != courseID {
		return Coupon{}, ErrNotFound
	}

	now := time.Now()
	if (c.StartsAt != nil && now.Before(*c.StartsAt)) || (c.ExpiresAt != nil && now.After(*c.ExpiresAt)) {
		return Coupon{}, ErrExpired
	}
	if c.MaxRedemptions != nil && c.RedeemedCount >= *c.MaxRedemptions {
		return Coupon{}, ErrExhausted
	}

	var alreadyUsed bool
	err = r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM coupon_redemptions WHERE coupon_id = $1 AND user_id = $2)`,
		c.ID, userID,
	).Scan(&alreadyUsed)
	if err != nil {
		return Coupon{}, fmt.Errorf("coupons: validate: check prior redemption: %w", err)
	}
	if alreadyUsed {
		return Coupon{}, ErrAlreadyUsed
	}

	return c, nil
}

// ConsumeTx atomically consumes one redemption of couponID within tx — must
// be called only after payment is confirmed (never at checkout-creation), so
// an abandoned checkout never burns a redemption for nothing.
//
// The guarded UPDATE...RETURNING is the actual concurrency fix: a naive
// "SELECT to check remaining redemptions, then INSERT" has a TOCTOU race
// that lets a capped coupon be redeemed more times than max_redemptions
// under concurrent requests. Here, zero rows updated means Postgres itself
// decided the coupon was already exhausted by the time this row lock was
// acquired — not a check Go performed and then hoped stayed true.
func (r *Repo) ConsumeTx(ctx context.Context, tx pgx.Tx, couponID, userID, purchaseID string, discountCents int) error {
	var redeemedCount int
	err := tx.QueryRow(ctx,
		`UPDATE coupons SET redeemed_count = redeemed_count + 1, updated_at = now()
		 WHERE id = $1 AND is_active
		   AND (starts_at IS NULL OR starts_at <= now())
		   AND (expires_at IS NULL OR expires_at > now())
		   AND (max_redemptions IS NULL OR redeemed_count < max_redemptions)
		 RETURNING redeemed_count`,
		couponID,
	).Scan(&redeemedCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrExhausted
		}
		return fmt.Errorf("coupons: consume: update coupon: %w", err)
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO coupon_redemptions (coupon_id, user_id, purchase_id, discount_cents) VALUES ($1, $2, $3, $4)`,
		couponID, userID, purchaseID, discountCents,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrAlreadyUsed
		}
		return fmt.Errorf("coupons: consume: insert redemption: %w", err)
	}
	return nil
}

// Create inserts a new coupon. Callers (service.go) have already normalized
// Code and validated DiscountType/DiscountValue.
func (r *Repo) Create(ctx context.Context, c Coupon) (Coupon, error) {
	created, err := scanCoupon(r.pool.QueryRow(ctx,
		`INSERT INTO coupons (org_id, code, description, discount_type, discount_value,
		   course_id, max_redemptions, starts_at, expires_at, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		 RETURNING `+couponColumns,
		c.OrgID, c.Code, c.Description, c.DiscountType, c.DiscountValue,
		c.CourseID, c.MaxRedemptions, c.StartsAt, c.ExpiresAt, c.CreatedBy,
	))
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return Coupon{}, fmt.Errorf("%w: a coupon with this code already exists", ErrInvalid)
		}
		return Coupon{}, fmt.Errorf("coupons: create: %w", err)
	}
	return created, nil
}

// List returns every coupon for orgID, newest first. includeInactive
// controls whether deactivated coupons are included.
func (r *Repo) List(ctx context.Context, orgID string, includeInactive bool) ([]Coupon, error) {
	query := `SELECT ` + couponColumns + ` FROM coupons WHERE org_id = $1`
	if !includeInactive {
		query += ` AND is_active`
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.pool.Query(ctx, query, orgID)
	if err != nil {
		return nil, fmt.Errorf("coupons: list: %w", err)
	}
	defer rows.Close()

	var out []Coupon
	for rows.Next() {
		c, err := scanCoupon(rows)
		if err != nil {
			return nil, fmt.Errorf("coupons: list: scan: %w", err)
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("coupons: list: %w", err)
	}
	return out, nil
}

// Get fetches a single coupon by id, scoped to orgID.
func (r *Repo) Get(ctx context.Context, orgID, id string) (Coupon, error) {
	c, err := scanCoupon(r.pool.QueryRow(ctx,
		`SELECT `+couponColumns+` FROM coupons WHERE id = $1 AND org_id = $2`, id, orgID,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Coupon{}, ErrNotFound
		}
		return Coupon{}, fmt.Errorf("coupons: get: %w", err)
	}
	return c, nil
}

// Update changes description/is_active/expires_at/max_redemptions only — the
// discount itself is never mutated on a coupon that may already have
// redemptions, since that would silently change the terms of a purchase
// already made under the original discount.
func (r *Repo) Update(ctx context.Context, orgID, id, description string, isActive bool, expiresAt *time.Time, maxRedemptions *int) (Coupon, error) {
	c, err := scanCoupon(r.pool.QueryRow(ctx,
		`UPDATE coupons SET description = $3, is_active = $4, expires_at = $5, max_redemptions = $6, updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+couponColumns,
		id, orgID, description, isActive, expiresAt, maxRedemptions,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Coupon{}, ErrNotFound
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23514" {
			return Coupon{}, fmt.Errorf("%w: max_redemptions cannot be set below the current redeemed count", ErrInvalid)
		}
		return Coupon{}, fmt.Errorf("coupons: update: %w", err)
	}
	return c, nil
}

// Deactivate soft-deletes a coupon (is_active = false) — a coupon with
// redemptions is never hard-deleted, since coupon_redemptions and
// course_purchases both reference it for audit/refund purposes.
func (r *Repo) Deactivate(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE coupons SET is_active = false, updated_at = now() WHERE id = $1 AND org_id = $2`, id, orgID,
	)
	if err != nil {
		return fmt.Errorf("coupons: deactivate: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

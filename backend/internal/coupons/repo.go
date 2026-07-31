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

// tx runs fn inside a transaction, committing on success and rolling back on
// any error fn returns. Mirrors mentoring.Repo's tx helper.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("coupons: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("coupons: commit tx: %w", err)
	}
	return nil
}

const couponColumns = `id, org_id, code, description, discount_type, discount_value,
	max_discount_cents, max_redemptions, redeemed_count, starts_at, expires_at,
	is_active, created_by, created_at, updated_at`

func scanCoupon(row interface{ Scan(dest ...any) error }) (Coupon, error) {
	var c Coupon
	err := row.Scan(
		&c.ID, &c.OrgID, &c.Code, &c.Description, &c.DiscountType, &c.DiscountValue,
		&c.MaxDiscountCents, &c.MaxRedemptions, &c.RedeemedCount, &c.StartsAt, &c.ExpiresAt,
		&c.IsActive, &c.CreatedBy, &c.CreatedAt, &c.UpdatedAt,
	)
	return c, err
}

// courseIDsFor returns the coupon_courses association for a single coupon —
// empty slice means org-wide (valid for any paid course).
func (r *Repo) courseIDsFor(ctx context.Context, couponID string) ([]string, error) {
	rows, err := r.pool.Query(ctx, `SELECT course_id FROM coupon_courses WHERE coupon_id = $1`, couponID)
	if err != nil {
		return nil, fmt.Errorf("coupons: course ids: %w", err)
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("coupons: course ids: scan: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// courseIDsForMany batch-loads coupon_courses for a set of coupons — used by
// List so it doesn't issue one query per row.
func (r *Repo) courseIDsForMany(ctx context.Context, couponIDs []string) (map[string][]string, error) {
	out := make(map[string][]string, len(couponIDs))
	if len(couponIDs) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `SELECT coupon_id, course_id FROM coupon_courses WHERE coupon_id = ANY($1)`, couponIDs)
	if err != nil {
		return nil, fmt.Errorf("coupons: course ids for many: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var couponID, courseID string
		if err := rows.Scan(&couponID, &courseID); err != nil {
			return nil, fmt.Errorf("coupons: course ids for many: scan: %w", err)
		}
		out[couponID] = append(out[couponID], courseID)
	}
	return out, rows.Err()
}

// setCourseIDsTx replaces couponID's course scope within tx — a full
// delete-then-insert since callers always supply the complete desired set,
// never a delta. Empty courseIDs leaves the coupon org-wide.
func setCourseIDsTx(ctx context.Context, tx pgx.Tx, couponID string, courseIDs []string) error {
	if _, err := tx.Exec(ctx, `DELETE FROM coupon_courses WHERE coupon_id = $1`, couponID); err != nil {
		return fmt.Errorf("coupons: clear course scope: %w", err)
	}
	for _, courseID := range courseIDs {
		if _, err := tx.Exec(ctx,
			`INSERT INTO coupon_courses (coupon_id, course_id) VALUES ($1, $2)`, couponID, courseID,
		); err != nil {
			return fmt.Errorf("coupons: set course scope: %w", err)
		}
	}
	return nil
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

	var courseAllowed bool
	err = r.pool.QueryRow(ctx,
		`SELECT NOT EXISTS(SELECT 1 FROM coupon_courses WHERE coupon_id = $1)
		    OR EXISTS(SELECT 1 FROM coupon_courses WHERE coupon_id = $1 AND course_id = $2)`,
		c.ID, courseID,
	).Scan(&courseAllowed)
	if err != nil {
		return Coupon{}, fmt.Errorf("coupons: validate: check course scope: %w", err)
	}
	if !courseAllowed {
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

	c.CourseIDs, err = r.courseIDsFor(ctx, c.ID)
	if err != nil {
		return Coupon{}, err
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

// Create inserts a new coupon plus its course scope (if any), atomically.
// Callers (service.go) have already normalized Code and validated
// DiscountType/DiscountValue.
func (r *Repo) Create(ctx context.Context, c Coupon, courseIDs []string) (Coupon, error) {
	var created Coupon
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var txErr error
		created, txErr = scanCoupon(tx.QueryRow(ctx,
			`INSERT INTO coupons (org_id, code, description, discount_type, discount_value,
			   max_discount_cents, max_redemptions, starts_at, expires_at, created_by)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
			 RETURNING `+couponColumns,
			c.OrgID, c.Code, c.Description, c.DiscountType, c.DiscountValue,
			c.MaxDiscountCents, c.MaxRedemptions, c.StartsAt, c.ExpiresAt, c.CreatedBy,
		))
		if txErr != nil {
			var pgErr *pgconn.PgError
			if errors.As(txErr, &pgErr) && pgErr.Code == "23505" {
				return fmt.Errorf("%w: a coupon with this code already exists", ErrInvalid)
			}
			return fmt.Errorf("coupons: create: %w", txErr)
		}
		return setCourseIDsTx(ctx, tx, created.ID, courseIDs)
	})
	if err != nil {
		return Coupon{}, err
	}
	created.CourseIDs = courseIDs
	return created, nil
}

// List returns every coupon for orgID, newest first, with CourseIDs
// populated. includeInactive controls whether deactivated coupons are
// included.
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
	var out []Coupon
	for rows.Next() {
		c, err := scanCoupon(rows)
		if err != nil {
			rows.Close()
			return nil, fmt.Errorf("coupons: list: scan: %w", err)
		}
		out = append(out, c)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("coupons: list: %w", err)
	}

	ids := make([]string, len(out))
	for i, c := range out {
		ids[i] = c.ID
	}
	scopes, err := r.courseIDsForMany(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range out {
		out[i].CourseIDs = scopes[out[i].ID]
	}
	return out, nil
}

// Get fetches a single coupon by id, scoped to orgID, with CourseIDs populated.
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
	c.CourseIDs, err = r.courseIDsFor(ctx, c.ID)
	if err != nil {
		return Coupon{}, err
	}
	return c, nil
}

// Update changes description/is_active/expires_at/max_redemptions/
// max_discount_cents/course scope only — the discount itself
// (discount_type/discount_value) is never mutated on a coupon that may
// already have redemptions, since that would silently change the terms of a
// purchase already made under the original discount.
func (r *Repo) Update(ctx context.Context, orgID, id, description string, isActive bool, expiresAt *time.Time, maxRedemptions, maxDiscountCents *int, courseIDs []string) (Coupon, error) {
	var updated Coupon
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var txErr error
		updated, txErr = scanCoupon(tx.QueryRow(ctx,
			`UPDATE coupons SET description = $3, is_active = $4, expires_at = $5,
			   max_redemptions = $6, max_discount_cents = $7, updated_at = now()
			 WHERE id = $1 AND org_id = $2
			 RETURNING `+couponColumns,
			id, orgID, description, isActive, expiresAt, maxRedemptions, maxDiscountCents,
		))
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrNotFound
			}
			var pgErr *pgconn.PgError
			if errors.As(txErr, &pgErr) && pgErr.Code == "23514" {
				return fmt.Errorf("%w: max_redemptions cannot be set below the current redeemed count", ErrInvalid)
			}
			return fmt.Errorf("coupons: update: %w", txErr)
		}
		return setCourseIDsTx(ctx, tx, updated.ID, courseIDs)
	})
	if err != nil {
		if errors.Is(err, ErrNotFound) || errors.Is(err, ErrInvalid) {
			return Coupon{}, err
		}
		return Coupon{}, err
	}
	updated.CourseIDs = courseIDs
	return updated, nil
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

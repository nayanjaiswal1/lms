// Package coupons implements discount codes for paid course purchases. It is
// a leaf package (imports only authz/auth/httputil and stdlib/chi/pgx) so
// both mentoring and courses can depend on it without any import cycle.
package coupons

import (
	"errors"
	"time"
)

const (
	DiscountTypePercent = "percent"
	DiscountTypeFixed   = "fixed"
)

// PermissionManageCoupons gates the admin CRUD routes — see
// backend/db/migrations/004_payments_coupons.sql for the seed grant.
const PermissionManageCoupons = "payments.manage_coupons"

var (
	ErrNotFound = errors.New("coupons: not found")
	ErrInvalid  = errors.New("coupons: invalid input")
	// ErrExhausted is returned by Repo.ConsumeTx when max_redemptions has
	// already been reached — the guarded UPDATE that detects this is the
	// TOCTOU fix (see repo.go), not an application-level check-then-write.
	ErrExhausted = errors.New("coupons: redemption limit reached")
	// ErrAlreadyUsed is returned by Repo.ConsumeTx on a
	// UNIQUE(coupon_id,user_id) violation — this user has already redeemed
	// this coupon on a different purchase.
	ErrAlreadyUsed = errors.New("coupons: already used by this user")
	ErrExpired     = errors.New("coupons: expired or not yet active")
)

// Coupon mirrors the coupons table.
type Coupon struct {
	ID             string
	OrgID          string
	Code           string
	Description    string
	DiscountType   string
	DiscountValue  int
	CourseID       *string // nil = valid for any paid course in the org
	MaxRedemptions *int
	RedeemedCount  int
	StartsAt       *time.Time
	ExpiresAt      *time.Time
	IsActive       bool
	CreatedBy      *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Preview is the read-only, checkout-time view of applying a coupon —
// advisory only, the actual discount is always recomputed server-side again
// at webhook confirmation (see mentoring.Service.HandleWebhook).
type Preview struct {
	Code                string `json:"code"`
	DiscountCents       int    `json:"discount_cents"`
	FinalAmountCents    int    `json:"final_amount_cents"`
	OriginalAmountCents int    `json:"original_amount_cents"`
}

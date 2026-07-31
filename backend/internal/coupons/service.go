package coupons

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

var codePattern = regexp.MustCompile(`^[A-Z0-9_-]{3,32}$`)

// NormalizeCode uppercases and trims a user-supplied coupon code — coupons
// are matched case-insensitively (coupons_org_code_key is a unique index on
// upper(code)), so callers must normalize before comparing or storing.
func NormalizeCode(code string) string {
	return strings.ToUpper(strings.TrimSpace(code))
}

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// Validate is a thin passthrough to Repo.Validate — exposed on Service (the
// package's public surface) so mentoring.Service can call into coupons
// without depending on its unexported repo internals directly.
func (s *Service) Validate(ctx context.Context, orgID, userID, courseID, code string) (Coupon, error) {
	return s.repo.Validate(ctx, orgID, userID, courseID, code)
}

// ConsumeTx is a thin passthrough to Repo.ConsumeTx — see that method for
// the atomic-redemption guarantee. tx must be a transaction already owned by
// the caller (mentoring.Service.confirmPurchase), since consuming a coupon
// redemption must commit or roll back atomically with marking the purchase
// completed and creating the enrollment.
func (s *Service) ConsumeTx(ctx context.Context, tx pgx.Tx, couponID, userID, purchaseID string, discountCents int) error {
	return s.repo.ConsumeTx(ctx, tx, couponID, userID, purchaseID, discountCents)
}

// Preview validates code against courseID and returns the discount it would
// apply to amountCents — advisory only, re-validated and recomputed again at
// webhook confirmation (see mentoring.Service.HandleWebhook).
func (s *Service) Preview(ctx context.Context, orgID, userID, courseID, code string, amountCents int) (Preview, error) {
	c, err := s.repo.Validate(ctx, orgID, userID, courseID, NormalizeCode(code))
	if err != nil {
		return Preview{}, err
	}
	discount := DiscountCents(c, amountCents)
	return Preview{
		Code:                c.Code,
		DiscountCents:       discount,
		FinalAmountCents:    amountCents - discount,
		OriginalAmountCents: amountCents,
	}, nil
}

// Create validates and inserts a new coupon.
func (s *Service) Create(ctx context.Context, c Coupon) (Coupon, error) {
	c.Code = NormalizeCode(c.Code)
	if !codePattern.MatchString(c.Code) {
		return Coupon{}, fmt.Errorf("%w: code must be 3-32 characters, uppercase letters/digits/-/_ only", ErrInvalid)
	}
	if c.DiscountType != DiscountTypePercent && c.DiscountType != DiscountTypeFixed {
		return Coupon{}, fmt.Errorf("%w: discount_type must be \"percent\" or \"fixed\"", ErrInvalid)
	}
	if c.DiscountType == DiscountTypePercent && (c.DiscountValue < 1 || c.DiscountValue > 100) {
		return Coupon{}, fmt.Errorf("%w: a percent discount must be between 1 and 100", ErrInvalid)
	}
	if c.DiscountType == DiscountTypeFixed && c.DiscountValue <= 0 {
		return Coupon{}, fmt.Errorf("%w: a fixed discount must be greater than 0", ErrInvalid)
	}
	if c.MaxRedemptions != nil && *c.MaxRedemptions <= 0 {
		return Coupon{}, fmt.Errorf("%w: max_redemptions must be positive when set", ErrInvalid)
	}
	if c.StartsAt != nil && c.ExpiresAt != nil && !c.ExpiresAt.After(*c.StartsAt) {
		return Coupon{}, fmt.Errorf("%w: expires_at must be after starts_at", ErrInvalid)
	}
	return s.repo.Create(ctx, c)
}

func (s *Service) List(ctx context.Context, orgID string, includeInactive bool) ([]Coupon, error) {
	return s.repo.List(ctx, orgID, includeInactive)
}

func (s *Service) Get(ctx context.Context, orgID, id string) (Coupon, error) {
	return s.repo.Get(ctx, orgID, id)
}

func (s *Service) Update(ctx context.Context, orgID, id, description string, isActive bool, expiresAt *time.Time, maxRedemptions *int) (Coupon, error) {
	if maxRedemptions != nil && *maxRedemptions <= 0 {
		return Coupon{}, fmt.Errorf("%w: max_redemptions must be positive when set", ErrInvalid)
	}
	return s.repo.Update(ctx, orgID, id, description, isActive, expiresAt, maxRedemptions)
}

func (s *Service) Deactivate(ctx context.Context, orgID, id string) error {
	return s.repo.Deactivate(ctx, orgID, id)
}

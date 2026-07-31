package mentoring

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/payments"
)

// newPendingProviderRef generates a unique placeholder for a purchase row
// created before the gateway has returned a real session/order id —
// provider_ref is NOT NULL and (provider, provider_ref) unique, so a pending
// row needs a value here from the moment it's inserted, not just once
// CreateCheckout returns.
func newPendingProviderRef() string {
	return "checkout_" + uuid.NewString()
}

// StartCheckout implements courses.CoursePurchaser. It validates the course
// and any coupon, opens (or reuses) a pending course_purchases row, and asks
// the requested payments.Provider to start a real checkout. It never grants
// access itself — only a webhook-confirmed HandleWebhook call does, since a
// real gateway confirms asynchronously (3DS, redirect, bank debit clearing)
// and this call only starts that process. The one exception is a 100%-off
// coupon (see the zero-total branch below), which has nothing to confirm.
func (s *Service) StartCheckout(ctx context.Context, req courses.CheckoutRequest) (courses.CheckoutSession, error) {
	course, err := s.coursesRepo.GetCourse(ctx, req.OrgID, req.CourseID)
	if err != nil {
		return courses.CheckoutSession{}, err
	}
	if course.IsFree || course.PriceCents <= 0 {
		return courses.CheckoutSession{}, fmt.Errorf("%w: course is free", ErrInvalid)
	}

	hasCompleted, err := s.repo.HasCompletedPurchase(ctx, req.UserID, req.CourseID)
	if err != nil {
		return courses.CheckoutSession{}, err
	}
	if hasCompleted {
		return courses.CheckoutSession{}, ErrAlreadyPurchased
	}

	provider, err := s.providers.Get(req.Provider)
	if err != nil {
		return courses.CheckoutSession{}, err
	}

	var couponID *string
	discountCents := 0
	if req.CouponCode != "" {
		c, cErr := s.coupons.Validate(ctx, req.OrgID, req.UserID, req.CourseID, coupons.NormalizeCode(req.CouponCode))
		if cErr != nil {
			return courses.CheckoutSession{}, cErr
		}
		discountCents = coupons.DiscountCents(c, course.PriceCents)
		couponID = &c.ID
	}
	finalAmount := course.PriceCents - discountCents
	if finalAmount < 0 {
		finalAmount = 0
	}

	// Reuse a still-live pending row for a double-click/retry within the
	// same 30-minute window instead of accumulating a new course_purchases
	// row per click — the purchase id (not the row itself) is what actually
	// needs to stay stable, since Stripe's checkout call is idempotent per
	// PurchaseID and re-running CreateCheckout below with the same id is
	// exactly what makes that so.
	purchase, err := s.repo.GetLivePendingPurchase(ctx, req.UserID, req.CourseID, provider.Name(), couponID)
	if err != nil {
		if !errors.Is(err, ErrNotFound) {
			return courses.CheckoutSession{}, err
		}
		purchase, err = s.repo.CreatePurchase(ctx, Purchase{
			OrgID: req.OrgID, UserID: req.UserID, CourseID: req.CourseID,
			AmountCents: finalAmount, DiscountCents: discountCents, Currency: s.currency,
			Provider: provider.Name(), ProviderRef: newPendingProviderRef(), CouponID: couponID,
		})
		if err != nil {
			return courses.CheckoutSession{}, err
		}
	}

	// Zero-total branch: a 100%-off coupon needs no gateway call at all —
	// several gateways reject a zero-amount checkout outright, and there is
	// nothing for the student to pay or confirm.
	if finalAmount == 0 {
		return s.completeZeroTotalCheckout(ctx, purchase, discountCents)
	}

	checkout, err := provider.CreateCheckout(ctx, payments.CheckoutParams{
		PurchaseID: purchase.ID, OrgID: req.OrgID, UserID: req.UserID, CourseID: req.CourseID,
		CourseTitle: course.Title, AmountCents: finalAmount, Currency: s.currency,
		SuccessURL: s.frontendURL + "/courses/" + course.Slug + "/checkout/return?purchase_id=" + purchase.ID,
		CancelURL:  s.frontendURL + "/courses/" + course.Slug + "?checkout=cancelled",
	})
	if err != nil {
		if markErr := s.repo.MarkPurchaseFailed(ctx, purchase.ID); markErr != nil {
			slog.Error("mentoring: failed to mark purchase failed after checkout creation error", "purchase_id", purchase.ID, "err", markErr)
		}
		return courses.CheckoutSession{}, fmt.Errorf("mentoring: start checkout: %w", err)
	}
	if err := s.repo.SetProviderRef(ctx, purchase.ID, checkout.ProviderRef); err != nil {
		return courses.CheckoutSession{}, err
	}

	return courses.CheckoutSession{
		PurchaseID: purchase.ID, Provider: provider.Name(), Status: PurchaseStatusPending,
		RedirectURL: checkout.RedirectURL, ClientParams: checkout.ClientParams,
		AmountCents: finalAmount, DiscountCents: discountCents, Currency: s.currency,
	}, nil
}

// completeZeroTotalCheckout runs the same confirmation path a webhook would,
// synchronously, for a purchase a coupon has discounted to zero. A
// payment_events row is still recorded (event id derived from the purchase
// id, so this can never double-fire for the same purchase) so a completed
// zero-total purchase is traceable through the same audit trail as a real
// gateway confirmation.
func (s *Service) completeZeroTotalCheckout(ctx context.Context, purchase Purchase, discountCents int) (courses.CheckoutSession, error) {
	eventID := "zero_total_" + purchase.ID
	eventRowID, inserted, err := s.repo.InsertPaymentEvent(ctx, purchase.Provider, eventID, "zero_total", purchase.ProviderRef, &purchase.ID, nil)
	if err != nil {
		return courses.CheckoutSession{}, err
	}
	if inserted {
		if _, _, err := s.confirmPurchase(ctx, purchase, "", eventRowID); err != nil {
			return courses.CheckoutSession{}, err
		}
	}
	return courses.CheckoutSession{
		PurchaseID: purchase.ID, Provider: purchase.Provider, Status: PurchaseStatusCompleted,
		AmountCents: 0, DiscountCents: discountCents, Currency: s.currency,
	}, nil
}

// PurchaseStatus implements courses.CoursePurchaser — polled by the
// frontend's checkout return page. The gateway redirect itself never grants
// access; only a webhook-confirmed "completed" status here does, which may
// land slightly after the redirect.
func (s *Service) PurchaseStatus(ctx context.Context, orgID, userID, courseID string) (courses.PurchaseStatus, error) {
	p, err := s.repo.GetLatestPurchase(ctx, orgID, userID, courseID)
	if err != nil {
		return courses.PurchaseStatus{}, err
	}
	enrolled, err := s.coursesRepo.IsEnrolled(ctx, userID, courseID)
	if err != nil {
		return courses.PurchaseStatus{}, fmt.Errorf("mentoring: purchase status: check enrollment: %w", err)
	}
	return courses.PurchaseStatus{PurchaseID: p.ID, Status: p.Status, Enrolled: enrolled}, nil
}

// HandleWebhook authenticates and processes a single gateway delivery for
// providerName. Every code path other than an unknown provider or an invalid
// signature acks the request (returns nil) — a webhook is never "failed"
// back to the gateway just because our side found nothing to do with it
// (unmatched purchase, already-processed event, amount mismatch), since that
// would only trigger pointless retries the gateway can't recover from.
func (s *Service) HandleWebhook(ctx context.Context, providerName string, rawBody []byte, h http.Header) error {
	provider, err := s.providers.Get(providerName)
	if err != nil {
		return err
	}

	ev, err := provider.ParseWebhook(rawBody, h)
	if err != nil {
		return err
	}

	eventRowID, inserted, err := s.repo.InsertPaymentEvent(ctx, provider.Name(), ev.ID, ev.Type, ev.ProviderRef, nil, ev.Raw)
	if err != nil {
		return err
	}
	if !inserted {
		// A gateway redelivering an event we've already recorded is normal
		// (Stripe retries for up to 72h) — not an error, just a no-op.
		return nil
	}

	if ev.Status == payments.StatusIgnored {
		return s.repo.MarkPaymentEventProcessed(ctx, eventRowID)
	}

	p, err := s.repo.GetPurchaseByProviderRef(ctx, provider.Name(), ev.ProviderRef)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			slog.Error("mentoring: webhook for unknown purchase", "provider", provider.Name(), "provider_ref", ev.ProviderRef, "event_type", ev.Type)
			return s.repo.MarkPaymentEventError(ctx, eventRowID, "no matching purchase for provider_ref")
		}
		return err
	}

	if ev.Status == payments.StatusFailed {
		if err := s.repo.MarkPurchaseFailed(ctx, p.ID); err != nil {
			return err
		}
		return s.repo.MarkPaymentEventProcessed(ctx, eventRowID)
	}

	// StatusSucceeded: cross-check the event against what we stored at
	// checkout-creation time before ever completing the purchase — a valid
	// signature only proves the delivery is authentically from the gateway,
	// not that it's about the amount we actually asked the gateway to
	// charge (a tampered or mismatched replay must never slip through just
	// because it passed HMAC/signature verification).
	if ev.AmountCents != p.AmountCents || !strings.EqualFold(ev.Currency, p.Currency) {
		slog.Error("mentoring: webhook amount/currency mismatch, purchase left pending",
			"purchase_id", p.ID, "expected_cents", p.AmountCents, "expected_currency", p.Currency,
			"got_cents", ev.AmountCents, "got_currency", ev.Currency)
		return s.repo.MarkPaymentEventError(ctx, eventRowID, "amount/currency mismatch")
	}

	_, _, err = s.confirmPurchase(ctx, p, ev.PaymentRef, eventRowID)
	return err
}

// confirmPurchase runs every side effect of a confirmed payment in one
// transaction: mark the purchase completed, consume the coupon redemption
// (if any), enroll the student, and open a mentor ticket unless they already
// have one — the exact same steps the old synchronous purchaseCourse ran,
// just triggered by a confirmed webhook (or the zero-total branch above)
// instead of an immediate stub charge.
//
// MarkPurchaseCompletedTx's guarded UPDATE is the real idempotency
// backstop: if it reports no transition (already completed by an earlier
// delivery), this returns immediately without touching coupons, enrollment,
// or tickets a second time.
func (s *Service) confirmPurchase(ctx context.Context, p Purchase, paymentRef, eventRowID string) (Purchase, bool, error) {
	var completed Purchase
	var transitioned bool
	err := s.repo.tx(ctx, func(tx pgx.Tx) error {
		var txErr error
		completed, transitioned, txErr = s.repo.MarkPurchaseCompletedTx(ctx, tx, p.ID, paymentRef)
		if txErr != nil {
			return txErr
		}
		if !transitioned {
			return nil
		}

		if completed.CouponID != nil {
			if cErr := s.coupons.ConsumeTx(ctx, tx, *completed.CouponID, completed.UserID, completed.ID, completed.DiscountCents); cErr != nil {
				if errors.Is(cErr, coupons.ErrExhausted) || errors.Is(cErr, coupons.ErrAlreadyUsed) {
					// The money is already taken — a lost coupon race must
					// never cost the student their paid enrollment. Logged
					// loudly for an operator to notice the discrepancy.
					slog.Error("mentoring: coupon redemption lost race after payment captured, enrollment proceeds anyway",
						"purchase_id", completed.ID, "coupon_id", *completed.CouponID, "err", cErr)
				} else {
					return cErr
				}
			}
		}

		enrolledBy := completed.UserID
		_, txErr = s.coursesRepo.CreateEnrollmentTx(ctx, tx, courses.Enrollment{
			UserID: completed.UserID, CourseID: completed.CourseID, EnrolledBy: &enrolledBy,
		})
		// ON CONFLICT DO NOTHING on an already-existing enrollment surfaces
		// as a wrapped pgx.ErrNoRows (RETURNING finds no row) — treated as
		// success, not failure, for webhook-replay safety.
		if txErr != nil && !errors.Is(txErr, pgx.ErrNoRows) {
			return txErr
		}

		hasMentor, txErr := s.repo.HasActiveMentor(ctx, tx, completed.OrgID, completed.UserID)
		if txErr != nil {
			return txErr
		}
		if !hasMentor {
			purchaseID := completed.ID
			if _, txErr := s.repo.CreateTicket(ctx, tx, Ticket{
				OrgID: completed.OrgID, StudentID: completed.UserID, CourseID: completed.CourseID, PurchaseID: &purchaseID,
			}); txErr != nil {
				return txErr
			}
		}

		if eventRowID != "" {
			if txErr := s.repo.MarkPaymentEventProcessedTx(ctx, tx, eventRowID, completed.ID); txErr != nil {
				return txErr
			}
		}
		return nil
	})
	if err != nil {
		return Purchase{}, false, err
	}
	return completed, transitioned, nil
}

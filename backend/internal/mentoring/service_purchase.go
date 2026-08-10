package mentoring

import (
	"context"
	"encoding/json"
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
	"github.com/mindforge/backend/internal/tickets"
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
	// GetCourse is org-scoped but status-agnostic (it also backs the author's
	// own draft views), so a student who knows a course id could otherwise pay
	// for a draft or archived course that has no catalog entry to consume.
	// Reported as courses.ErrNotFound, not a distinct error: an unpublished
	// course simply doesn't exist to a buyer, the same way GetCourseTree hides
	// someone else's self-course.
	if course.Status != courses.StatusPublished {
		return courses.CheckoutSession{}, courses.ErrNotFound
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
	var coupon *coupons.Coupon
	discountCents := 0
	if req.CouponCode != "" {
		c, cErr := s.coupons.Validate(ctx, req.OrgID, req.UserID, req.CourseID, coupons.NormalizeCode(req.CouponCode))
		if cErr != nil {
			return courses.CheckoutSession{}, cErr
		}
		discountCents = coupons.DiscountCents(c, course.PriceCents)
		couponID = &c.ID
		coupon = &c

		// Retire this student's own abandoned holds first, so a walked-away
		// checkout doesn't keep the coupon locked (see ExpireStaleCouponHolds).
		if err := s.repo.ExpireStaleCouponHolds(ctx, req.UserID, c.ID); err != nil {
			return courses.CheckoutSession{}, err
		}
		// c.RedeemedCount only counts webhook-confirmed redemptions; the live
		// holds are checkouts already opened at the discounted price whose
		// webhooks simply haven't landed yet. Both must count against the cap,
		// or a "first 10 customers" coupon can be handed to any number of
		// concurrent buyers, every one of whom then gets enrolled anyway once
		// their payment captures (see confirmPurchase's lost-race branch).
		//
		// The actual cap enforcement (FOR UPDATE-locked, atomic with the hold
		// it protects) happens below, immediately around CreatePurchaseTx —
		// checking here too would just be a stale, unlocked pre-check.
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
		// No existing hold to reuse — this is what actually consumes a
		// redemption slot, so the capped-coupon check and the insert run
		// inside one transaction with the coupon row locked FOR UPDATE the
		// whole time: two concurrent requests can no longer both read
		// "under cap" and both insert a hold.
		txErr := s.repo.tx(ctx, func(tx pgx.Tx) error {
			if coupon != nil && coupon.MaxRedemptions != nil {
				redeemed, lockErr := s.repo.LockCouponRedeemedCount(ctx, tx, coupon.ID)
				if lockErr != nil {
					return lockErr
				}
				held, cErr := s.repo.CountLiveCouponHoldsTx(ctx, tx, coupon.ID)
				if cErr != nil {
					return cErr
				}
				if redeemed+held >= *coupon.MaxRedemptions {
					return coupons.ErrExhausted
				}
			}
			var pErr error
			purchase, pErr = s.repo.CreatePurchaseTx(ctx, tx, Purchase{
				OrgID: req.OrgID, UserID: req.UserID, CourseID: req.CourseID,
				AmountCents: finalAmount, DiscountCents: discountCents, Currency: s.currency,
				Provider: provider.Name(), ProviderRef: newPendingProviderRef(), CouponID: couponID,
			})
			return pErr
		})
		if txErr != nil {
			// The coupon-hold index fired: this student already has an open
			// checkout (or a completed purchase) using this coupon. Same
			// meaning the API already has a message for.
			if errors.Is(txErr, ErrCouponHeld) {
				return courses.CheckoutSession{}, coupons.ErrAlreadyUsed
			}
			return courses.CheckoutSession{}, txErr
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
	// payment_events.payload is jsonb NOT NULL — a nil []byte encodes as SQL
	// NULL, so this branch needs a real (synthetic) payload rather than the
	// gateway body a webhook-driven event carries.
	payload, err := json.Marshal(map[string]string{
		"kind": "zero_total", "purchase_id": purchase.ID, "provider_ref": purchase.ProviderRef,
	})
	if err != nil {
		return courses.CheckoutSession{}, fmt.Errorf("mentoring: zero-total payload: %w", err)
	}
	eventRowID, inserted, err := s.repo.InsertPaymentEvent(ctx, purchase.Provider, eventID, "zero_total", purchase.ProviderRef, &purchase.ID, payload)
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

// GetReceipt returns purchaseID's receipt data, scoped to orgID and to
// userID owning the purchase — a student can only ever see their own
// receipt, there is no staff bypass here (staff work purchases through the
// refund action instead, which is org-scoped, not user-scoped).
func (s *Service) GetReceipt(ctx context.Context, orgID, userID, purchaseID string) (courses.Receipt, error) {
	p, err := s.repo.GetPurchase(ctx, orgID, purchaseID)
	if err != nil {
		return courses.Receipt{}, err
	}
	if p.UserID != userID {
		return courses.Receipt{}, ErrNotFound
	}
	return courses.Receipt{
		PurchaseID: p.ID, ReceiptNumber: p.ReceiptNumber, CourseID: p.CourseID,
		AmountCents: p.AmountCents, DiscountCents: p.DiscountCents, Currency: p.Currency,
		Provider: p.Provider, Status: p.Status, PurchasedAt: p.PurchasedAt,
	}, nil
}

// Refund reverses a completed purchase: calls the gateway's refund API,
// then in one transaction marks the purchase 'refunded' and revokes the
// enrollment it granted. Callers must already hold payments.manage_refunds
// (checked by route middleware) — this is never self-serve.
//
// The gateway call happens before the transaction, not inside it: a DB
// transaction must not hold open while waiting on an external HTTP call,
// and if the gateway call fails, nothing in our own data should have
// changed anyway.
func (s *Service) Refund(ctx context.Context, orgID, purchaseID string) error {
	p, err := s.repo.GetPurchase(ctx, orgID, purchaseID)
	if err != nil {
		return err
	}
	if p.Status != PurchaseStatusCompleted {
		return &clientErr{msg: "only a completed purchase can be refunded"}
	}
	if p.PaymentRef == nil || *p.PaymentRef == "" {
		return &clientErr{msg: "purchase has no payment reference to refund"}
	}

	provider, err := s.providers.Get(p.Provider)
	if err != nil {
		return err
	}
	if err := provider.Refund(ctx, *p.PaymentRef, p.AmountCents); err != nil {
		return err
	}

	return s.repo.tx(ctx, func(tx pgx.Tx) error {
		_, transitioned, err := s.repo.MarkPurchaseRefundedTx(ctx, tx, p.ID)
		if err != nil {
			return err
		}
		if !transitioned {
			// Lost a race with another refund attempt on the same purchase —
			// the gateway call above already succeeded (or the gateway itself
			// will report the duplicate), so this is a safe no-op, not an error.
			return nil
		}
		return s.coursesRepo.RevokeEnrollmentTx(ctx, tx, p.UserID, p.CourseID)
	})
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
		if !errors.Is(err, ErrNotFound) {
			return err
		}
		// Not a course purchase. Before writing this delivery off, offer it to
		// the other product that checks out through this same gateway — a
		// mentor session credit pack (see PackConfirmer). Its own amount /
		// currency cross-check runs on its side, against its own row.
		if s.packs != nil {
			matched, packErr := s.packs.ConfirmPackPurchase(ctx, provider.Name(), ev.ProviderRef,
				ev.PaymentRef, ev.AmountCents, ev.Currency, ev.Status == payments.StatusSucceeded)
			if packErr != nil {
				slog.Error("mentoring: session pack confirmation failed",
					"provider", provider.Name(), "provider_ref", ev.ProviderRef, "err", packErr)
				return s.repo.MarkPaymentEventError(ctx, eventRowID, "session pack confirmation failed: "+packErr.Error())
			}
			if matched {
				return s.repo.MarkPaymentEventProcessed(ctx, eventRowID)
			}
		}
		slog.Error("mentoring: webhook for unknown purchase", "provider", provider.Name(), "provider_ref", ev.ProviderRef, "event_type", ev.Type)
		return s.repo.MarkPaymentEventError(ctx, eventRowID, "no matching purchase for provider_ref")
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

	if _, _, err = s.confirmPurchase(ctx, p, ev.PaymentRef, eventRowID); err != nil {
		// The student ended up with two separately-paid checkouts for one
		// course (ux_course_purchases_completed rejected the second). Retrying
		// will never resolve that, so ack the delivery and leave the event
		// flagged for an operator to refund — returning the error would make
		// the gateway redeliver for 72h against a condition it cannot fix.
		if errors.Is(err, ErrAlreadyPurchased) {
			slog.Error("mentoring: second paid purchase for an already-owned course, refund required",
				"purchase_id", p.ID, "user_id", p.UserID, "course_id", p.CourseID, "payment_ref", ev.PaymentRef)
			return s.repo.MarkPaymentEventError(ctx, eventRowID, "duplicate completed purchase for this user+course — refund required")
		}
		return err
	}
	return nil
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
			purchaseID, courseID := completed.ID, completed.CourseID
			if _, txErr := s.tickets.CreateTx(ctx, tx, tickets.Ticket{
				OrgID: completed.OrgID, Kind: tickets.KindMentorship, RequesterID: completed.UserID,
				CourseID: &courseID, PurchaseID: &purchaseID,
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

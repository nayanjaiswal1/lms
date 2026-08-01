package sessions

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/payments"
)

// CheckoutSession is what the frontend needs to open a gateway checkout for
// a credit pack. Mirrors courses.CheckoutSession field-for-field so the
// existing checkout UI can consume either without a second code path.
type CheckoutSession struct {
	PurchaseID   string            `json:"purchase_id"`
	Provider     string            `json:"provider"`
	Status       string            `json:"status"`
	RedirectURL  string            `json:"redirect_url,omitempty"`
	ClientParams map[string]string `json:"client_params,omitempty"`
	AmountCents  int               `json:"amount_cents"`
	Currency     string            `json:"currency"`
}

// StartPackCheckout opens a pending session_pack_purchases row and asks the
// gateway to start a checkout. It never credits the ledger itself — only a
// webhook-confirmed ConfirmPackPurchase does, since a real gateway confirms
// asynchronously. This is the same split mentoring.StartCheckout uses for
// course purchases, for the same reason.
func (s *Service) StartPackCheckout(ctx context.Context, orgID, userID, packID, providerName string) (CheckoutSession, error) {
	cfg, err := s.repo.GetConfig(ctx, orgID)
	if err != nil {
		return CheckoutSession{}, err
	}
	if !cfg.Enabled {
		return CheckoutSession{}, ErrBookingDisabled
	}

	pack, err := s.repo.GetPack(ctx, orgID, packID)
	if err != nil {
		return CheckoutSession{}, err
	}
	if !pack.Active {
		return CheckoutSession{}, fmt.Errorf("%w: this pack is no longer on sale", ErrInvalid)
	}

	provider, err := s.providers.Get(providerName)
	if err != nil {
		return CheckoutSession{}, err
	}

	purchase, err := s.repo.CreatePackPurchase(ctx, PackPurchase{
		OrgID: orgID, UserID: userID, PackID: pack.ID, Sessions: pack.Sessions,
		AmountCents: pack.PriceCents, Currency: pack.Currency,
		Provider: provider.Name(), ProviderRef: "packcheckout_" + uuid.NewString(),
	})
	if err != nil {
		return CheckoutSession{}, err
	}

	// A free pack (an org handing out credits through the same catalogue UI
	// rather than the admin grant screen) has nothing to charge and no
	// gateway that would accept a zero-amount checkout — credit it now.
	if pack.PriceCents == 0 {
		if _, err := s.repo.CompletePurchase(ctx, purchase.ID, ""); err != nil {
			return CheckoutSession{}, err
		}
		return CheckoutSession{
			PurchaseID: purchase.ID, Provider: provider.Name(), Status: PurchaseStatusCompleted,
			AmountCents: 0, Currency: pack.Currency,
		}, nil
	}

	checkout, err := provider.CreateCheckout(ctx, payments.CheckoutParams{
		PurchaseID: purchase.ID,
		OrgID:      orgID,
		UserID:     userID,
		// CourseID/CourseTitle are the provider's generic description and
		// metadata slots (see stripe.go/razorpay.go — neither treats them as
		// a foreign key), so a pack rides them as its own identity rather
		// than needing a parallel set of fields on CheckoutParams.
		CourseID:    pack.ID,
		CourseTitle: pack.Name,
		AmountCents: pack.PriceCents,
		Currency:    pack.Currency,
		SuccessURL:  s.frontendURL + "/sessions/credits?purchase_id=" + purchase.ID,
		CancelURL:   s.frontendURL + "/sessions/credits?checkout=cancelled",
	})
	if err != nil {
		if markErr := s.repo.MarkPurchaseFailed(ctx, purchase.ID); markErr != nil {
			slog.Error("sessions: failed to mark pack purchase failed after checkout error",
				"purchase_id", purchase.ID, "err", markErr)
		}
		return CheckoutSession{}, fmt.Errorf("sessions: start pack checkout: %w", err)
	}
	if err := s.repo.SetPurchaseProviderRef(ctx, purchase.ID, checkout.ProviderRef); err != nil {
		return CheckoutSession{}, err
	}

	return CheckoutSession{
		PurchaseID: purchase.ID, Provider: provider.Name(), Status: PurchaseStatusPending,
		RedirectURL: checkout.RedirectURL, ClientParams: checkout.ClientParams,
		AmountCents: pack.PriceCents, Currency: pack.Currency,
	}, nil
}

// ConfirmPackPurchase implements mentoring.PackConfirmer — the pack half of
// payment-webhook handling. The mentoring package owns the single webhook
// endpoint (one gateway, one URL) and calls this when a delivery's
// provider_ref matches no course purchase. matched=false means the delivery
// is not a credit pack either, and the caller writes it off.
//
// The amount/currency cross-check mirrors the one mentoring performs: a valid
// signature proves the delivery is authentically from the gateway, not that
// it is about the amount we asked the gateway to charge.
func (s *Service) ConfirmPackPurchase(ctx context.Context, providerName, providerRef, paymentRef string, amountCents int, currency string, succeeded bool) (bool, error) {
	purchase, err := s.repo.GetPurchaseByProviderRef(ctx, providerName, providerRef)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return false, nil
		}
		return false, err
	}

	if !succeeded {
		return true, s.repo.MarkPurchaseFailed(ctx, purchase.ID)
	}

	if amountCents != purchase.AmountCents || !strings.EqualFold(currency, purchase.Currency) {
		slog.Error("sessions: pack webhook amount/currency mismatch, purchase left pending",
			"purchase_id", purchase.ID, "expected_cents", purchase.AmountCents,
			"expected_currency", purchase.Currency, "got_cents", amountCents, "got_currency", currency)
		return true, fmt.Errorf("sessions: pack purchase %s: amount/currency mismatch", purchase.ID)
	}

	transitioned, err := s.repo.CompletePurchase(ctx, purchase.ID, paymentRef)
	if err != nil {
		return true, err
	}
	if !transitioned {
		// A redelivery of an event we already credited. Normal, not an error.
		slog.Info("sessions: pack purchase already completed, webhook ignored", "purchase_id", purchase.ID)
	}
	return true, nil
}

// ListPacks returns the org's credit packs.
func (s *Service) ListPacks(ctx context.Context, orgID string, activeOnly bool) ([]CreditPack, error) {
	return s.repo.ListPacks(ctx, orgID, activeOnly)
}

// SavePack creates or updates a credit pack. Currency is always the
// deployment's PAYMENTS_CURRENCY — an org cannot price one pack in a
// currency the rest of the checkout stack does not use.
func (s *Service) SavePack(ctx context.Context, p CreditPack, actorID string) (CreditPack, error) {
	if l := len(p.Name); l < 1 || l > 120 {
		return CreditPack{}, fmt.Errorf("%w: name must be between 1 and 120 characters", ErrInvalid)
	}
	if p.Sessions < 1 || p.Sessions > 1000 {
		return CreditPack{}, fmt.Errorf("%w: a pack must contain between 1 and 1000 sessions", ErrInvalid)
	}
	if p.PriceCents < 0 {
		return CreditPack{}, fmt.Errorf("%w: price cannot be negative", ErrInvalid)
	}
	p.Currency = s.currency
	return s.repo.UpsertPack(ctx, p, actorID)
}

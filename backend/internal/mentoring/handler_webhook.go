package mentoring

import (
	"errors"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/payments"
)

// maxWebhookBodyBytes caps the request body read — a real Stripe/Razorpay
// delivery is a few KB; this exists only to bound a malformed/malicious
// request, not real traffic.
const maxWebhookBodyBytes = 1 << 20 // 1MB

// Webhook handles POST /api/payments/webhooks/{provider} — every payment
// gateway's confirmation callback. Public route (see RegisterPublicRoutes):
// the gateway itself is the caller, never a logged-in browser, so
// authentication is the provider's own signature scheme, not a session.
//
// The raw body is read here, in full, before anything else touches it.
// Razorpay's (and Stripe's) signature covers the exact bytes received, and
// re-serializing a JSON-decoded body does not reproduce them — no decoding
// happens in this function; Provider.ParseWebhook (called inside
// Service.HandleWebhook) is the only place the body is parsed, and only
// after verifying its signature against these same raw bytes.
func (h *Handler) Webhook(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxWebhookBodyBytes))
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Could not read request body.")
		return
	}

	provider := chi.URLParam(r, "provider")
	if err := h.service.HandleWebhook(r.Context(), provider, body, r.Header); err != nil {
		switch {
		case errors.Is(err, payments.ErrUnknownProvider):
			httputil.WriteError(w, http.StatusNotFound, "Unknown payment provider.")
		case errors.Is(err, payments.ErrInvalidSignature):
			httputil.WriteError(w, http.StatusUnauthorized, "Invalid webhook signature.")
		default:
			// Unlike most public webhook handlers in this codebase, a
			// genuine internal failure here is answered non-2xx on purpose:
			// there is no reconciliation sweep behind this endpoint, so the
			// gateway's own retry (Stripe retries for up to 72h) is what
			// recovers a transient DB hiccup instead of the purchase
			// silently staying 'pending' forever.
			httputil.WriteError(w, http.StatusInternalServerError, "Webhook processing failed.")
		}
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

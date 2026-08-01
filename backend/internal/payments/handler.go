package payments

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
)

// PublicConfig is what a client needs before it can render a single price:
// which currency every *_cents amount this deployment returns is denominated
// in. PAYMENTS_CURRENCY is the one authority for that (course prices, coupon
// amounts, and checkout totals are all in it), so it is served rather than
// duplicated into the frontend's build — a second copy is a second thing to
// get wrong, and it silently mislabels real money when it drifts.
type PublicConfig struct {
	Currency string `json:"currency"`
}

// RegisterPublicRoutes mounts the payments config endpoint. Public because the
// anonymous course catalog (/api/public/courses) shows prices too, so the
// formatting contract has to be readable without a session.
func RegisterPublicRoutes(r chi.Router, cfg *config.Config) {
	r.Get("/api/public/payments/config", func(w http.ResponseWriter, _ *http.Request) {
		httputil.WriteJSON(w, http.StatusOK, PublicConfig{Currency: cfg.PaymentsCurrency})
	})
}

package pricing

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound: {Status: http.StatusNotFound, Message: "Pricing tier not found."},
	ErrInvalid:  {Status: http.StatusUnprocessableEntity},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

type tierResponse struct {
	ID          string    `json:"id"`
	Audience    string    `json:"audience"`
	Position    int16     `json:"position"`
	Name        string    `json:"name"`
	Price       string    `json:"price"`
	BillingNote string    `json:"billing_note"`
	Tagline     string    `json:"tagline"`
	Features    []string  `json:"features"`
	CTALabel    string    `json:"cta_label"`
	CTADisabled bool      `json:"cta_disabled"`
	CTAHref     *string   `json:"cta_href,omitempty"`
	Highlighted bool      `json:"highlighted"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func toTierResponse(t Tier) tierResponse {
	return tierResponse{
		ID: t.ID, Audience: t.Audience, Position: t.Position, Name: t.Name,
		Price: t.Price, BillingNote: t.BillingNote, Tagline: t.Tagline, Features: t.Features,
		CTALabel: t.CTALabel, CTADisabled: t.CTADisabled, CTAHref: t.CTAHref,
		Highlighted: t.Highlighted, UpdatedAt: t.UpdatedAt,
	}
}

// ListPublic serves one landing page's pricing section — audience is
// required so a caller can never accidentally render the wrong page's tiers.
func (h *Handler) ListPublic(w http.ResponseWriter, r *http.Request) {
	audience := r.URL.Query().Get("audience")
	tiers, err := h.service.ListByAudience(r.Context(), audience)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	out := make([]tierResponse, len(tiers))
	for i, t := range tiers {
		out[i] = toTierResponse(t)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tiers": out})
}

// AdminList returns every tier across both audiences for the /platform/pricing
// admin page.
func (h *Handler) AdminList(w http.ResponseWriter, r *http.Request) {
	tiers, err := h.service.ListAll(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}
	out := make([]tierResponse, len(tiers))
	for i, t := range tiers {
		out[i] = toTierResponse(t)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tiers": out})
}

type updateTierRequest struct {
	Name        string   `json:"name"`
	Price       string   `json:"price"`
	BillingNote string   `json:"billing_note"`
	Tagline     string   `json:"tagline"`
	Features    []string `json:"features"`
	CTALabel    string   `json:"cta_label"`
	CTADisabled bool     `json:"cta_disabled"`
	CTAHref     *string  `json:"cta_href"`
	Highlighted bool     `json:"highlighted"`
}

// AdminUpdate edits an existing tier's display fields. id, audience, and
// position are not accepted here — see Service.Update's own comment on why
// the tier catalog's shape is fixed and only its content is editable.
func (h *Handler) AdminUpdate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")

	var req updateTierRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	updated, err := h.service.Update(r.Context(), id, Tier{
		Name: req.Name, Price: req.Price, BillingNote: req.BillingNote, Tagline: req.Tagline,
		Features: req.Features, CTALabel: req.CTALabel, CTADisabled: req.CTADisabled,
		CTAHref: req.CTAHref, Highlighted: req.Highlighted,
	}, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, toTierResponse(updated))
}

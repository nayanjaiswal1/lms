package whatsnew

import (
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
	ErrNotFound: {Status: http.StatusNotFound, Message: "Entry not found."},
	ErrInvalid:  {Status: http.StatusUnprocessableEntity},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

type entryResponse struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Icon        string    `json:"icon"`
	CTALabel    string    `json:"cta_label"`
	CTAHref     string    `json:"cta_href"`
	Published   bool      `json:"published"`
	PublishedAt time.Time `json:"published_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func toEntryResponse(e Entry) entryResponse {
	return entryResponse{
		ID: e.ID, Title: e.Title, Description: e.Description, Icon: e.Icon,
		CTALabel: e.CTALabel, CTAHref: e.CTAHref, Published: e.Published,
		PublishedAt: e.PublishedAt, UpdatedAt: e.UpdatedAt,
	}
}

// List returns the published entries for the sidebar panel — any
// authenticated user.
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	entries, err := h.service.ListPublished(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}
	out := make([]entryResponse, len(entries))
	for i, e := range entries {
		out[i] = toEntryResponse(e)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"entries": out})
}

// AdminList returns every entry, published and draft, for the platform
// admin editor.
func (h *Handler) AdminList(w http.ResponseWriter, r *http.Request) {
	entries, err := h.service.ListAll(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}
	out := make([]entryResponse, len(entries))
	for i, e := range entries {
		out[i] = toEntryResponse(e)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"entries": out})
}

type entryRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
	CTALabel    string `json:"cta_label"`
	CTAHref     string `json:"cta_href"`
	Published   bool   `json:"published"`
}

func (h *Handler) AdminCreate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req entryRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	createdBy := claims.UserID
	e, err := h.service.Create(r.Context(), Entry{
		Title: req.Title, Description: req.Description, Icon: req.Icon,
		CTALabel: req.CTALabel, CTAHref: req.CTAHref, Published: req.Published, CreatedBy: &createdBy,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, toEntryResponse(e))
}

func (h *Handler) AdminUpdate(w http.ResponseWriter, r *http.Request) {
	var req entryRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	e, err := h.service.Update(r.Context(), chi.URLParam(r, "id"), Entry{
		Title: req.Title, Description: req.Description, Icon: req.Icon,
		CTALabel: req.CTALabel, CTAHref: req.CTAHref, Published: req.Published,
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, toEntryResponse(e))
}

func (h *Handler) AdminDelete(w http.ResponseWriter, r *http.Request) {
	if err := h.service.Delete(r.Context(), chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

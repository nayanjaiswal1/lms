package highlights

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the highlights domain over HTTP.
type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// ─── shared helpers ───────────────────────────────────────────────────────────

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:      {Status: http.StatusNotFound, Message: "Highlight not found."},
	ErrNotOwner:      {Status: http.StatusForbidden, Message: "This highlight belongs to another user."},
	ErrInvalidSource: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"source_type": "must be one of: wiki_page, lesson, problem"}},
	ErrTextTooShort:  {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"selected_text": "must be at least 3 characters"}},
	ErrTextTooLong:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"selected_text": "must not exceed 2000 characters"}},
	ErrNoteTooLong:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"note": "must not exceed 1000 characters"}},
	ErrAIUnavailable: {Status: http.StatusServiceUnavailable, Message: "AI provider is not configured."},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

// ─── Handlers ─────────────────────────────────────────────────────────────────

// Create handles POST /api/highlights
// Saves a text selection without explaining it — used when the user clicks
// "Save for revision" without wanting an AI explanation.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	highlight, err := h.service.Create(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, highlight)
}

// Explain handles POST /api/highlights/explain
// Creates a highlight record and returns a cached or freshly generated AI
// explanation for the selected text. from_cache in the response indicates
// whether an LLM call was made.
func (h *Handler) Explain(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req ExplainRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	resp, err := h.service.Explain(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
}

// ToggleRevision handles PATCH /api/highlights/{highlightID}/revision
// Marks or unmarks a highlight as saved for spaced-repetition review.
func (h *Handler) ToggleRevision(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	highlightID := chi.URLParam(r, "highlightID")
	var req ToggleRevisionRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	highlight, err := h.service.ToggleRevision(r.Context(), claims.UserID, highlightID, req.SaveForRevision, req.Note)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, highlight)
}

// List handles GET /api/highlights?source_type=&source_id=&saved_only=&limit=&cursor=
// — the caller's own highlights, newest first, explanations joined in. Every
// filter is optional; one content resource's highlights pass both source
// params, the revision list passes saved_only=true.
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	p, ok := httputil.PageParams(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	f := ListFilter{SourceType: httputil.QueryStrPtr(r, "source_type"), SourceID: httputil.QueryStrPtr(r, "source_id")}
	if f.SourceID != nil {
		if _, err := uuid.Parse(*f.SourceID); err != nil {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"source_id": "must be a UUID"})
			return
		}
	}
	f.SavedOnly, _ = strconv.ParseBool(q.Get("saved_only"))
	page, err := h.service.List(r.Context(), claims.UserID, f, p)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// Analytics handles GET /api/admin/highlights/analytics
// Returns the most-served cached explanations as a proxy for "most confusing concepts".
// Query param: ?limit=50 (default 50, capped at 100).
func (h *Handler) Analytics(w http.ResponseWriter, r *http.Request) {
	limitStr := r.URL.Query().Get("limit")
	limit, _ := strconv.Atoi(limitStr)
	entries, err := h.service.TopExplanations(r.Context(), limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entries)
}

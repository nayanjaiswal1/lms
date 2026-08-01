package highlights

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

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

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:      {Status: http.StatusNotFound, Message: "Highlight not found."},
	ErrNotOwner:      {Status: http.StatusForbidden, Message: "This highlight belongs to another user."},
	ErrInvalidSource: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"source_type": "must be one of: wiki_page, lesson, problem"}},
	ErrTextTooShort:  {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"selected_text": "must be at least 3 characters"}},
	ErrTextTooLong:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"selected_text": "must not exceed 2000 characters"}},
	ErrNoteTooLong:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"note": "must not exceed 1000 characters"}},
	ErrAIUnavailable: {Status: http.StatusServiceUnavailable, Message: "AI provider is not configured."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

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
	if !decodeJSON(w, r, &req) {
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
	if !decodeJSON(w, r, &req) {
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
	if !decodeJSON(w, r, &req) {
		return
	}
	highlight, err := h.service.ToggleRevision(r.Context(), claims.UserID, highlightID, req.SaveForRevision, req.Note)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, highlight)
}

// ListBySource handles GET /api/highlights?source_type=&source_id=
// Returns the caller's highlights for a specific content resource with
// explanations joined in — used by the page-level "see all highlights" panel.
func (h *Handler) ListBySource(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	sourceType := SourceType(r.URL.Query().Get("source_type"))
	sourceID := r.URL.Query().Get("source_id")
	if sourceID == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"source_id": "required",
		})
		return
	}
	highlights, err := h.service.GetForSource(r.Context(), claims.UserID, sourceType, sourceID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, highlights)
}

// ListMine handles GET /api/highlights/me
// Returns the caller's highlights, newest first.
// Query param: ?saved_only=true filters to revision-saved highlights only.
func (h *Handler) ListMine(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	savedOnly, _ := strconv.ParseBool(r.URL.Query().Get("saved_only"))
	highlights, err := h.service.ListMine(r.Context(), claims.UserID, savedOnly)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, highlights)
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

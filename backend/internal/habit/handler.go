package habit

import (
	"net/http"

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
	ErrNotFound:             {Status: http.StatusNotFound, Message: "Habit not found."},
	ErrNameEmpty:            {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "is required"}},
	ErrNameTooLong:          {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "must not exceed 60 characters"}},
	ErrInvalidCadence:       {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"cadence": "must be one of: daily, weekly, monthly"}},
	ErrInvalidMonth:         {Status: http.StatusBadRequest, Message: "month must be formatted YYYY-MM."},
	ErrInvalidPeriod:        {Status: http.StatusBadRequest, Message: "period must be formatted YYYY-MM-DD."},
	ErrInvalidRange:         {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"from": "from/to must be YYYY-MM-DD, from <= to, at most a year apart."}},
	ErrInvalidColor:         {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"color": "must be one of the habit palette colors"}},
	ErrInvalidTarget:        {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"target_count": "must be between 1 and 7"}},
	ErrInvalidWeekday:       {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"weekdays": "must be unique values between 0 and 6"}},
	ErrConflictingModes:     {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"weekdays": "cannot be combined with a target_count above 1"}},
	ErrInvalidHabitType:     {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"type": "must be one of: generic, gym, sleep, reading, custom"}},
	ErrCustomFieldsEmpty:    {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"custom_fields": "must include at least one field for a custom habit"}},
	ErrTooManyCustomFields:  {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"custom_fields": "must not exceed 8 fields"}},
	ErrCustomFieldInvalid:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"custom_fields": "each field needs a unique key, a label, and a valid kind"}},
	ErrHabitHasNoFields:     {Status: http.StatusUnprocessableEntity, Message: "This habit type has no entry fields."},
	ErrInvalidMetadataField: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"metadata": "contains a field not defined for this habit"}},
	ErrInvalidIcon:          {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"icon": "must be one of the curated icon set"}},
	ErrTooManyTags:          {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"tags": "must not exceed 6 tags"}},
	ErrTagTooLong:           {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"tags": "each tag must not exceed 24 characters"}},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

// Create handles POST /api/habits
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	habit, err := h.service.Create(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, habit)
}

// Delete handles DELETE /api/habits/{habitID}
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	habitID := chi.URLParam(r, "habitID")
	if err := h.service.Delete(r.Context(), claims.UserID, habitID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Update handles PATCH /api/habits/{habitID} — a partial update of color,
// icon, and/or tags (whichever fields the body includes).
func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	habitID := chi.URLParam(r, "habitID")
	var req UpdateRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.Update(r.Context(), claims.UserID, habitID, req); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// List handles GET /api/habits?from=YYYY-MM-DD&to=YYYY-MM-DD — the caller's
// habits plus every completion whose period overlaps the range.
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	view, err := h.service.ListRange(r.Context(), claims.UserID, q.Get("from"), q.Get("to"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// SetCompletion handles PUT /api/habits/{habitID}/completions/{period}
func (h *Handler) SetCompletion(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	habitID := chi.URLParam(r, "habitID")
	period := chi.URLParam(r, "period")
	if err := h.service.SetCompletion(r.Context(), claims.UserID, habitID, period); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ClearCompletion handles DELETE /api/habits/{habitID}/completions/{period}
func (h *Handler) ClearCompletion(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	habitID := chi.URLParam(r, "habitID")
	period := chi.URLParam(r, "period")
	if err := h.service.ClearCompletion(r.Context(), claims.UserID, habitID, period); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// SetCompletionMetadata handles PUT /api/habits/{habitID}/completions/{period}/metadata
func (h *Handler) SetCompletionMetadata(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	habitID := chi.URLParam(r, "habitID")
	period := chi.URLParam(r, "period")
	var req SetMetadataRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.SetCompletionMetadata(r.Context(), claims.UserID, habitID, period, req.Metadata); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

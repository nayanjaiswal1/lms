package habit

import (
	"encoding/json"
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
	ErrNotFound:         {Status: http.StatusNotFound, Message: "Habit not found."},
	ErrNameEmpty:        {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "is required"}},
	ErrNameTooLong:      {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"name": "must not exceed 60 characters"}},
	ErrInvalidCadence:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"cadence": "must be one of: daily, weekly, monthly"}},
	ErrInvalidMonth:     {Status: http.StatusBadRequest, Message: "month must be formatted YYYY-MM."},
	ErrInvalidPeriod:    {Status: http.StatusBadRequest, Message: "period must be formatted YYYY-MM-DD."},
	ErrInvalidColor:     {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"color": "must be one of the habit palette colors"}},
	ErrInvalidTarget:    {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"target_count": "must be between 1 and 7"}},
	ErrInvalidWeekday:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"weekdays": "must be unique values between 0 and 6"}},
	ErrConflictingModes: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"weekdays": "cannot be combined with a target_count above 1"}},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// Create handles POST /api/habits
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
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

// UpdateColor handles PATCH /api/habits/{habitID}
func (h *Handler) UpdateColor(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	habitID := chi.URLParam(r, "habitID")
	var req UpdateColorRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}
	if err := h.service.UpdateColor(r.Context(), claims.UserID, habitID, req.Color); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// MonthView handles GET /api/habits?month=2026-08
func (h *Handler) MonthView(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	month := r.URL.Query().Get("month")
	if month == "" {
		httputil.WriteError(w, http.StatusBadRequest, "month query param is required (YYYY-MM).")
		return
	}
	view, err := h.service.MonthView(r.Context(), claims.UserID, month)
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

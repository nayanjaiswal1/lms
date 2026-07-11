package whatnow

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the What Now? domain over HTTP.
type Handler struct {
	service *Service
}

// NewHandler constructs the What Now? handler from a connection pool.
func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{service: NewService(NewRepo(pool))}
}

// ctxClaims pulls authenticated claims or writes 401 and returns false.
func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

// writeDomainError maps domain errors to HTTP responses.
func writeDomainError(w http.ResponseWriter, err error) {
	if errors.Is(err, ErrNotFound) {
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
		return
	}
	httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
}

// decodeJSON decodes r.Body into dst. Writes 400 and returns false on error.
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

// GetNow handles GET /api/whatnow/tasks/now.
func (h *Handler) GetNow(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	q := NowQuery{Energy: EnergySharp}
	if v := r.URL.Query().Get("energy"); v == string(EnergyTired) {
		q.Energy = EnergyTired
	}
	if v := r.URL.Query().Get("availableMin"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			q.AvailableMin = &n
		}
	}
	res, err := h.service.GetNow(r.Context(), claims.UserID, q)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, res)
}

// GetInbox handles GET /api/whatnow/tasks/inbox.
func (h *Handler) GetInbox(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	tasks, err := h.service.GetInbox(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tasks)
}

// GetPlanToday handles GET /api/whatnow/plan/today.
func (h *Handler) GetPlanToday(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	plan, err := h.service.GetPlanToday(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, plan)
}

// GetDecayed handles GET /api/whatnow/archive/decayed.
func (h *Handler) GetDecayed(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	tasks, err := h.service.GetDecayed(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tasks)
}

// GetWeeklyRecap handles GET /api/whatnow/recap/weekly.
func (h *Handler) GetWeeklyRecap(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	recap, err := h.service.GetWeeklyRecap(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, recap)
}

// GetDayPlan handles GET /api/whatnow/plan/day.
func (h *Handler) GetDayPlan(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	// ?tz= is the client's UTC offset in minutes east of UTC; malformed or
	// out-of-range (beyond UTC±14:00) values fall back to a UTC day window.
	tzOffsetMin, tzErr := strconv.Atoi(r.URL.Query().Get("tz"))
	if tzErr != nil || tzOffsetMin < -14*60 || tzOffsetMin > 14*60 {
		tzOffsetMin = 0
	}
	plan, err := h.service.GetDayPlan(r.Context(), claims.UserID, r.URL.Query().Get("date"), tzOffsetMin)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, plan)
}

// CaptureTask handles POST /api/whatnow/tasks.
func (h *Handler) CaptureTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req CaptureRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Raw == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"raw": "raw is required.",
		})
		return
	}
	task, err := h.service.CaptureTask(r.Context(), claims.UserID, req.Raw)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, task)
}

// PostPlanToday handles POST /api/whatnow/plan/today.
func (h *Handler) PostPlanToday(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req PlanTodayRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	plan, err := h.service.PostPlanToday(r.Context(), claims.UserID, req.TaskIDs)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, plan)
}

// CompleteTask handles POST /api/whatnow/tasks/{id}/complete.
func (h *Handler) CompleteTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	res, err := h.service.CompleteTask(r.Context(), claims.UserID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, res)
}

// PauseTask handles POST /api/whatnow/tasks/{id}/pause.
func (h *Handler) PauseTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var req PauseRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	task, err := h.service.PauseTask(r.Context(), claims.UserID, id, req.ResumeNote)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, task)
}

// StuckTask handles POST /api/whatnow/tasks/{id}/stuck.
func (h *Handler) StuckTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var req StuckRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	switch req.Reason {
	case StuckTooBig, StuckNotSureItMatters, StuckDeadlineUnreal, StuckCantFocus:
	default:
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"reason": "reason must be one of too_big, not_sure_it_matters, deadline_unreal, cant_focus.",
		})
		return
	}
	res, err := h.service.StuckTask(r.Context(), claims.UserID, id, req.Reason)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, res)
}

// ReviveTask handles POST /api/whatnow/tasks/{id}/revive.
func (h *Handler) ReviveTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	task, err := h.service.ReviveTask(r.Context(), claims.UserID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, task)
}

// ProposeBreakdown handles POST /api/whatnow/tasks/{id}/breakdown.
func (h *Handler) ProposeBreakdown(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	proposal, err := h.service.ProposeBreakdown(r.Context(), claims.UserID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, proposal)
}

// ConfirmBreakdown handles POST /api/whatnow/tasks/{id}/breakdown/confirm.
func (h *Handler) ConfirmBreakdown(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var proposal BreakdownProposal
	if !decodeJSON(w, r, &proposal) {
		return
	}
	tasks, err := h.service.ConfirmBreakdown(r.Context(), claims.UserID, id, proposal)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tasks)
}

// PatchTask handles PATCH /api/whatnow/tasks/{id}.
func (h *Handler) PatchTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var patch TaskPatch
	if !decodeJSON(w, r, &patch) {
		return
	}
	task, err := h.service.PatchTask(r.Context(), claims.UserID, id, patch)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, task)
}

// PutEnergy handles PUT /api/whatnow/me/energy.
func (h *Handler) PutEnergy(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req EnergyRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Energy != EnergySharp && req.Energy != EnergyTired {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"energy": "energy must be 'sharp' or 'tired'.",
		})
		return
	}
	if err := h.service.PutEnergy(r.Context(), claims.UserID, req.Energy); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"energy": string(req.Energy)})
}

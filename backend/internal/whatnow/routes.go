package whatnow

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// New constructs the What Now? domain handler.
func New(pool *pgxpool.Pool) *Handler {
	return NewHandler(pool)
}

// RegisterRoutes mounts the What Now? endpoints under /api/whatnow.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/whatnow/tasks/now", h.GetNow)
	r.Get("/api/whatnow/tasks/inbox", h.GetInbox)
	r.Get("/api/whatnow/plan/today", h.GetPlanToday)
	r.Get("/api/whatnow/plan/day", h.GetDayPlan)
	r.Get("/api/whatnow/archive/decayed", h.GetDecayed)
	r.Get("/api/whatnow/recap/weekly", h.GetWeeklyRecap)
	r.Post("/api/whatnow/tasks", h.CaptureTask)
	r.Post("/api/whatnow/plan/today", h.PostPlanToday)
	r.Post("/api/whatnow/tasks/{id}/complete", h.CompleteTask)
	r.Post("/api/whatnow/tasks/{id}/pause", h.PauseTask)
	r.Post("/api/whatnow/tasks/{id}/stuck", h.StuckTask)
	r.Post("/api/whatnow/tasks/{id}/revive", h.ReviveTask)
	r.Post("/api/whatnow/tasks/{id}/breakdown", h.ProposeBreakdown)
	r.Post("/api/whatnow/tasks/{id}/breakdown/confirm", h.ConfirmBreakdown)
	r.Patch("/api/whatnow/tasks/{id}", h.PatchTask)
	r.Put("/api/whatnow/me/energy", h.PutEnergy)
}

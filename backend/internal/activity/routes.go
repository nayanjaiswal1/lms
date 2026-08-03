package activity

import "github.com/go-chi/chi/v5"

// RegisterRoutes mounts the activity feed endpoint.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/activity", h.List)
}

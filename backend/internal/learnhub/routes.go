package learnhub

import "github.com/go-chi/chi/v5"

// RegisterRoutes mounts the Learn hub aggregator endpoint.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/learn/hub-stats", h.GetStats)
}

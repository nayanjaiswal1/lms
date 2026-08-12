package journal

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/authz"
)

// New builds the fully-wired journal handler.
func New(pool *pgxpool.Pool, provider ai.LLMProvider) *Handler {
	return NewHandler(pool, provider)
}

// RegisterRoutes mounts the journal API onto the given router, gated on
// content.learning_journal — enforced server-side regardless of what the
// frontend nav/UI already checks. The caller is responsible for applying
// RequireAuth + RequireCSRF before this.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.learning_journal")).Group(func(r chi.Router) {
		r.Get("/api/journal", h.ListEntries)
		r.Get("/api/journal/categories", h.ListCategories)
		r.Get("/api/journal/graph", h.GetGraph)
		r.Post("/api/journal", h.CreateEntry)
		r.Post("/api/journal/structure", h.StructureEntry)
		r.Get("/api/journal/{id}", h.GetEntry)
		r.Patch("/api/journal/{id}", h.UpdateEntry)
		r.Delete("/api/journal/{id}", h.DeleteEntry)
	})
}

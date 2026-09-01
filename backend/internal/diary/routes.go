package diary

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/authz"
)

// New builds the fully-wired diary handler.
func New(pool *pgxpool.Pool, provider ai.LLMProvider) *Handler {
	return NewHandler(pool, provider)
}

// RegisterRoutes mounts the diary API onto the given router, gated on
// content.diary — enforced server-side regardless of what the frontend
// nav/UI already checks. The caller is responsible for applying
// RequireAuth + RequireCSRF before this.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.diary")).Group(func(r chi.Router) {
		r.Get("/api/diary", h.ListEntries)
		r.Get("/api/diary/today", h.GetToday)
		r.Get("/api/diary/{date}", h.GetByDate)
		r.Patch("/api/diary/{date}", h.UpdateContent)
		r.Post("/api/diary/{date}/analyze/preview", h.AnalyzePreview)
		r.Post("/api/diary/{date}/analyze/apply", h.AnalyzeApply)
		r.Post("/api/diary/{date}/fix-english", h.FixEnglish)
	})
}

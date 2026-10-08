package labauthor

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/redis/go-redis/v9"
)

// Permission codes (migration 047_lab_authoring_permissions.sql; mirrored in
// frontend/lib/auth/permission-codes.ts). docs/debug-labs.md B7 names them
// debuglabs.*; the generic names apply because composition is kind-agnostic.
const (
	PermCompose      = "labauthor.compose"
	PermManageBlocks = "labauthor.manage_blocks"
)

// New wires the lab-authoring dependency graph. aiProvider may be a no-op
// provider; ticket drafting then reports ai_unavailable.
func New(pool *pgxpool.Pool, rdb *redis.Client, aiProvider ai.LLMProvider, cfg *config.Config) *Handler {
	drafter := NewDrafter(aiProvider, ratelimit.New(rdb), cfg.LabAuthorDraftRateMax, cfg.LabAuthorDraftRateWindow)
	return NewHandler(NewService(NewRepo(pool), drafter))
}

// Service exposes the application service to the build/publish phase.
func (h *Handler) Service() *Service { return h.svc }

// RegisterRoutes mounts the authoring API. The caller applies RequireAuth and
// RequireCSRF first; org scoping is enforced inside every query.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service, pool *pgxpool.Pool) {
	compose := authz.RequirePermission(authzSvc, PermCompose)
	manage := authz.RequirePermission(authzSvc, PermCompose, PermManageBlocks)

	r.Route("/api/instructor/lab-authoring", func(r chi.Router) {
		r.Group(func(r chi.Router) {
			r.Use(compose)
			r.Get("/blocks", h.HandleListBlocks)
			r.Get("/blocks/{id}", h.HandleGetBlock)

			r.Get("/recipes", h.HandleListRecipes)
			r.Post("/recipes", h.HandleCreateRecipe)
			r.Get("/recipes/{id}", h.HandleGetRecipe)
			r.Put("/recipes/{id}", h.HandleUpdateRecipe)
			r.Delete("/recipes/{id}", h.HandleDeleteRecipe)
			r.Get("/recipes/{id}/analysis", h.HandleRecipeAnalysis)
			r.Get("/recipes/{id}/candidates", h.HandleRecipeCandidates)
			r.With(middleware.Idempotency(pool)).Post("/recipes/{id}/ticket-draft", h.HandleTicketDraft)
		})
		r.Group(func(r chi.Router) {
			r.Use(manage)
			r.Post("/blocks", h.HandleCreateBlock)
			r.Put("/blocks/{id}", h.HandleUpdateBlock)
			r.Delete("/blocks/{id}", h.HandleDeleteBlock)
		})
	})

	r.Route("/api/admin/lab-authoring/blocks/{versionID}", func(r chi.Router) {
		r.Use(middleware.RequirePlatformRole(pool, middleware.PlatformRoleSuperAdmin))
		r.Get("/affected-labs", h.HandleAffectedLabs)
		r.Post("/yank", h.HandleYankVersion)
	})
}

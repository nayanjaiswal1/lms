package profile

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/storage"
)

// ProfileHandler is the top-level entry point for the profile domain.
// It wires the full dependency graph and exposes route registration methods.
type ProfileHandler struct {
	handler *Handler
}

// New constructs the profile stack: Repo → Service → Handler. certsRepo is
// shared (read-only here) so the public profile can list a learner's earned
// certificates without a second query path into the certificates domain.
func New(pool *pgxpool.Pool, cfg *config.Config, store storage.StorageClient, certsRepo *certificates.Repo, aiProvider ai.LLMProvider) *ProfileHandler {
	repo := NewRepo(pool)
	svc := NewService(repo, store, cfg, certsRepo, aiProvider)
	h := newHandler(svc, pool)
	return &ProfileHandler{handler: h}
}

// RegisterRoutes mounts the authenticated profile routes.
// Must be called inside a group that already has RequireAuth + RequireCSRF applied.
func (ph *ProfileHandler) RegisterRoutes(r chi.Router) {
	r.Get("/api/profile/me", ph.handler.HandleGetMyProfile)
	r.Get("/api/profile/me/overview", ph.handler.HandleGetMyOverview)
	r.Patch("/api/profile/me", ph.handler.HandleUpdateProfile)
	r.Put("/api/profile/me/last-page", ph.handler.HandleSetLastPage)
	r.Post("/api/profile/me/avatar", ph.handler.HandleUploadAvatar)
	r.Delete("/api/profile/me/avatar", ph.handler.HandleDeleteAvatar)
	r.Get("/api/profile/me/skills", ph.handler.HandleGetMySkills)
	r.Post("/api/profile/me/skills", ph.handler.HandleAddSkill)
	r.Delete("/api/profile/me/skills/{skillID}", ph.handler.HandleRemoveSkill)
	r.Post("/api/profile/me/resume/parse", ph.handler.HandleParseResume)
	r.Get("/api/profile/user/{userID}", ph.handler.HandleGetUserProfile)
}

// RegisterPublicRoutes mounts the unauthenticated profile routes.
// Must be called on the root router, outside the RequireAuth group.
func (ph *ProfileHandler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/profile/public/{slug}", ph.handler.HandleGetPublicProfile)
}

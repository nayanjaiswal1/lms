package systemdesign

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
)

// Router wires the systemdesign domain into the main chi router. Service is
// exported so mcpconnect can reuse the exact same attempt/scene/feedback/chat
// logic for its AI Connector tools instead of a second implementation.
type Router struct {
	handler *Handler
	Service *Service
}

// New builds the systemdesign Router with its full dependency graph.
// coursesRepo is shared with the courses package (read-only here) so every
// endpoint can validate a moduleId is a real, org-scoped system_design
// question without a second query path into course_modules.
func New(pool *pgxpool.Pool, coursesRepo *courses.Repo, provider ai.LLMProvider) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, coursesRepo, provider)
	return &Router{handler: newHandler(service), Service: service}
}

// RegisterRoutes mounts system-design endpoints under the caller's
// authenticated group, gated on content.system_design — the same permission
// code the frontend's nav entry and <AccessGate> already check, enforced
// again here since UI gates are UX, not security.
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.system_design")).Group(func(r chi.Router) {
		r.Get("/api/modules/{moduleId}/design/attempts", rt.handler.ListAttempts)
		r.Post("/api/modules/{moduleId}/design/attempts", rt.handler.CreateAttempt)
		r.Get("/api/modules/{moduleId}/design/attempts/{attemptId}", rt.handler.GetAttempt)
		r.Put("/api/modules/{moduleId}/design/attempts/{attemptId}/scene", rt.handler.SaveScene)
		r.Post("/api/modules/{moduleId}/design/attempts/{attemptId}/feedback", rt.handler.GenerateFeedback)

		r.Get("/api/modules/{moduleId}/design/chat", rt.handler.ListChat)
		r.Post("/api/modules/{moduleId}/design/chat", rt.handler.SendChatMessage)
	})
}

package practice

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/authz"
)

// Router mounts the practice HTTP API. Service is exported so other packages
// (e.g. interviewprep, which delegates its conceptual round to a practice
// session) can be handed the concrete *Service — mirrors mentoring.Router.
//
// Session creation and listing are no longer routed here directly: every
// practice session is created through interviewprep.CreatePlan now (quick or
// targeted mode), which wraps it in a Plan. Only the endpoints the round-
// answering UI hits directly (fetch one session, answer an item, mark status)
// stay public.
type Router struct {
	handler *Handler
	Service *Service
}

func New(pool *pgxpool.Pool, provider ai.LLMProvider) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, provider)
	return &Router{handler: &Handler{service: service, repo: repo}, Service: service}
}

// RegisterRoutes mounts the practice API, gated on practice.use — the same
// permission code the frontend's nav entry and <AccessGate> already check,
// enforced again here since UI gates are UX, not security.
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "practice.use")).Group(func(r chi.Router) {
		r.Get("/api/practice/technologies", rt.handler.ListTechnologies)
		r.Get("/api/practice/sessions/{sessionID}", rt.handler.GetSession)
		r.Patch("/api/practice/sessions/{sessionID}", rt.handler.UpdateSessionStatus)
		r.Post("/api/practice/sessions/{sessionID}/items/{position}/answer", rt.handler.SubmitAnswer)
	})
}

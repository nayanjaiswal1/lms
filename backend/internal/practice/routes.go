package practice

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
)

type Router struct {
	handler *Handler
}

func New(pool *pgxpool.Pool, provider ai.LLMProvider) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, provider)
	return &Router{handler: &Handler{service: service, repo: repo}}
}

func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/practice/technologies", rt.handler.ListTechnologies)
	r.Get("/api/practice/sessions", rt.handler.ListSessions)
	r.Post("/api/practice/sessions", rt.handler.CreateSession)
	r.Get("/api/practice/sessions/{sessionID}", rt.handler.GetSession)
	r.Patch("/api/practice/sessions/{sessionID}", rt.handler.UpdateSessionStatus)
	r.Post("/api/practice/sessions/{sessionID}/items/{position}/answer", rt.handler.SubmitAnswer)
}

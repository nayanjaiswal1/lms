package messaging

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/middleware"
)

type Router struct {
	handler *Handler
}

func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: &Handler{service: service, repo: repo}}
}

func (rt *Router) RegisterRoutes(r chi.Router) {
	staff := middleware.RequireOrgRole(middleware.RoleAdmin, middleware.RoleInstructor, middleware.RoleMentor)
	adminInstructor := middleware.RequireOrgRole(middleware.RoleAdmin, middleware.RoleInstructor)

	// Batch messages — any authenticated member can list and post
	r.Get("/api/batches/{batchID}/messages", rt.handler.ListMessages)
	r.Post("/api/batches/{batchID}/messages", rt.handler.PostMessage)
	r.Patch("/api/messages/{msgID}", rt.handler.EditMessage)
	r.Delete("/api/messages/{msgID}", rt.handler.DeleteMessage)
	r.Post("/api/messages/{msgID}/reactions", rt.handler.React)

	// Moderation — staff only
	r.Group(func(r chi.Router) {
		r.Use(staff)
		r.Post("/api/messages/{msgID}/resolve", rt.handler.ResolveMessage)
		r.Post("/api/messages/{msgID}/pin", rt.handler.PinMessage)
		r.Post("/api/messages/{msgID}/promote-faq", rt.handler.PromoteToFAQ)
		r.Put("/api/courses/{courseID}/faqs/order", rt.handler.ReorderFAQs)
	})

	// FAQs — any authenticated user can list
	r.Get("/api/courses/{courseID}/faqs", rt.handler.ListFAQs)

	// FAQ management — admin/instructor only
	r.Group(func(r chi.Router) {
		r.Use(adminInstructor)
		r.Post("/api/courses/{courseID}/faqs", rt.handler.CreateFAQ)
		r.Patch("/api/faqs/{faqID}", rt.handler.UpdateFAQ)
		r.Delete("/api/faqs/{faqID}", rt.handler.DeleteFAQ)
	})
}

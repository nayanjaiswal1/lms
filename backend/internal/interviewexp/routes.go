package interviewexp

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
)

// Router wires the interview-experiences domain into the main chi router.
type Router struct {
	handler *Handler
}

func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: newHandler(service, pool)}
}

// RegisterRoutes mounts interview-experiences endpoints under the caller's
// authenticated group, gated on content.interview_exp — same permission
// code the frontend nav entry checks. Unlike every other domain, reads here
// are never org-scoped (see docs/interview-experiences.md); the permission
// gate just requires the caller to be an authenticated member of some org.
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "content.interview_exp")).Group(func(r chi.Router) {
		r.Get("/api/interview-exp/posts", rt.handler.ListPosts)
		r.Post("/api/interview-exp/posts", rt.handler.CreatePost)
		r.Get("/api/interview-exp/posts/{id}", rt.handler.GetPost)
		r.Post("/api/interview-exp/posts/{id}/entries", rt.handler.CreateEntry)
		r.Post("/api/interview-exp/posts/{id}/qna", rt.handler.CreateStandaloneQna)

		r.Post("/api/interview-exp/entries/{id}/qna", rt.handler.CreateEntryQna)

		r.Patch("/api/interview-exp/qna/{id}", rt.handler.UpdateQna)
		r.Delete("/api/interview-exp/qna/{id}", rt.handler.DeleteQna)
		r.Post("/api/interview-exp/qna/{id}/comments", rt.handler.CreateComment)

		r.Patch("/api/interview-exp/comments/{id}", rt.handler.UpdateComment)
		r.Delete("/api/interview-exp/comments/{id}", rt.handler.DeleteComment)

		r.Post("/api/interview-exp/vote", rt.handler.Vote)

		r.Get("/api/interview-exp/faq", rt.handler.GetFaq)
		r.Patch("/api/interview-exp/faq/{qnaId}/progress", rt.handler.UpdateFaqStatus)
		r.Patch("/api/interview-exp/faq/{qnaId}/star", rt.handler.UpdateFaqStarred)
	})
}

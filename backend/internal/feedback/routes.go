package feedback

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Router struct {
	handler *Handler
}

func New(pool *pgxpool.Pool, mentorship MentorshipVerifier) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, mentorship)
	return &Router{handler: &Handler{service: service}}
}

// RegisterRoutes mounts the feedback API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware, so any
// authenticated org member (student/instructor/admin/mentor) can submit and
// read their own feedback — there is no extra role gate here.
func (rt *Router) RegisterRoutes(r chi.Router) {
	// Core feedback routes for courses, assessments, labs, mentors
	r.Post("/api/feedback", rt.handler.SubmitFeedback)
	r.Get("/api/feedback/{subjectType}/{subjectID}/me", rt.handler.GetMyFeedback)
	r.Get("/api/feedback/{subjectType}/{subjectID}", rt.handler.ListFeedback)

	// Experience report routes (absorbed from experience package)
	r.Post("/api/experience-reports", rt.handler.SubmitExperienceReport)
	r.Get("/api/experience-reports/{subjectType}/{subjectID}/me", rt.handler.GetMyExperienceReport)
}

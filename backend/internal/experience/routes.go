package experience

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Router struct {
	handler *Handler
}

func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: &Handler{service: service}}
}

// RegisterRoutes mounts the experience-report API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware, so any
// authenticated org member can submit and read their own reports — there is
// no extra role gate here (this is collection only; a staff-facing triage
// view over the same table is a separate follow-up).
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Post("/api/experience-reports", rt.handler.SubmitReport)
	r.Get("/api/experience-reports/{subjectType}/{subjectID}/me", rt.handler.GetMyReport)
}

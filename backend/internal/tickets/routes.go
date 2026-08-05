package tickets

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
)

// Router wires the ticket HTTP API.
type Router struct {
	handler *Handler
	Service *Service
	// Repo is exported so internal/mentoring can build its ticket lifecycle
	// (auto-create on purchase, RequestMentor, claim/hand-assign/close) on
	// top of the same conversations/messages rows this package owns, instead
	// of duplicating the CRUD.
	Repo *Repo
}

// New wires the tickets package's repo/service/handler dependency graph.
// authzSvc backs the per-kind manage/queue permission checks (support.manage,
// mentoring.assign_tickets, mentoring.view_tickets). cfg backs the
// created/reply email notifications (FrontendURL for ticket links,
// EmailFrom's domain for Message-Id threading).
func New(pool *pgxpool.Pool, authzSvc *authz.Service, cfg *config.Config) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, cfg)
	return &Router{
		handler: &Handler{service: service, authzSvc: authzSvc},
		Service: service,
		Repo:    repo,
	}
}

// RegisterRoutes mounts the ticket API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	// Raise a ticket, list your own — any authenticated org member.
	r.Post("/api/tickets", rt.handler.CreateSupportTicket)
	r.Get("/api/tickets/me", rt.handler.ListMine)

	// Staff/mentor queue — gated per-kind (?kind=support|mentorship) by
	// QueuePermission, checked inside the handler since it depends on a
	// query param rather than a static route.
	r.Get("/api/tickets", rt.handler.ListQueue)

	// Ticket detail + reply thread — any authenticated org member; the
	// service verifies the caller is the ticket's own requester, its current
	// assignee, or holds its kind's manage permission.
	r.Get("/api/tickets/{ticketID}", rt.handler.Get)
	r.Get("/api/tickets/{ticketID}/messages", rt.handler.ListMessages)
	r.Post("/api/tickets/{ticketID}/messages", rt.handler.SendMessage)

	// Status/properties — support tickets only (mentorship tickets change
	// status through claim/assign/close/change-request-approval instead);
	// gated by support.manage, checked inside the handler.
	r.Patch("/api/tickets/{ticketID}/status", rt.handler.SetStatus)
	r.Patch("/api/tickets/{ticketID}/properties", rt.handler.SetProperties)
}

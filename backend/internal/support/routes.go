package support

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
)

// Router wires the support-ticket HTTP API.
type Router struct {
	handler *Handler
	Service *Service
}

// New wires the support package's repo/service/handler dependency graph.
// authzSvc backs the support.manage permission check, both for gating the
// staff queue route group and for the per-request ownership check on the
// shared ticket/thread endpoints (a ticket's own reporter or anyone holding
// support.manage may view/reply to it).
func New(pool *pgxpool.Pool, authzSvc *authz.Service) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: &Handler{service: service, authzSvc: authzSvc}, Service: service}
}

// RegisterRoutes mounts the support API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	manage := authz.RequirePermission(rt.handler.authzSvc, PermissionManage)

	// Raise a ticket, list your own — any authenticated org member.
	r.Post("/api/support/tickets", rt.handler.CreateTicket)
	r.Get("/api/support/tickets/me", rt.handler.ListMyTickets)

	// Staff queue — every ticket in the org, gated by support.manage.
	r.Group(func(r chi.Router) {
		r.Use(manage)
		r.Get("/api/support/tickets", rt.handler.ListTickets)
		r.Patch("/api/support/tickets/{ticketID}/status", rt.handler.UpdateStatus)
		r.Patch("/api/support/tickets/{ticketID}/properties", rt.handler.UpdateProperties)
	})

	// Ticket detail + reply thread — any authenticated org member; the
	// service verifies the caller is the ticket's own reporter or holds
	// support.manage, so both a student checking their own ticket and staff
	// working the queue land on the same routes.
	r.Get("/api/support/tickets/{ticketID}", rt.handler.GetTicket)
	r.Get("/api/support/tickets/{ticketID}/messages", rt.handler.ListMessages)
	r.Post("/api/support/tickets/{ticketID}/messages", rt.handler.SendMessage)
}

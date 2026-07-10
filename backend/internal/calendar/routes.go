package calendar

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
)

// Router mounts the calendar HTTP API.
type Router struct {
	handler *Handler
}

// New wires the calendar package's repo/service/handler dependency graph.
// authzSvc backs the calendar.events.manage permission override inside
// Service (an org admin holding it can view/mutate any event regardless of
// attendee role).
func New(pool *pgxpool.Pool, authzSvc *authz.Service, cfg *config.Config) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, authzSvc)
	return &Router{handler: &Handler{service: service, cfg: cfg}}
}

// RegisterRoutes mounts the authenticated calendar API onto r. Caller has
// already applied RequireAuth + RequireCSRF. Every mutation here is gated
// inline by Service (owner/editor attendee or calendar.events.manage), not
// by route-level RBAC middleware — a plain org member with no special
// permission still needs to create/edit their own events.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/api/calendar/events", rt.handler.ListEvents)
	r.Post("/api/calendar/events", rt.handler.CreateEvent)
	r.Get("/api/calendar/events/{eventID}", rt.handler.GetEvent)
	r.Patch("/api/calendar/events/{eventID}", rt.handler.UpdateEvent)
	r.Delete("/api/calendar/events/{eventID}", rt.handler.DeleteEvent)
	r.Patch("/api/calendar/events/{eventID}/notes", rt.handler.UpdateNotes)
	r.Patch("/api/calendar/events/{eventID}/complete", rt.handler.SetCompleted)
	r.Post("/api/calendar/events/{eventID}/rsvp", rt.handler.RSVP)
	r.Post("/api/calendar/events/{eventID}/invite", rt.handler.InviteExternal)
	r.Post("/api/calendar/events.ics/token", rt.handler.MintFeedToken)
}

// RegisterPublicRoutes mounts routes that do not require authentication: the
// invite-accept link (proof of access is the token itself) and the personal
// ICS feed (external calendar clients cannot carry session cookies; proof of
// access is the ?token= query param).
func (rt *Router) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/calendar/invites/{token}/accept", rt.handler.AcceptInvite)
	r.Get("/api/calendar/events.ics", rt.handler.EventsICS)
}

package sessions

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/payments"
)

// Router mounts the session-booking HTTP API. Service is exported so the
// mentoring package's single payment-webhook endpoint can hand pack
// purchases here (see mentoring.PackConfirmer) — same pattern
// mentoringRouter.Service already uses for courses.
type Router struct {
	handler *Handler
	Service *Service
}

// New wires the sessions package. cal is the shared *calendar.Service, so a
// booked session is projected onto the org calendar through exactly the code
// path a hand-created event uses — including its ICS feed and attendee RSVP.
func New(pool *pgxpool.Pool, cal CalendarProjector, providers *payments.Registry, cfg *config.Config) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, cal, providers, cfg)
	return &Router{handler: &Handler{service: service}, Service: service}
}

// RegisterRoutes mounts the session-booking API. Caller has already applied
// RequireAuth + RequireCSRF.
//
// Note what is NOT role-gated here: booking, cancelling, rescheduling, and
// rating a session are all things a plain learner does for their own
// sessions, so authorization is per-row inside Service (am I this session's
// student or mentor?) rather than per-route. Only the org-admin surface and
// the mentor's own availability get middleware.
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	manageBooking := authz.RequirePermission(authzSvc, PermissionManageBooking)

	// Booking policy + the caller's balance — read by every booking screen.
	r.Get("/api/session-booking/config", rt.handler.GetConfig)

	// Mentor availability. The service checks the caller actually holds the
	// mentor role before publishing, so no route-level role guard is needed
	// (and a route guard would 403 an instructor who is also a mentor).
	r.Get("/api/session-booking/availability/me", rt.handler.GetMyAvailability)
	r.Put("/api/session-booking/availability/me", rt.handler.ReplaceMyAvailability)
	r.Post("/api/session-booking/availability/me/exceptions", rt.handler.AddException)
	r.Delete("/api/session-booking/availability/me/exceptions/{exceptionID}", rt.handler.DeleteException)

	// The bookable grid for one mentor — free and taken windows both.
	r.Get("/api/mentors/{mentorID}/slots", rt.handler.GetSlots)

	// Sessions.
	r.Post("/api/mentor-sessions", rt.handler.Book)
	r.Get("/api/mentor-sessions", rt.handler.ListSessions)
	r.Get("/api/mentor-sessions/{sessionID}", rt.handler.GetSession)
	r.Post("/api/mentor-sessions/{sessionID}/cancel", rt.handler.Cancel)
	r.Post("/api/mentor-sessions/{sessionID}/reschedule", rt.handler.Reschedule)
	r.Post("/api/mentor-sessions/{sessionID}/outcome", rt.handler.SetOutcome)
	r.Post("/api/mentor-sessions/{sessionID}/feedback", rt.handler.SubmitFeedback)
	r.Put("/api/mentor-sessions/{sessionID}/notes", rt.handler.SaveNotes)

	// A mentor's view of one mentee's whole history with them.
	r.Get("/api/session-booking/mentees/{studentID}", rt.handler.GetMenteeProgress)

	// Credits — read your own balance, browse and buy packs.
	r.Get("/api/session-booking/credits", rt.handler.GetCredits)
	r.Get("/api/session-booking/packs", rt.handler.ListPacks)
	r.Post("/api/session-booking/packs/{packID}/checkout", rt.handler.BuyPack)

	// Org-admin surface.
	r.Group(func(r chi.Router) {
		r.Use(manageBooking)
		r.Patch("/api/session-booking/config", rt.handler.UpdateConfig)
		r.Post("/api/session-booking/packs", rt.handler.SavePack)
		r.Patch("/api/session-booking/packs/{packID}", rt.handler.SavePack)
		r.Post("/api/session-booking/credits/grant", rt.handler.GrantCredits)
		r.Post("/api/batches/{batchID}/sessions", rt.handler.BookForBatch)
	})
}

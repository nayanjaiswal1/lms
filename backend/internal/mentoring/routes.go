package mentoring

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/payments"
)

// Router mounts the mentoring HTTP API. Service is exported so the courses
// package's purchase handler (which must not import this package directly,
// see courses.CoursePurchaser) can be handed the concrete *Service by
// backend/internal/api/router.go at construction time.
type Router struct {
	handler *Handler
	Service *Service
	pool    *pgxpool.Pool
}

// New wires the mentoring package's repo/service/handler dependency graph.
// coursesRepo is used only for its CreateEnrollmentTx capability inside
// Service.confirmPurchase, so the paid-course enrollment insert stays
// identical to the one courses.Repo.CreateEnrollment issues for free
// enrollment. authzSvc backs the mentoring.assign_tickets /
// mentoring.manage_reports permission checks. providers is the payments
// registry built by payments.FromConfig; couponsSvc backs coupon
// validation/redemption during checkout. packs receives payment webhooks
// whose provider_ref belongs to a mentor-session credit pack rather than a
// course — see PackConfirmer; it may be nil.
func New(pool *pgxpool.Pool, providers *payments.Registry, couponsSvc *coupons.Service, coursesRepo *courses.Repo, packs PackConfirmer, authzSvc *authz.Service, cfg *config.Config) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, providers, couponsSvc, coursesRepo, packs, cfg)
	return &Router{
		handler: &Handler{service: service, authzSvc: authzSvc},
		Service: service,
		pool:    pool,
	}
}

// RegisterPublicRoutes mounts the payment-gateway webhook receiver — public
// because the gateway itself is the caller (authenticated by its own
// signature scheme, not a session cookie), outside the RequireAuth/
// RequireCSRF group RegisterRoutes assumes.
func (rt *Router) RegisterPublicRoutes(r chi.Router) {
	r.Post("/api/payments/webhooks/{provider}", rt.handler.Webhook)
}

// RegisterRoutes mounts the mentoring API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	mentorOrStaff := middleware.RequireOrgRole(rt.pool, middleware.RoleMentor, middleware.RoleInstructor, middleware.RoleAdmin)
	mentorOnly := middleware.RequireOrgRole(rt.pool, middleware.RoleMentor)
	assignTickets := authz.RequirePermission(rt.handler.authzSvc, PermissionAssignTickets)
	manageReports := authz.RequirePermission(rt.handler.authzSvc, PermissionManageReports)
	verifyMentors := authz.RequirePermission(rt.handler.authzSvc, PermissionVerifyMentors)

	// Ticket queue — mentor/instructor/admin can view.
	r.Group(func(r chi.Router) {
		r.Use(mentorOrStaff)
		r.Get("/api/mentor-tickets", rt.handler.ListTickets)
	})

	// A student's own tickets — any authenticated org member.
	r.Get("/api/mentor-tickets/me", rt.handler.ListMyTickets)

	// Student-initiated mentor request — any authenticated org member; the
	// service verifies course enrollment and dedupes against an existing
	// active ticket.
	r.Post("/api/mentor-tickets/request", rt.handler.RequestMentor)

	// Self-claim — any mentor-role org member.
	r.Group(func(r chi.Router) {
		r.Use(mentorOnly)
		r.Post("/api/mentor-tickets/{ticketID}/claim", rt.handler.ClaimTicket)
	})

	// Hand-assign — gated by the DB-configurable mentoring.assign_tickets
	// permission (default: instructor + tenant_admin) rather than a role.
	r.Group(func(r chi.Router) {
		r.Use(assignTickets)
		r.Post("/api/mentor-tickets/{ticketID}/assign", rt.handler.AssignTicket)
	})

	// Close — either the assigned mentor OR mentoring.assign_tickets; that
	// either/or condition is checked inline in the handler, not via middleware.
	r.Post("/api/mentor-tickets/{ticketID}/close", rt.handler.CloseTicket)

	// Student-initiated mentor change request — any authenticated org member;
	// the service verifies the caller owns the ticket.
	r.Post("/api/mentor-tickets/{ticketID}/change-request", rt.handler.RequestMentorChange)

	// 1:1 chat thread — any authenticated org member; the service verifies
	// the caller is the ticket's student or its currently assigned mentor.
	r.Get("/api/mentor-tickets/{ticketID}/messages", rt.handler.ListChatMessages)
	r.Post("/api/mentor-tickets/{ticketID}/messages", rt.handler.SendChatMessage)

	// Ticket status + mentor-assignment history — same access rule as chat.
	r.Get("/api/mentor-tickets/{ticketID}/history", rt.handler.GetTicketHistory)

	// Change-request review — gated by mentoring.assign_tickets, same staff
	// who can hand-assign a ticket in the first place.
	r.Group(func(r chi.Router) {
		r.Use(assignTickets)
		r.Get("/api/mentor-change-requests", rt.handler.ListChangeRequests)
		r.Post("/api/mentor-change-requests/{requestID}/approve", rt.handler.ApproveChangeRequest)
		r.Post("/api/mentor-change-requests/{requestID}/deny", rt.handler.DenyChangeRequest)

		// Ticket detail — the single-page lifecycle view (assignments +
		// change requests + reports) for staff. Same permission group as
		// change-request review since it's the same "manages the ticket
		// queue" audience.
		r.Get("/api/mentor-tickets/{ticketID}/detail", rt.handler.GetTicketDetail)
	})

	// Directory + reporting — any authenticated org member.
	r.Get("/api/mentors", rt.handler.ListMentorDirectory)
	r.Get("/api/mentors/{mentorID}/profile", rt.handler.GetMentorProfile)
	r.Post("/api/mentors/{mentorID}/report", rt.handler.ReportMentor)

	// Verified-expert badge toggle — gated by the DB-configurable
	// mentoring.verify_mentors permission (default: instructor + tenant_admin).
	r.Group(func(r chi.Router) {
		r.Use(verifyMentors)
		r.Patch("/api/mentors/{mentorID}/verify", rt.handler.VerifyMentor)
	})

	// Ticket-independent mentor DMs — any authenticated org member; the
	// service verifies the caller is the conversation's student or mentor,
	// and that a new conversation's target actually holds the mentor role.
	r.Post("/api/mentor-conversations", rt.handler.CreateOrGetConversation)
	r.Get("/api/mentor-conversations", rt.handler.ListMyConversations)
	r.Get("/api/mentor-conversations/{conversationID}/messages", rt.handler.ListConversationMessages)
	r.Post("/api/mentor-conversations/{conversationID}/messages", rt.handler.SendConversationMessage)

	// Report moderation — gated by mentoring.manage_reports.
	r.Group(func(r chi.Router) {
		r.Use(manageReports)
		r.Get("/api/mentor-reports", rt.handler.ListReports)
		r.Patch("/api/mentor-reports/{reportID}", rt.handler.ResolveReport)
	})
}

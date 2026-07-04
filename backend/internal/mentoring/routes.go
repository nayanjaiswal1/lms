package mentoring

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/payments"
)

// Router mounts the mentoring HTTP API. Service is exported so the courses
// package's purchase handler (which must not import this package directly,
// see courses.MentorTicketOpener) can be handed the concrete *Service by
// backend/internal/api/router.go at construction time.
type Router struct {
	handler *Handler
	Service *Service
}

// New wires the mentoring package's repo/service/handler dependency graph.
// coursesRepo is used only for its CreateEnrollmentTx capability inside
// Service.PurchaseCourse, so the paid-course enrollment insert stays
// identical to the one courses.Repo.CreateEnrollment issues for free
// enrollment. authzSvc backs the mentoring.assign_tickets /
// mentoring.manage_reports permission checks.
func New(pool *pgxpool.Pool, paymentsProvider payments.Provider, coursesRepo *courses.Repo, authzSvc *authz.Service) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, paymentsProvider, coursesRepo)
	return &Router{
		handler: &Handler{service: service, authzSvc: authzSvc},
		Service: service,
	}
}

// RegisterRoutes mounts the mentoring API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	mentorOrStaff := middleware.RequireOrgRole(middleware.RoleMentor, middleware.RoleInstructor, middleware.RoleAdmin)
	mentorOnly := middleware.RequireOrgRole(middleware.RoleMentor)
	assignTickets := authz.RequirePermission(rt.handler.authzSvc, PermissionAssignTickets)
	manageReports := authz.RequirePermission(rt.handler.authzSvc, PermissionManageReports)

	// Ticket queue — mentor/instructor/admin can view.
	r.Group(func(r chi.Router) {
		r.Use(mentorOrStaff)
		r.Get("/api/mentor-tickets", rt.handler.ListTickets)
	})

	// A student's own tickets — any authenticated org member.
	r.Get("/api/mentor-tickets/me", rt.handler.ListMyTickets)

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

	// Change-request review — gated by mentoring.assign_tickets, same staff
	// who can hand-assign a ticket in the first place.
	r.Group(func(r chi.Router) {
		r.Use(assignTickets)
		r.Get("/api/mentor-change-requests", rt.handler.ListChangeRequests)
		r.Post("/api/mentor-change-requests/{requestID}/approve", rt.handler.ApproveChangeRequest)
		r.Post("/api/mentor-change-requests/{requestID}/deny", rt.handler.DenyChangeRequest)
	})

	// Directory + reporting — any authenticated org member.
	r.Get("/api/mentors", rt.handler.ListMentorDirectory)
	r.Post("/api/mentors/{mentorID}/report", rt.handler.ReportMentor)

	// Report moderation — gated by mentoring.manage_reports.
	r.Group(func(r chi.Router) {
		r.Use(manageReports)
		r.Get("/api/mentor-reports", rt.handler.ListReports)
		r.Patch("/api/mentor-reports/{reportID}", rt.handler.ResolveReport)
	})
}

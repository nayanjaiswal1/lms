package certificates

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/middleware"
)

// Router wires the certificates domain into the main chi router.
type Router struct {
	handler *Handler
	pool    *pgxpool.Pool
}

// New builds the certificates Router. coursesRepo backs the enrollment/
// completion gate and course-existence check; executor grades coding
// questions via the same Piston/Judge0 path assessment attempts use;
// mentorAuth/purchases back the mentor-manual and threshold-auto-issue
// paths respectively (both satisfied by *mentoring.Service — see
// backend/internal/api/router.go).
func New(pool *pgxpool.Pool, coursesRepo *courses.Repo, executor assessment.CodeExecutor, mentorAuth MentorAuthChecker, purchases PurchaseChecker) *Router {
	repo := NewRepo(pool)
	service := NewService(repo, coursesRepo, executor, mentorAuth, purchases)
	return &Router{handler: newHandler(service, pool), pool: pool}
}

// RegisterRoutes mounts the authenticated routes under the caller's group.
// Authoring is role-gated the same way courses' own module CRUD is (courses
// doesn't use permission codes for authoring); student-facing reads/writes
// are gated on content.certificates — the same permission code the
// frontend's nav entry and <AccessGate> already check.
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	instructor := middleware.RequireOrgRole(rt.pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor)
	r.With(instructor).Group(func(r chi.Router) {
		r.Get("/api/courses/{courseID}/final-test/edit", rt.handler.GetFinalTestForEdit)
		r.Put("/api/courses/{courseID}/final-test", rt.handler.UpsertFinalTest)
		r.Get("/api/courses/{courseID}/certificate-threshold", rt.handler.GetCertificateThreshold)
		r.Put("/api/courses/{courseID}/certificate-threshold", rt.handler.UpsertCertificateThreshold)
	})

	// Manual award — a mentor may only issue for their own assigned student
	// (enforced in the service, since middleware can't see the mentor/student
	// pairing); instructor/admin may issue for anyone enrolled.
	mentorOrStaff := middleware.RequireOrgRole(rt.pool, middleware.RoleMentor, middleware.RoleInstructor, middleware.RoleAdmin, middleware.RoleOwner)
	r.With(mentorOrStaff).Group(func(r chi.Router) {
		r.Post("/api/courses/{courseID}/certificates/issue", rt.handler.IssueCertificate)
	})

	r.With(authz.RequirePermission(authzSvc, "content.certificates")).Group(func(r chi.Router) {
		r.Get("/api/courses/{courseID}/final-test", rt.handler.GetFinalTestForStudent)
		r.Post("/api/courses/{courseID}/final-test/attempt", rt.handler.SubmitAttempt)
		r.Get("/api/certificates/me", rt.handler.ListMyCertificates)
		r.Get("/api/courses/{courseID}/certificates/me", rt.handler.GetMyCertificateForCourse)
		r.Post("/api/courses/{courseID}/certificates/check-threshold", rt.handler.CheckThresholdCertificate)
	})
}

// RegisterPublicRoutes mounts the no-auth certificate verification endpoint.
func (rt *Router) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/certificates/{uuid}", rt.handler.VerifyCertificate)
}

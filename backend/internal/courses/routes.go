package courses

import (
	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/middleware"
)

// RegisterRoutes mounts the courses API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (h *Handler) RegisterRoutes(r chi.Router) {
	instructor := middleware.RequireOrgRole(h.repo.Pool(), middleware.RoleAdmin, middleware.RoleInstructor)
	staff := middleware.RequireOrgRole(h.repo.Pool(), middleware.RoleAdmin, middleware.RoleInstructor, middleware.RoleMentor)

	// ─── Instructor: course/section/module authoring ──────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(instructor)

		r.Post("/api/courses", h.CreateCourse)
		r.Patch("/api/courses/{courseID}", h.UpdateCourse)
		r.Post("/api/courses/{courseID}/publish", h.PublishCourse)
		r.Delete("/api/courses/{courseID}", h.DeleteCourse)
		r.Post("/api/courses/{courseID}/fork", h.ForkCourse)

		r.Post("/api/courses/{courseID}/sections", h.CreateSection)
		r.Put("/api/courses/{courseID}/sections/order", h.ReorderSections)
		r.Patch("/api/sections/{sectionID}", h.UpdateSection)
		r.Delete("/api/sections/{sectionID}", h.DeleteSection)

		r.Post("/api/sections/{sectionID}/modules", h.CreateModule)
		r.Put("/api/sections/{sectionID}/modules/order", h.ReorderModules)
		r.Patch("/api/modules/{moduleID}", h.UpdateModule)
		r.Delete("/api/modules/{moduleID}", h.DeleteModule)

		r.Post("/api/upload", h.UploadAsset)
		r.Post("/api/upload/course-asset", h.GetUploadURL)
		r.Post("/api/courses/generate-outline", h.GenerateOutline)
	})

	// ─── Staff + Mentor: progress overview ────────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(staff)
		r.Get("/api/courses/{courseID}/progress", h.GetAllProgress)
	})

	// ─── Instructor: content-proposal review queue ────────────────────────────
	// A proposal always targets an org course, so this reuses the same
	// instructor/admin gate as authoring that course directly — approving a
	// proposal IS authoring the course, just sourced from a student's work.
	r.Group(func(r chi.Router) {
		r.Use(instructor)
		r.Get("/api/courses/{courseID}/proposals", h.ListProposals)
		r.Post("/api/proposals/{proposalID}/approve", h.ApproveProposal)
		r.Post("/api/proposals/{proposalID}/reject", h.RejectProposal)
	})

	// ─── All authenticated users: self-courses (own private course tree) ─────
	// No RequireOrgRole gate — every student may create/edit their own
	// private courses; ownership (not org role) is what CreateSelfCourse/
	// ForkSelfCourseFromOrgCourse/AddSelfCourseModule/UpdateSelfCourseModule
	// enforce.
	r.Get("/api/learning-context", h.GetLearningContext)
	r.Post("/api/self-courses", h.CreateSelfCourse)
	r.Post("/api/self-courses/fork", h.ForkSelfCourse)
	r.Post("/api/self-courses/{courseID}/modules", h.AddSelfCourseModule)
	r.Patch("/api/self-course-modules/{moduleID}", h.UpdateSelfCourseModule)
	r.Post("/api/courses/{courseID}/proposals", h.ProposeModule)

	// ─── All authenticated users: browse, enroll, learn ──────────────────────
	r.Get("/api/courses", h.ListCourses)
	r.Get("/api/courses/random-topic", h.GetRandomTopic)
	r.Get("/api/courses/{courseID}", h.GetCourse)
	r.Post("/api/courses/{courseID}/enroll", h.Enroll)
	r.Post("/api/courses/{courseID}/checkout", h.StartCheckout)
	r.Get("/api/courses/{courseID}/purchase-status", h.PurchaseStatus)
	r.Post("/api/courses/{courseID}/coupon/preview", h.PreviewCoupon)
	r.Get("/api/enrollments/me", h.MyEnrollments)
	r.Post("/api/courses/{courseID}/reviews", h.SubmitReview)
	r.Get("/api/courses/{courseID}/reviews/me", h.GetMyReview)
	r.Get("/api/modules/{moduleID}", h.GetModuleContent)
	r.Patch("/api/modules/{moduleID}/progress", h.UpdateProgress)
	r.Post("/api/modules/{moduleID}/check-attempts", h.RecordCheckAttempt)
	r.Get("/api/modules/{moduleID}/check-attempts/me", h.GetMyCheckProgress)
	r.Post("/api/modules/{moduleID}/reflection", h.SubmitReflection)
	r.Get("/api/modules/{moduleID}/reflection/me", h.GetMyReflection)
	r.Put("/api/modules/{moduleID}/notes", h.SaveLessonNote)
	r.Get("/api/modules/{moduleID}/notes/me", h.GetMyLessonNote)
	r.Get("/api/courses/{courseID}/progress/me", h.GetMyProgress)
}

// RegisterPublicRoutes mounts routes that require no authentication. The
// handler only returns published courses explicitly opted in via is_public.
func (h *Handler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/public/courses", h.ListPublicCourses)
}

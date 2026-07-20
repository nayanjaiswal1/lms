package courses

import (
	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/middleware"
)

// RegisterRoutes mounts the courses API onto the given router.
// Caller has already applied RequireAuth + RequireCSRF middleware.
func (h *Handler) RegisterRoutes(r chi.Router) {
	instructor := middleware.RequireOrgRole(middleware.RoleAdmin, middleware.RoleInstructor)
	staff := middleware.RequireOrgRole(middleware.RoleAdmin, middleware.RoleInstructor, middleware.RoleMentor)

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

	// ─── All authenticated users: browse, enroll, learn ──────────────────────
	r.Get("/api/courses", h.ListCourses)
	r.Get("/api/courses/{courseID}", h.GetCourse)
	r.Post("/api/courses/{courseID}/enroll", h.Enroll)
	r.Post("/api/courses/{courseID}/purchase", h.Purchase)
	r.Get("/api/enrollments/me", h.MyEnrollments)
	r.Post("/api/courses/{courseID}/reviews", h.SubmitReview)
	r.Get("/api/courses/{courseID}/reviews/me", h.GetMyReview)
	r.Get("/api/modules/{moduleID}", h.GetModuleContent)
	r.Patch("/api/modules/{moduleID}/progress", h.UpdateProgress)
	r.Post("/api/modules/{moduleID}/check-attempts", h.RecordCheckAttempt)
	r.Get("/api/modules/{moduleID}/check-attempts/me", h.GetMyCheckProgress)
	r.Post("/api/modules/{moduleID}/reflection", h.SubmitReflection)
	r.Get("/api/modules/{moduleID}/reflection/me", h.GetMyReflection)
	r.Get("/api/courses/{courseID}/progress/me", h.GetMyProgress)
}

// RegisterPublicRoutes mounts routes that require no authentication. The
// handler only returns published courses explicitly opted in via is_public.
func (h *Handler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/public/courses", h.ListPublicCourses)
}

package assessment

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/rewards"
)

// New builds the fully-wired assessment handler from the shared pool, config, and jobs registry.
// jobRegistry is used by SubmitAttempt to enqueue eval.subjective jobs via the Job Management System.
func New(pool *pgxpool.Pool, cfg *config.Config, jobRegistry *jobs.Registry, rewardsSvc *rewards.Service) *Handler {
	repo := NewRepo(pool)
	exec := NewExecutor(cfg)
	service := NewService(repo, exec, cfg)
	return NewHandler(repo, service, pool, jobRegistry, rewardsSvc)
}

// RegisterRoutes mounts the assessment API onto the given router. The caller is
// responsible for applying RequireAuth + RequireCSRF before this; here we add
// per-group org-role guards on top.
//
// Staff group  — admin / instructor / mentor: authoring, assignment, analytics.
// Student group — any authenticated org member: take tests, view own results.
func (h *Handler) RegisterRoutes(r chi.Router) {
	staff := middleware.RequireOrgRole(middleware.RoleAdmin, middleware.RoleInstructor, middleware.RoleMentor)

	// ─── Staff: management ────────────────────────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(staff)

		// Question categories
		r.Post("/api/categories", h.CreateCategory)
		r.Get("/api/categories", h.ListCategories)

		// Question bank
		r.Post("/api/questions", h.CreateQuestion)
		r.Get("/api/questions", h.ListQuestions)
		r.Get("/api/questions/{questionID}", h.GetQuestion)
		r.Patch("/api/questions/{questionID}", h.UpdateQuestion)
		r.Delete("/api/questions/{questionID}", h.ArchiveQuestion)

		// Batches
		r.Post("/api/batches", h.CreateBatch)
		r.Get("/api/batches", h.ListBatches)
		r.Get("/api/batches/{batchID}", h.GetBatch)
		r.Post("/api/batches/{batchID}/members", h.AddBatchMembers)
		r.Delete("/api/batches/{batchID}/members/{userID}", h.RemoveBatchMember)

		// Batch mentors
		r.Post("/api/batches/{batchID}/mentors", h.AddBatchMentor)
		r.Delete("/api/batches/{batchID}/mentors/{userID}", h.RemoveBatchMentor)
		r.Get("/api/batches/{batchID}/mentors", h.ListBatchMentors)

		// Batch courses
		r.Post("/api/batches/{batchID}/courses", h.AssignBatchCourse)
		r.Delete("/api/batches/{batchID}/courses/{courseID}", h.UnassignBatchCourse)
		r.Get("/api/batches/{batchID}/courses", h.ListBatchCourses)

		// Batch invitations
		r.Post("/api/batches/{batchID}/invite", h.BulkInvite)
		r.Get("/api/batches/{batchID}/invitations", h.ListInvitations)
		r.Delete("/api/batches/{batchID}/invitations/{invID}", h.RevokeInvitation)
		r.Post("/api/batches/{batchID}/invitations/{invID}/resend", h.ResendInvitation)

		// Batch progress
		r.Get("/api/batches/{batchID}/progress", h.GetBatchProgress)

		// Assessments
		r.Post("/api/assessments", h.CreateAssessment)
		r.Get("/api/assessments", h.ListAssessments)
		r.Get("/api/assessments/{assessmentID}", h.GetAssessment)
		r.Patch("/api/assessments/{assessmentID}", h.UpdateAssessment)
		r.Post("/api/assessments/{assessmentID}/questions", h.AddAssessmentQuestion)
		r.Delete("/api/assessments/{assessmentID}/questions/{aqID}", h.RemoveAssessmentQuestion)
		r.Post("/api/assessments/{assessmentID}/publish", h.PublishAssessment)
		r.Post("/api/assessments/{assessmentID}/status", h.SetAssessmentStatus)

		// Assignment
		r.Post("/api/assessments/{assessmentID}/assignments", h.CreateAssignment)
		r.Get("/api/assessments/{assessmentID}/assignments", h.ListAssignments)
		r.Delete("/api/assessments/{assessmentID}/assignments/{assignmentID}", h.DeleteAssignment)

		// Analytics + results review
		r.Get("/api/assessments/{assessmentID}/analytics", h.AssessmentAnalytics)
		r.Get("/api/assessments/{assessmentID}/attempts", h.ListAssessmentAttempts)
		r.Get("/api/assessments/{assessmentID}/candidates", h.GetPublicCandidates)
		r.Get("/api/attempts/{attemptID}/proctoring", h.AttemptProctoringLog)
		r.Get("/api/analytics/overview", h.OrgAnalytics)

		// Interview evaluation — staff review queue and queue health
		r.Get("/api/interview/review-queue", h.HandleReviewQueue)
		r.Get("/health/eval-queue", h.HandleEvalQueueHealth)
	})

	// ─── Student: take tests ──────────────────────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Get("/api/my/assessments", h.ListMyAssessments)
		r.Get("/api/my/analytics", h.MyAnalytics)

		// Invitation accept/decline — any authenticated user (students accepting
		// batch invitations must reach this endpoint before they are org members).
		r.Post("/api/invitations/accept", h.AcceptInvitation)
		r.Post("/api/invitations/decline", h.DeclineInvitation)

		r.Post("/api/assessments/{assessmentID}/attempts", h.StartAttempt)
		r.Get("/api/attempts/{attemptID}", h.ResumeAttempt)
		r.Put("/api/attempts/{attemptID}/answers", h.SaveAnswer)
		r.Post("/api/attempts/{attemptID}/events", h.RecordEvent)
		r.Post("/api/attempts/{attemptID}/submit", h.SubmitAttempt)
		r.Get("/api/attempts/{attemptID}/result", h.GetAttemptResult)

		// Interview evaluation — students poll for their own eval status and results
		r.Get("/api/attempts/{attemptID}/evaluation/status", h.HandleGetEvaluationStatus)
		r.Get("/api/attempts/{attemptID}/evaluation", h.HandleGetEvaluation)
		r.Get("/api/attempts/{attemptID}/compare/{otherID}", h.HandleCompareEvaluations)
		r.Get("/api/interview/progress", h.HandleStudentProgress)
		r.Get("/api/interview/skills", h.HandleSkillTrends)
	})
}

// RegisterPublicRoutes mounts routes that do not require authentication.
func (h *Handler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/invitations/preview/{token}", h.PreviewInvitation)

	// Hiring / public assessment routes — no auth, keyed by short_code.
	r.Get("/api/p/{code}", h.GetPublicTest)
	r.Post("/api/p/{code}/start", h.StartPublicAttempt)
	r.Post("/api/p/{code}/submit/{token}", h.SubmitPublicAttempt)
	r.Get("/api/p/{code}/result/{token}", h.GetPublicResult)
}

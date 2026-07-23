package assessment

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/rewards"
	"github.com/mindforge/backend/internal/storage"
)

// New builds the fully-wired assessment handler from the shared pool, config, and jobs registry.
// jobRegistry is used by SubmitAttempt to enqueue eval.subjective jobs via the Job Management System.
// coursesSvc lets a passed assessment complete the course module that embeds it.
// store backs batch cover-image uploads.
// sandboxRuntime is the same labs.ContainerRuntime the labs domain uses (Docker or
// Kubernetes, chosen once at startup — see internal/api/router.go); it grades
// "sandbox" runtime coding questions (real FastAPI/React execution) by running
// them in the same container infrastructure labs already uses. May be nil in
// deploys with no container runtime configured — sandbox questions then grade
// as pending manual review, same as an unconfigured Piston/Judge0 executor.
func New(pool *pgxpool.Pool, cfg *config.Config, jobRegistry *jobs.Registry, rewardsSvc *rewards.Service, coursesSvc *courses.Service, store storage.StorageClient, sandboxRuntime SandboxRuntime) *Handler {
	repo := NewRepo(pool)
	exec := NewExecutor(cfg)
	sandboxExec := NewSandboxExecutor(sandboxRuntime)
	service := NewService(repo, exec, sandboxExec, cfg)
	return NewHandler(repo, service, pool, jobRegistry, rewardsSvc, coursesSvc, store)
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
		r.Patch("/api/batches/{batchID}", h.UpdateBatch)
		r.Post("/api/batches/{batchID}/members", h.AddBatchMembers)
		r.Delete("/api/batches/{batchID}/members/{userID}", h.RemoveBatchMember)
		r.Post("/api/batches/{batchID}/image", h.UploadBatchImage)
		r.Delete("/api/batches/{batchID}/image", h.DeleteBatchImage)

		// Cohort groups (optional hierarchy above batches, e.g. Class/Section)
		r.Post("/api/cohort-groups", h.CreateCohortGroup)
		r.Get("/api/cohort-groups", h.ListCohortGroups)
		r.Get("/api/cohort-groups/{groupID}", h.GetCohortGroup)
		r.Patch("/api/cohort-groups/{groupID}", h.UpdateCohortGroup)
		r.Delete("/api/cohort-groups/{groupID}", h.ArchiveCohortGroup)
		r.Put("/api/batches/{batchID}/cohort-group", h.MoveBatchToGroup)

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

		// Bulk student import via Excel
		r.Post("/api/batches/{batchID}/import/parse", h.HandleImportParse)
		r.Post("/api/batches/{batchID}/import/validate", h.HandleImportValidate)
		r.Post("/api/batches/{batchID}/import/confirm", h.HandleImportConfirm)
		r.Get("/api/batches/{batchID}/import/report", h.HandleImportReport)

		// Batch progress
		r.Get("/api/batches/{batchID}/progress", h.GetBatchProgress)
		r.Get("/api/batches/{batchID}/analytics", h.GetBatchAnalytics)

		// Classroom Test Assessment Engine — manual offline test scores
		r.Post("/api/batches/{batchID}/offline-tests", h.CreateOfflineTestScores)
		r.Get("/api/batches/{batchID}/offline-tests", h.ListOfflineTests)
		r.Get("/api/batches/{batchID}/offline-tests/{testID}", h.GetOfflineTest)
		r.Patch("/api/batches/{batchID}/offline-tests/{testID}/scores/{userID}", h.UpdateOfflineTestScore)

		// Assessments
		r.Post("/api/assessments", h.CreateAssessment)
		r.Get("/api/assessments", h.ListAssessments)
		r.Get("/api/assessments/{assessmentID}", h.GetAssessment)
		r.Patch("/api/assessments/{assessmentID}", h.UpdateAssessment)
		r.Post("/api/assessments/{assessmentID}/questions", h.AddAssessmentQuestion)
		r.Post("/api/assessments/{assessmentID}/questions/auto-select", h.AutoSelectAssessmentQuestions)
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
		r.Patch("/api/assessments/{assessmentID}/candidates/{candidateID}/override", h.OverridePublicCandidateScore)
		r.Get("/api/attempts/{attemptID}/proctoring", h.AttemptProctoringLog)
		r.Patch("/api/attempts/{attemptID}/answers/{answerID}/override", h.OverrideAnswerScore)
		r.Get("/api/analytics/overview", h.OrgAnalytics)

		// Interview evaluation — staff review queue and queue health
		r.Get("/api/interview/review-queue", h.HandleReviewQueue)
		r.Get("/health/eval-queue", h.HandleEvalQueueHealth)
	})

	// ─── Student: take tests ──────────────────────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Get("/api/my/assessments", h.ListMyAssessments)
		r.Get("/api/my/analytics", h.MyAnalytics)
		r.Get("/api/my/batches", h.ListMyBatches)

		// Invitation accept/decline — any authenticated user (students accepting
		// batch invitations must reach this endpoint before they are org members).
		r.Post("/api/invitations/accept", h.AcceptInvitation)
		r.Post("/api/invitations/decline", h.DeclineInvitation)

		r.Post("/api/assessments/{assessmentID}/attempts", h.StartAttempt)
		r.Get("/api/attempts/{attemptID}", h.ResumeAttempt)
		r.Put("/api/attempts/{attemptID}/answers", h.SaveAnswer)
		r.Post("/api/attempts/{attemptID}/questions/{assessmentQuestionID}/run", h.RunCode)
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

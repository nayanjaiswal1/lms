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
// Staff-author group — owner / admin / instructor: creates, edits, publishes,
// deletes, or otherwise mutates assessments, questions, categories, test
// templates, cohort groups, and batches (incl. batch authoring, bulk
// import/invite, and grading overrides). Mentor does NOT get this group: the
// seeded mentor role only holds assessments.view_results, mentoring.manage_batches,
// mentoring.view_students, and admin.view_members — none of the
// create/edit/publish/delete/manage_questions/manage_batches (assessment-batch
// authoring) permissions. See docs/rbac.md §3.
// Staff-all group — owner / admin / instructor / mentor: read-only results,
// progress, and analytics views, plus batch-roster membership management,
// which is what mentor's granted permissions actually cover.
// Student group — any authenticated org member: take tests, view own results.
func (h *Handler) RegisterRoutes(r chi.Router) {
	staffAuthor := middleware.RequireOrgRole(h.pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor)
	staffAll := middleware.RequireOrgRole(h.pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor, middleware.RoleMentor)

	// ─── Staff: authoring (owner/admin/instructor only) ───────────────────────
	r.Group(func(r chi.Router) {
		r.Use(staffAuthor)

		// Question categories
		r.Post("/api/categories", h.CreateCategory)
		r.Get("/api/categories", h.ListCategories)

		// Question bank
		r.Post("/api/questions", h.CreateQuestion)
		r.Get("/api/questions", h.ListQuestions)
		r.Get("/api/questions/usage", h.ListQuestionUsage)
		r.Get("/api/questions/tags", h.ListQuestionTags)
		r.Get("/api/questions/{questionID}", h.GetQuestion)
		r.Patch("/api/questions/{questionID}", h.UpdateQuestion)
		r.Delete("/api/questions/{questionID}", h.ArchiveQuestion)

		// Batches — authoring (creation/edit/cover image). Roster membership
		// (add/remove members) lives in the staff-all group below since that's
		// the "manage mentoring-batch rosters" mentor is granted.
		r.Post("/api/batches", h.CreateBatch)
		r.Patch("/api/batches/{batchID}", h.UpdateBatch)
		r.Post("/api/batches/{batchID}/image", h.UploadBatchImage)
		r.Delete("/api/batches/{batchID}/image", h.DeleteBatchImage)

		// Cohort groups (optional hierarchy above batches, e.g. Class/Section)
		r.Post("/api/cohort-groups", h.CreateCohortGroup)
		r.Get("/api/cohort-groups", h.ListCohortGroups)
		r.Get("/api/cohort-groups/{groupID}", h.GetCohortGroup)
		r.Patch("/api/cohort-groups/{groupID}", h.UpdateCohortGroup)
		r.Delete("/api/cohort-groups/{groupID}", h.ArchiveCohortGroup)
		r.Put("/api/batches/{batchID}/cohort-group", h.MoveBatchToGroup)

		// Batch mentors (who mentors this batch) — administrative assignment,
		// distinct from a mentor managing their own students' roster.
		r.Post("/api/batches/{batchID}/mentors", h.AddBatchMentor)
		r.Delete("/api/batches/{batchID}/mentors/{userID}", h.RemoveBatchMentor)
		r.Get("/api/batches/{batchID}/mentors", h.ListBatchMentors)

		// Batch courses (structure/authoring)
		r.Post("/api/batches/{batchID}/courses", h.AssignBatchCourse)
		r.Delete("/api/batches/{batchID}/courses/{courseID}", h.UnassignBatchCourse)
		r.Get("/api/batches/{batchID}/courses", h.ListBatchCourses)

		// Batch invitations — bulk-invite workflow, explicitly excluded from mentor
		r.Post("/api/batches/{batchID}/invite", h.BulkInvite)
		r.Get("/api/batches/{batchID}/invitations", h.ListInvitations)
		r.Delete("/api/batches/{batchID}/invitations/{invID}", h.RevokeInvitation)
		r.Post("/api/batches/{batchID}/invitations/{invID}/resend", h.ResendInvitation)

		// Bulk student import via Excel — explicitly excluded from mentor
		r.Post("/api/batches/{batchID}/import/parse", h.HandleImportParse)
		r.Post("/api/batches/{batchID}/import/validate", h.HandleImportValidate)
		r.Post("/api/batches/{batchID}/import/confirm", h.HandleImportConfirm)
		r.Get("/api/batches/{batchID}/import/report", h.HandleImportReport)

		// Classroom Test Assessment Engine — entering/editing manual offline
		// test scores is a mutation of grading outcomes, not "view_results".
		r.Post("/api/batches/{batchID}/offline-tests", h.CreateOfflineTestScores)
		r.Patch("/api/batches/{batchID}/offline-tests/{testID}/scores/{userID}", h.UpdateOfflineTestScore)

		// Offline test templates — reusable name + default max score
		r.Post("/api/test-templates", h.CreateTestTemplate)
		r.Get("/api/test-templates", h.ListTestTemplates)

		// Assessments — full CRUD, structure, and publish lifecycle. GET routes
		// here return assessment definitions (incl. question/answer content),
		// which mentor's view_results (results, not definitions) doesn't cover.
		r.Post("/api/assessments", h.CreateAssessment)
		r.Get("/api/assessments", h.ListAssessments)
		r.Get("/api/assessments/{assessmentID}", h.GetAssessment)
		r.Patch("/api/assessments/{assessmentID}", h.UpdateAssessment)
		r.Post("/api/assessments/{assessmentID}/questions", h.AddAssessmentQuestion)
		r.Post("/api/assessments/{assessmentID}/questions/auto-select", h.AutoSelectAssessmentQuestions)
		r.Delete("/api/assessments/{assessmentID}/questions/{aqID}", h.RemoveAssessmentQuestion)
		r.Post("/api/assessments/{assessmentID}/publish", h.PublishAssessment)
		r.Post("/api/assessments/{assessmentID}/status", h.SetAssessmentStatus)

		// Assignment (who takes the assessment) — authoring, not results review
		r.Post("/api/assessments/{assessmentID}/assignments", h.CreateAssignment)
		r.Get("/api/assessments/{assessmentID}/assignments", h.ListAssignments)
		r.Delete("/api/assessments/{assessmentID}/assignments/{assignmentID}", h.DeleteAssignment)

		// Grading-outcome overrides — mutate a score/answer verdict, not a view;
		// mentor's assessments.view_results is view-only by name.
		r.Patch("/api/assessments/{assessmentID}/candidates/{candidateID}/override", h.OverridePublicCandidateScore)
		r.Patch("/api/attempts/{attemptID}/answers/{answerID}/override", h.OverrideAnswerScore)
	})

	// ─── Staff: read/view + mentoring-roster management ───────────────────────
	// Matches what the seeded mentor role actually holds: assessments.view_results,
	// mentoring.manage_batches (roster), mentoring.view_students, admin.view_members.
	r.Group(func(r chi.Router) {
		r.Use(staffAll)

		// Batches — viewing, and roster membership (mentor's "manage batches"
		// permission is about the student roster of batches they mentor).
		r.Get("/api/batches", h.ListBatches)
		r.Get("/api/batches/{batchID}", h.GetBatch)
		r.Post("/api/batches/{batchID}/members", h.AddBatchMembers)
		r.Delete("/api/batches/{batchID}/members/{userID}", h.RemoveBatchMember)

		// Batch progress + analytics
		r.Get("/api/batches/{batchID}/progress", h.GetBatchProgress)
		r.Get("/api/batches/{batchID}/analytics", h.GetBatchAnalytics)

		// Classroom Test Assessment Engine — viewing offline/manual test results
		r.Get("/api/batches/{batchID}/offline-tests", h.ListOfflineTests)
		r.Get("/api/batches/{batchID}/offline-tests/{testID}", h.GetOfflineTest)

		// Analytics + results review (view-only)
		r.Get("/api/assessments/{assessmentID}/analytics", h.AssessmentAnalytics)
		r.Get("/api/assessments/{assessmentID}/attempts", h.ListAssessmentAttempts)
		r.Get("/api/assessments/{assessmentID}/candidates", h.GetPublicCandidates)
		r.Get("/api/attempts/{attemptID}/proctoring", h.AttemptProctoringLog)
		r.Get("/api/analytics/overview", h.OrgAnalytics)

		// Interview evaluation — staff review queue (read) and queue health
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

package gitlab

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/secrets"
)

// New builds the fully-wired gitlab Handler from the shared pool, config,
// secrets vault, jobs registry, notifications service, and AI provider.
// vault must be the same instance shared with the rest of the app (see
// internal/api/router.go) so tokens encrypted here decrypt correctly
// wherever else they're read (e.g. the token-refresh job in
// cmd/server/main.go, built as its own standalone gitlab.Service the same
// way assessment.New's job-only instance is built there). jobsRegistry is
// used by Batch 2's provisioning/roster-sync flows to enqueue
// gitlab.provision_team/gitlab.sync_members jobs. notifSvc is Batch 5's
// generic notifications domain (internal/notifications), used by
// service_checkpoint.go/service_webhook.go's peer-review and CI-alert flows.
// aiProvider is Batch 8's AI MR reviewer dependency.
func New(pool *pgxpool.Pool, cfg *config.Config, vault *secrets.Vault, jobsRegistry *jobs.Registry, notifSvc *notifications.Service, aiProvider ai.LLMProvider) *Handler {
	service := NewService(pool, cfg, vault, jobsRegistry, notifSvc, aiProvider)
	return NewHandler(service)
}

// Service exposes the built *gitlab.Service so a sibling domain can consume
// it as an optional dependency without gitlab importing that domain back —
// e.g. internal/api/router.go passes this into labs.New's RepoPreparer slot
// for the Batch 3 lab-container auto-clone hook. Mirrors authz.Handler's own
// Service() accessor (internal/authz/handler.go), already used the same way
// for calendarRouter/mentoringRouter's *.Service field.
func (h *Handler) Service() *Service {
	return h.service
}

// RegisterRoutes mounts the authenticated gitlab API onto the given router.
// The caller is responsible for applying RequireAuth + RequireCSRF before
// this. Installation management is admin-only; connect/status/disconnect is
// any authenticated org member managing their own personal connection;
// the projects/teams provisioning surface (Batch 2) is staff (admin or
// instructor) — these are day-to-day teaching operations, not admin-only
// org configuration, per kind-herding-cookie.md §2's routes table.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireOrgRole(h.service.pool, middleware.RoleOwner, middleware.RoleAdmin))

		r.Get("/api/gitlab/installations", h.InstallationsList)
		r.Post("/api/gitlab/installations", h.InstallationsCreate)
		r.Patch("/api/gitlab/installations/{installationID}", h.InstallationUpdate)
		r.Delete("/api/gitlab/installations/{installationID}", h.InstallationDelete)
		r.Post("/api/gitlab/installations/{installationID}/verify", h.InstallationVerify)
		r.Post("/api/gitlab/installations/{installationID}/set-default", h.InstallationSetDefault)

		r.Get("/api/gitlab/org-config", h.OrgConfigGet)
		r.Put("/api/gitlab/org-config", h.OrgConfigPut)
	})

	r.Get("/api/gitlab/connect", h.Connect)
	r.Get("/api/gitlab/status", h.Status)
	r.Post("/api/gitlab/disconnect", h.Disconnect)

	// Planning & task board moved to the workspace package — it now serves
	// real assigned work items instead of embedded fixtures (see
	// workspace/handler_planning.go, workspace/routes.go).

	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireOrgRole(h.service.pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor))

		r.Post("/api/workspace-cohorts", h.CreateAssignment)
		r.Get("/api/workspace-cohorts", h.ListAssignments)
		r.Get("/api/workspace-cohorts/{assignmentID}", h.GetAssignment)
		r.Patch("/api/workspace-cohorts/{assignmentID}", h.UpdateAssignment)
		r.Delete("/api/workspace-cohorts/{assignmentID}", h.DeleteAssignment)
		r.Post("/api/workspace-cohorts/{assignmentID}/publish", h.PublishAssignment)
		r.Put("/api/workspace-cohorts/{assignmentID}/installation", h.SetAssignmentInstallation)

		// Batch 6: mid-project template updates + cross-team originality
		// scan — instructor-triggered, per kind-herding-cookie.md §2's routes
		// table ("Reports | POST/GET .../originality, POST .../handoff").
		r.Post("/api/workspace-cohorts/{assignmentID}/template-sync", h.TemplateSync)
		r.Post("/api/workspace-cohorts/{assignmentID}/originality", h.RequestOriginalityScan)
		r.Get("/api/workspace-cohorts/{assignmentID}/originality", h.ListOriginalityReports)

		r.Get("/api/workspace-cohorts/{assignmentID}/teams", h.ListTeams)
		r.Post("/api/workspace-cohorts/teams/{teamID}/reprovision", h.ReprovisionTeam)
		r.Post("/api/workspace-cohorts/teams/{teamID}/handoff", h.RequestHandoff)

		// Batch 5: checkpoints + peer-review submissions — staff, per
		// kind-herding-cookie.md §2's routes table.
		r.Post("/api/workspace-cohorts/{assignmentID}/checkpoints", h.CreateCheckpoint)
		r.Get("/api/workspace-cohorts/{assignmentID}/checkpoints", h.ListCheckpoints)
		r.Patch("/api/workspace-cohorts/checkpoints/{checkpointID}", h.UpdateCheckpoint)
		r.Delete("/api/workspace-cohorts/checkpoints/{checkpointID}", h.DeleteCheckpoint)

		r.Get("/api/workspace-cohorts/checkpoints/{checkpointID}/submissions", h.ListSubmissions)
		r.Patch("/api/workspace-cohorts/checkpoints/{checkpointID}/submissions/{teamID}/grade", h.GradeSubmission)
		r.Post("/api/workspace-cohorts/checkpoints/{checkpointID}/submissions/{teamID}/merge", h.MergeSubmission)
		r.Post("/api/workspace-cohorts/checkpoints/{checkpointID}/submissions/{teamID}/comment", h.CommentOnSubmission)

		// Batch 7: settling a design/architecture review checkpoint — staff
		// makes the final call, same split as grade/merge above. The
		// cross-team proposal listing lives here too (not with the
		// team-scoped one below) since staff are never project_team_members
		// themselves.
		r.Get("/api/workspace-cohorts/checkpoints/{checkpointID}/proposals", h.ListAllDesignProposals)
		r.Post("/api/workspace-cohorts/proposals/{proposalID}/accept", h.AcceptDesignProposal)
	})

	// Batch 4: dashboards — staff+mentor, per kind-herding-cookie.md §2's
	// routes table. Day-to-day teaching visibility (who's contributing, is
	// anyone free-riding), not admin-only org configuration, so mentors get
	// it too — same three-role set courses/messaging/assessment already use
	// for their own "staff+mentor" surfaces (see e.g.
	// internal/courses/routes.go:12, internal/assessment/routes.go:39).
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireOrgRole(h.service.pool, middleware.RoleOwner, middleware.RoleAdmin, middleware.RoleInstructor, middleware.RoleMentor))

		r.Get("/api/workspace-cohorts/{assignmentID}/dashboard", h.GetAssignmentDashboard)
		r.Get("/api/workspace-cohorts/{assignmentID}/burndown", h.GetAssignmentBurndown)
		r.Get("/api/workspace-cohorts/{assignmentID}/leaderboard", h.GetAssignmentLeaderboard)
		r.Get("/api/workspace-cohorts/{assignmentID}/ownership", h.GetAssignmentOwnership)
	})
}

// RegisterPublicRoutes mounts the OAuth callback — authenticated via the
// gitlab_oauth_states row matched by the state param, not a session cookie,
// since PKCE's verifier must survive a cross-site top-level redirect — and
// the Batch 3 webhook receiver, authenticated via X-Gitlab-Token instead
// (see handler_webhook.go).
func (h *Handler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/gitlab/callback", h.Callback)
	r.Post("/api/gitlab/webhook", h.Webhook)
}

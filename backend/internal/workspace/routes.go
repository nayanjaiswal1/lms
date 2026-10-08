package workspace

import (
	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/authz"
)

// RegisterRoutes mounts the authenticated workspace API. The caller (see
// internal/api/router.go) applies RequireAuth + RequireCSRF to r before this
// — every route below assumes an authenticated, CSRF-checked request.
// Per-route project-role/status gates come from this package's own
// middleware.go (RequireProjectRole, ProjectStatusGate), per 00-decisions D4
// and contract-phase1.md's route table.
func (h *Handler) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	pool := h.service.repo.Pool()
	gate := func(r chi.Router, min string, allowedStatuses ...string) {
		r.Use(RequireProjectRole(pool, h.perms, min))
		if len(allowedStatuses) > 0 {
			r.Use(ProjectStatusGate(allowedStatuses...))
		}
	}

	r.With(authz.RequirePermission(authzSvc, PermProjectsCreate)).Post("/api/workspaces", h.CreateProject)
	r.Get("/api/workspaces", h.ListProjects)
	r.Get("/api/workspaces/invitations", h.ListMyInvitations)
	r.Post("/api/workspaces/{workspaceID}/membership/respond", h.RespondToInvite)

	// Planning & task board — any
	// authenticated caller, built from their own assigned open work items
	// across every workspace they're an active member of. No project-role
	// gate: this aggregates across projects rather than acting on one.
	r.Get("/api/gitlab/planning/board", h.PlanningBoard)
	r.Get("/api/gitlab/planning/issues", h.PlanningIssues)

	// viewer, no status gate
	r.Group(func(r chi.Router) {
		gate(r, RoleViewer)
		r.Get("/api/workspaces/{workspaceID}", h.GetProject)
		r.Get("/api/workspaces/{workspaceID}/requirement", h.GetRequirement)
		r.Get("/api/workspaces/{workspaceID}/members", h.ListMembers)
		r.Get("/api/workspaces/{workspaceID}/tracks", h.ListTracks)
		r.Get("/api/workspaces/{workspaceID}/onboarding", h.ListOnboarding)

		// Phase 2 — work items: reads are viewer, no status gate.
		r.Get("/api/workspaces/{workspaceID}/items", h.ListWorkItems)
		r.Get("/api/workspaces/{workspaceID}/items/similar", h.ListSimilarItems)
		r.Get("/api/workspaces/{workspaceID}/items/{itemID}", h.GetWorkItem)
		r.Get("/api/workspaces/{workspaceID}/items/{itemID}/events", h.ListItemEvents)

		// Phase 3 — reads are viewer, no status gate (contract-phase3.md).
		r.Get("/api/workspaces/{workspaceID}/questions", h.ListQuestions)
		r.Get("/api/workspaces/{workspaceID}/questions/similar", h.SimilarQuestions)
		r.Get("/api/workspaces/{workspaceID}/questions/{questionID}/comments", h.ListQuestionComments)
		r.Get("/api/workspaces/{workspaceID}/brief", h.GetBrief)
		r.Get("/api/workspaces/{workspaceID}/items/{itemID}/doc", h.GetDoc)
		r.Get("/api/workspaces/{workspaceID}/items/{itemID}/comments", h.ListItemComments)
		r.Get("/api/workspaces/{workspaceID}/meetings", h.ListMeetings)
		r.Get("/api/workspaces/{workspaceID}/standups", h.ListStandups)

		// Phase 4 — reads are viewer, no status gate (contract-phase4.md).
		r.Get("/api/workspaces/{workspaceID}/items/{itemID}/gitlab", h.GetItemGitlabLinks)
		r.Get("/api/workspaces/{workspaceID}/time-logs", h.ListTimeLogs)
		r.Get("/api/workspaces/{workspaceID}/dashboard", h.GetDashboard)

		// Phase 5 — releases/sprints reads are viewer, no status gate
		// (contract-phase5.md's route table). GetReleaseNotes' own polish=true
		// manager check happens inside the service, since the gate can't
		// express "GET is viewer but this one query param needs manager+".
		r.Get("/api/workspaces/{workspaceID}/releases", h.ListReleases)
		r.Get("/api/workspaces/{workspaceID}/releases/{releaseID}/notes", h.GetReleaseNotes)
		r.Get("/api/workspaces/{workspaceID}/sprints", h.ListSprints)
	})
	// viewer, not cancelled/archived (service enforces self-or-manager)
	r.Group(func(r chi.Router) {
		gate(r, RoleViewer, StatusesLive...)
		r.Delete("/api/workspaces/{workspaceID}/members/{userID}", h.RemoveMember)
	})

	// member, planning statuses (service enforces self/lead/manager+ per action)
	r.Group(func(r chi.Router) {
		gate(r, RoleMember, StatusesPlanning...)
		r.Post("/api/workspaces/{workspaceID}/tracks/{trackID}/members", h.JoinTrack)
		r.Post("/api/workspaces/{workspaceID}/tracks/{trackID}/members/{userID}/approve", h.ApproveTrackMember)
		r.Delete("/api/workspaces/{workspaceID}/tracks/{trackID}/members/{userID}", h.LeaveTrack)

		// Phase 2 — work items: writes are member+, gated to planning statuses;
		// per-action role (epic/feature creator, editor, transition actor, ...)
		// is enforced inside the service (contract-phase2.md's own table).
		r.Post("/api/workspaces/{workspaceID}/items", h.CreateWorkItem)
		r.Patch("/api/workspaces/{workspaceID}/items/{itemID}", h.UpdateWorkItem)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/move", h.MoveWorkItem)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/archive", h.ArchiveWorkItem)
		r.Delete("/api/workspaces/{workspaceID}/items/{itemID}", h.DeleteWorkItem)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/transition", h.TransitionWorkItem)
		r.Put("/api/workspaces/{workspaceID}/items/{itemID}/assignees", h.SetAssignees)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/links", h.CreateItemLink)
		r.Delete("/api/workspaces/{workspaceID}/items/{itemID}/links/{toItemID}/{kind}", h.DeleteItemLink)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/triage", h.TriageBug)
		r.Post("/api/workspaces/{workspaceID}/meetings/{eventID}/action-items", h.ConvertActionItem)

		// Phase 5 — release targeting and the epic/breakdown AI suggestions
		// are member+, gated to planning statuses; the service enforces
		// manager+/track-lead for the AI ones and the editor rule for release
		// targeting (contract-phase5.md's own route table).
		r.Put("/api/workspaces/{workspaceID}/items/{itemID}/release", h.SetItemRelease)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/ai/breakdown", h.SuggestTaskBreakdown)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/ai/assignees", h.SuggestAssignees)
	})
	// member, any non-terminal status — always the caller's own progress
	r.Group(func(r chi.Router) {
		gate(r, RoleMember, StatusesNotFinal...)
		r.Put("/api/workspaces/{workspaceID}/onboarding/{stepID}/done", h.SetOnboardingStepDone)
	})
	// Phase 5 — member, no status gate (contract-phase5.md's route table):
	// feedback reads, a member's own outcome report or a track lead's team
	// report, and the showcase opt-in.
	r.Group(func(r chi.Router) {
		gate(r, RoleMember)
		r.Get("/api/workspaces/{workspaceID}/feedback", h.GetFeedback)
		r.Get("/api/workspaces/{workspaceID}/members/{userID}/report", h.GetMemberReport)
		r.Put("/api/workspaces/{workspaceID}/membership/showcase", h.SetShowcaseOptIn)
	})
	// Phase 5 — member, StatusesFeedback (completed only): submitting a
	// rating only makes sense once the project's feedback window is open.
	r.Group(func(r chi.Router) {
		gate(r, RoleMember, StatusesFeedback...)
		r.Post("/api/workspaces/{workspaceID}/feedback", h.SubmitPeerFeedback)
	})
	// Phase 3 — member, StatusesDiscuss (contract-phase3.md).
	r.Group(func(r chi.Router) {
		gate(r, RoleMember, StatusesDiscuss...)
		r.Post("/api/workspaces/{workspaceID}/questions", h.AskQuestion)
		r.Post("/api/workspaces/{workspaceID}/questions/{questionID}/comments", h.CreateQuestionComment)
		r.Post("/api/workspaces/{workspaceID}/brief", h.CreateBriefPage)
		r.Post("/api/workspaces/{workspaceID}/brief/approve", h.ApproveBrief)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/doc/submit", h.SubmitDoc)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/doc/reviews", h.ReviewDoc)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/doc/design-review", h.ScheduleDesignReview)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/comments", h.CreateItemComment)
	})
	// Phase 3 — member, StatusesWork (own standup).
	// Phase 4 — member, StatusesWork (own time logs, contract-phase4.md 4b).
	r.Group(func(r chi.Router) {
		gate(r, RoleMember, StatusesWork...)
		r.Put("/api/workspaces/{workspaceID}/standups", h.PostStandup)
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/time-logs", h.LogTime)
		r.Patch("/api/workspaces/{workspaceID}/time-logs/{logID}", h.UpdateTimeLog)
		r.Delete("/api/workspaces/{workspaceID}/time-logs/{logID}", h.DeleteTimeLog)

		// Phase 5 — member, StatusesWork (own item's sprint assignment).
		r.Put("/api/workspaces/{workspaceID}/items/{itemID}/sprint", h.SetItemSprint)
	})
	// Phase 5 — manager, StatusesWork (sprint lifecycle; contract-phase5.md).
	r.Group(func(r chi.Router) {
		gate(r, RoleManager, StatusesWork...)
		r.Post("/api/workspaces/{workspaceID}/sprints", h.CreateSprint)
		r.Post("/api/workspaces/{workspaceID}/sprints/{sprintID}/start", h.StartSprint)
		r.Post("/api/workspaces/{workspaceID}/sprints/{sprintID}/close", h.CloseSprint)
	})

	// manager, no status gate
	r.Group(func(r chi.Router) {
		gate(r, RoleManager)
		r.Get("/api/workspaces/{workspaceID}/interests", h.ListInterests)

		// Phase 5 — manager, no status gate (contract-phase5.md's route table).
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/ai/why-late", h.ExplainLate)
		r.Post("/api/workspaces/{workspaceID}/ai/weekly-summary", h.GetWeeklySummary)
		r.Get("/api/workspaces/{workspaceID}/export/{kind}.csv", h.ExportCSV)
	})
	// manager, recruiting/active
	r.Group(func(r chi.Router) {
		gate(r, RoleManager, StatusesRecruit...)
		r.Patch("/api/workspaces/{workspaceID}/interests/{interestID}", h.ReviewInterest)
		r.Post("/api/workspaces/{workspaceID}/interests/{interestID}/rank", h.RankInterest)
	})
	// manager, planning statuses
	r.Group(func(r chi.Router) {
		gate(r, RoleManager, StatusesPlanning...)
		r.Post("/api/workspaces/{workspaceID}/members", h.AddMember)
		r.Patch("/api/workspaces/{workspaceID}/members/{userID}", h.UpdateMember)
		r.Post("/api/workspaces/{workspaceID}/tracks", h.CreateTrack)
		r.Patch("/api/workspaces/{workspaceID}/tracks/{trackID}", h.UpdateTrack)
		r.Delete("/api/workspaces/{workspaceID}/tracks/{trackID}", h.DeleteTrack)
		r.Post("/api/workspaces/{workspaceID}/onboarding", h.CreateOnboardingStep)
		r.Patch("/api/workspaces/{workspaceID}/onboarding/{stepID}", h.UpdateOnboardingStep)
		r.Delete("/api/workspaces/{workspaceID}/onboarding/{stepID}", h.DeleteOnboardingStep)

		// Phase 5 — manager, planning statuses (contract-phase5.md's route table).
		r.Post("/api/workspaces/{workspaceID}/releases", h.CreateRelease)
		r.Patch("/api/workspaces/{workspaceID}/releases/{releaseID}", h.UpdateRelease)
		r.Post("/api/workspaces/{workspaceID}/ai/epics", h.SuggestEpics)
	})
	// Phase 3 — manager, StatusesDiscuss (contract-phase3.md).
	r.Group(func(r chi.Router) {
		gate(r, RoleManager, StatusesDiscuss...)
		r.Post("/api/workspaces/{workspaceID}/questions/{questionID}/answer", h.AnswerQuestion)
		r.Post("/api/workspaces/{workspaceID}/requirement/gaps", h.RequirementGaps)
		r.Post("/api/workspaces/{workspaceID}/meetings", h.ScheduleMeeting)
		r.Put("/api/workspaces/{workspaceID}/meetings/{eventID}/attendance", h.RecordAttendance)

		// Phase 5 — manager, StatusesDiscuss (contract-phase5.md's route table).
		r.Post("/api/workspaces/{workspaceID}/items/{itemID}/ai/change-impact", h.ChangeImpact)
	})

	// owner, no status gate
	r.Group(func(r chi.Router) {
		gate(r, RoleOwner)
		r.Patch("/api/workspaces/{workspaceID}/status", h.SetProjectStatus)
	})
	// Phase 5 — owner, StatusesFeedback (completed only): certificates are
	// only ever issued once a project has actually finished.
	r.Group(func(r chi.Router) {
		gate(r, RoleOwner, StatusesFeedback...)
		r.Post("/api/workspaces/{workspaceID}/certificates", h.IssueCertificate)
	})
	// owner, not cancelled/archived
	r.Group(func(r chi.Router) {
		gate(r, RoleOwner, StatusesNotFinal...)
		r.Patch("/api/workspaces/{workspaceID}", h.UpdateProject)
	})
	// owner, any live (non-archived) status
	r.Group(func(r chi.Router) {
		gate(r, RoleOwner, StatusesLive...)
		r.Post("/api/workspaces/{workspaceID}/share-token", h.RotateShareToken)
		r.Post("/api/workspaces/{workspaceID}/transfer-owner", h.TransferOwner)
	})
	// owner, planning statuses
	r.Group(func(r chi.Router) {
		gate(r, RoleOwner, StatusesPlanning...)
		r.Put("/api/workspaces/{workspaceID}/requirement", h.UpdateRequirement)
		// Phase 4 (D8) — GitLab provisioning; the service itself also checks
		// gitlab_enabled (contract-phase4.md: "owner, StatusesPlanning, gitlab_enabled").
		r.Post("/api/workspaces/{workspaceID}/gitlab/provision", h.ProvisionGitlab)
	})
}

// RegisterPublicRoutes mounts the anonymous share-link surface: no auth, no
// CSRF (see internal/api/router.go for where this is mounted outside the
// authenticated group).
func (h *Handler) RegisterPublicRoutes(r chi.Router) {
	r.Get("/api/public/workspaces/{shareToken}", h.GetPublicProject)
	r.Post("/api/public/workspaces/{shareToken}/interest", h.SubmitInterest)
}

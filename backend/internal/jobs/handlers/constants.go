package handlers

import "github.com/mindforge/backend/internal/jobs"

const (
	HandlerEvalSubjective      = "eval.subjective"
	HandlerEmailSend           = "email.send"
	HandlerBulkInvite          = "invite.bulk"
	HandlerLLM                 = jobs.HandlerLLM
	HandlerAnalytics           = "analytics.task"
	HandlerRetentionPurge      = "retention.purge"
	HandlerPaymentReconcile    = "payments.reconcile"
	HandlerMentorEscalate      = "mentoring.escalate_tickets"
	HandlerCalendarReminder    = "calendar.reminder"
	HandlerBatchImport         = "batch_import.students"
	HandlerGitlabTokenRefresh  = "gitlab.token_refresh"
	HandlerGitlabProvisionTeam = "gitlab.provision_team"
	HandlerGitlabSyncMembers   = "gitlab.sync_members"
	HandlerGitlabIngestEvent   = "gitlab.ingest_event"
	HandlerGitlabCommitStats   = "gitlab.commit_stats"
	HandlerGitlabPollSync      = "gitlab.poll_sync"

	// Batch 6: deadlines, originality, handoff.
	HandlerGitlabDeadlineSnapshot = "gitlab.deadline_snapshot"
	HandlerGitlabTemplateSync     = "gitlab.template_sync"
	HandlerGitlabOriginalityScan  = "gitlab.originality_scan"
	HandlerGitlabHandoff          = "gitlab.handoff"
	HandlerProjectHandoff         = "project.handoff"

	// Batch 8: AI MR review (docs/project-marketplace.md Phase C).
	HandlerGitlabAIReviewMR = "gitlab.ai_review_mr"

	// Ops alerting (internal/opsalert): health checks and the daily digest.
	HandlerOpsHealth = "ops.health"
	HandlerOpsDigest = "ops.digest"

	// Nightly AI revision digest (internal/digest).
	HandlerDigestNightly = "digest.nightly"
	HandlerDigestUser    = "digest.user"

	// Project marketplace (internal/projectmarket) — Phase A, Slice 1 finish.
	HandlerProjectmarketScoreRequirement = "projectmarket.score_requirement"
	HandlerProjectmarketCloseExpired     = "projectmarket.close_expired"

	// Knowledge Captures (internal/captures) — extract + AI-structure a
	// screenshot/PDF/link into a journal note or SRS flashcard candidate.
	HandlerCapturesProcess = "captures.process"

	// Project Workspace (internal/workspace), Phase 1 — see
	// docs/project-workspace-plan/contract-phase1.md's Jobs section.
	HandlerWorkspaceProjectInviteEmail = "workspace.project_invite_email"
	HandlerWorkspacePurge              = "workspace.purge_interests"
	HandlerWorkspaceBriefReminder      = "workspace.brief_reminder"
	HandlerWorkspaceDocReviewReminder  = "workspace.doc_review_reminder"

	// Project Workspace Phase 4 (contract-phase4.md's Jobs sections).
	HandlerWorkspaceGitlabSync      = "workspace.gitlab_sync"
	HandlerWorkspaceInactivitySweep = "workspace.inactivity_sweep"
	HandlerWorkspaceManagerDigest   = "workspace.manager_digest"

	// Project Workspace Phase 5 (contract-phase5.md's Jobs section). The
	// cron-scheduled fan-out (weekly_summary) enqueues one
	// ai_weekly_summary_project job per active project, idempotency-keyed on
	// project+ISO week — same fan-out shape as digest.nightly/digest.user.
	HandlerWorkspaceAIWeeklySummary        = "workspace.ai_weekly_summary"
	HandlerWorkspaceAIWeeklySummaryProject = "workspace.ai_weekly_summary_project"
)

package handlers

const (
	HandlerEvalSubjective      = "eval.subjective"
	HandlerEmailSend           = "email.send"
	HandlerBulkInvite          = "invite.bulk"
	HandlerLLM                 = "llm.task"
	HandlerSRSReminder         = "srs.review_reminder"
	HandlerAnalytics           = "analytics.task"
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

	// Nightly AI revision digest (internal/digest).
	HandlerDigestNightly = "digest.nightly"
	HandlerDigestUser    = "digest.user"

	// Project marketplace (internal/projectmarket) — Phase A, Slice 1 finish.
	HandlerProjectmarketScoreRequirement = "projectmarket.score_requirement"
	HandlerProjectmarketCloseExpired     = "projectmarket.close_expired"
)

package workspace

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/notifications"
)

// RunInactivitySweep is the workspace.inactivity_sweep daily 03:00 job
// (contract-phase4.md 4c): an active member with no activity for
// InactivityAlertAfter (7d) gets their managers notified; past
// InactivitySuggestAfter (14d), a stronger "consider removal" nudge. Dedupe
// keys are per member+stage+ISO week, so the same stage isn't renotified
// every single day it stays true — only once per calendar week it's observed.
func (s *Service) RunInactivitySweep(ctx context.Context) (int, error) {
	now := s.now()
	members, err := s.repo.ListActiveMembersLastActivity(ctx)
	if err != nil {
		return 0, err
	}
	year, week := now.ISOWeek()

	sent := 0
	for _, m := range members {
		age := now.Sub(m.LastActive)
		var stage, body string
		switch {
		case age >= InactivitySuggestAfter:
			stage, body = "14d", "A team member has had no activity for 14+ days — consider whether they should be removed."
		case age >= InactivityAlertAfter:
			stage, body = "7d", "A team member has had no activity for 7+ days."
		default:
			continue
		}
		recipients, err := s.repo.ListManagerUserIDs(ctx, s.pool, m.ProjectID)
		if err != nil {
			return sent, err
		}
		if len(recipients) == 0 {
			continue
		}
		notifyErr := s.repo.InTx(ctx, func(tx pgx.Tx) error {
			return s.notif.NotifyMany(ctx, tx, notifications.New{
				OrgID: m.OrgID, Type: "workspace_member_inactive", Title: "Inactive team member", Body: &body,
				EntityType: strPtr("project_member"), EntityID: &m.UserID,
				DedupeKey: fmt.Sprintf("workspace_member_inactive:%s:%s:%s:%d-%02d", m.ProjectID, m.UserID, stage, year, week),
			}, recipients)
		})
		if notifyErr != nil {
			slog.ErrorContext(ctx, "workspace: inactivity sweep notify", "project_id", m.ProjectID, "user_id", m.UserID, "error", notifyErr)
			continue
		}
		sent++
	}
	return sent, nil
}

// service_reminders.go backs the two hourly cron jobs registered in
// cmd/server/main.go (contract-phase3.md "Jobs"). Both scan across every
// project — there is no ProjectCtx here — and notify best-effort per row: one
// failed notify logs and moves on rather than aborting the whole sweep.

// SendBriefReminders nudges unanswered clarifying questions: the project
// owner after QuestionReminderAfter, managers (who may then record an
// assumption) after QuestionAssumptionAfter.
func (s *Service) SendBriefReminders(ctx context.Context) (int, error) {
	now := s.now()
	questions, err := s.repo.ListUnansweredQuestionsOlderThan(ctx, now.Add(-QuestionReminderAfter))
	if err != nil {
		return 0, err
	}

	sent := 0
	for _, q := range questions {
		age := now.Sub(q.CreatedAt)
		var recipients []string
		var stage, body string
		if age >= QuestionAssumptionAfter {
			recipients, err = s.repo.ListManagerUserIDs(ctx, s.pool, q.ProjectID)
			if err != nil {
				return sent, err
			}
			stage = "5d"
			body = "A clarifying question has been unanswered for 5+ days — you may record it as an assumption."
		} else {
			ownerID, err := s.repo.GetProjectOwnerUserID(ctx, s.pool, q.ProjectID)
			if err != nil {
				return sent, err
			}
			if ownerID == "" {
				continue
			}
			recipients = []string{ownerID}
			stage = "3d"
			body = "A clarifying question is waiting for your answer."
		}
		if len(recipients) == 0 {
			continue
		}
		notifyErr := s.repo.InTx(ctx, func(tx pgx.Tx) error {
			return s.notif.NotifyMany(ctx, tx, notifications.New{
				OrgID: q.OrgID, Type: "workspace_question_reminder", Title: "Question needs an answer", Body: &body,
				EntityType: strPtr("requirement_question"), EntityID: &q.ID,
				DedupeKey: fmt.Sprintf("workspace_question_reminder:%s:%s", q.ID, stage),
			}, recipients)
		})
		if notifyErr != nil {
			slog.ErrorContext(ctx, "workspace: send brief reminder", "question_id", q.ID, "error", notifyErr)
			continue
		}
		sent++
	}
	return sent, nil
}

// SendDocReviewReminders nudges feature specs stuck in_review: current
// reviewers after DocReviewReminderAfter, managers after
// DocReviewEscalateAfter.
func (s *Service) SendDocReviewReminders(ctx context.Context) (int, error) {
	now := s.now()
	docs, err := s.repo.ListStaleInReviewDocs(ctx, now.Add(-DocReviewReminderAfter))
	if err != nil {
		return 0, err
	}

	sent := 0
	for _, d := range docs {
		age := now.Sub(d.IdleSince)
		var recipients []string
		var stage, body string
		if age >= DocReviewEscalateAfter {
			recipients, err = s.repo.ListManagerUserIDs(ctx, s.pool, d.ProjectID)
			if err != nil {
				return sent, err
			}
			stage = "5d"
			body = fmt.Sprintf("%s's spec review has been idle for 5+ days.", d.Key)
		} else {
			assignees, aerr := s.repo.ListAssigneesByItem(ctx, s.pool, d.ItemID)
			if aerr != nil {
				return sent, aerr
			}
			recipients = reviewerIDs(assignees)
			stage = "3d"
			body = fmt.Sprintf("%s's spec is waiting for your review.", d.Key)
		}
		if len(recipients) == 0 {
			continue
		}
		notifyErr := s.repo.InTx(ctx, func(tx pgx.Tx) error {
			return s.notif.NotifyMany(ctx, tx, notifications.New{
				OrgID: d.OrgID, Type: "workspace_doc_review_reminder", Title: "Spec review reminder", Body: &body,
				EntityType: strPtr("work_item"), EntityID: &d.ItemID,
				DedupeKey: fmt.Sprintf("workspace_doc_review_reminder:%s:%s", d.ItemID, stage),
			}, recipients)
		})
		if notifyErr != nil {
			slog.ErrorContext(ctx, "workspace: send doc review reminder", "item_id", d.ItemID, "error", notifyErr)
			continue
		}
		sent++
	}
	return sent, nil
}

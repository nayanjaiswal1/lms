package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
)

// Job handler key for this file's job — see service_provision.go's own
// jobProvisionTeam doc comment for why these are plain string literals
// rather than a shared constants import. MUST stay in sync with
// handlers.HandlerGitlabTemplateSync in internal/jobs/handlers/constants.go.
const jobTemplateSync = "gitlab.template_sync"

const templateSyncTimeoutMS = 180000

// RequestTemplateSync enqueues the gitlab.template_sync job for an
// assignment — instructor-triggered, no cron entry: pushing template updates
// into every team's fork mid-project is a deliberate call an instructor
// makes, not something that should fire on a schedule.
func (s *Service) RequestTemplateSync(ctx context.Context, orgID, assignmentID string) error {
	assignment, err := s.repo.GetAssignment(ctx, orgID, assignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: request template sync: %w", err)
	}
	if assignment.TemplateProjectID == nil {
		return fmt.Errorf("gitlab: request template sync: %w: assignment has no resolved template project yet", ErrConflict)
	}
	timeout := templateSyncTimeoutMS
	if _, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, jobs.EnqueueParams{
		Handler: jobTemplateSync, Priority: jobs.PriorityNormal,
		Payload: map[string]string{"assignment_id": assignmentID}, OrgID: &orgID, TimeoutMS: &timeout,
	}); err != nil {
		return fmt.Errorf("gitlab: enqueue template sync: %w", err)
	}
	return nil
}

// RunTemplateSync is the gitlab.template_sync job body: opens one cross-fork
// merge request per ready team, from the template's default branch into the
// team's own fork, reusing the fork relationship every team already has from
// provisioning (kind-herding-cookie.md §0 decision #3) rather than any manual
// patch/cherry-pick pipeline.
//
// Fan-out shape: one job, looping internally over every team and isolating
// each team's failure — matching this codebase's own "one trigger, many
// targets" convention (internal/jobs/handlers/batch_import.go: one job, loop
// over every pending row, log-and-continue per row) rather than enqueuing
// one job per team. A template sync is bounded by an assignment's team count
// (tens, not thousands), so there's no queue-fairness reason to split it the
// way per-commit/per-webhook work is split.
func (s *Service) RunTemplateSync(ctx context.Context, assignmentID string) error {
	assignment, err := s.repo.GetAssignmentByID(ctx, assignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: run template sync: get assignment: %w", err)
	}
	if assignment.TemplateProjectID == nil {
		return fmt.Errorf("gitlab: run template sync: assignment has no resolved template project")
	}
	client, err := s.clientFor(ctx, assignment.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("gitlab: run template sync: resolve client: %w", err)
	}
	teams, err := s.repo.ListTeams(ctx, assignment.OrgID, assignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: run template sync: list teams: %w", err)
	}

	title := fmt.Sprintf("Template sync: %s", assignment.Title)
	for _, team := range teams {
		if team.GitlabProjectID == nil {
			continue // unprovisioned team — nothing to sync into yet
		}
		_, err := client.CreateCrossForkMergeRequest(ctx, *assignment.TemplateProjectID, assignment.DefaultBranch,
			*team.GitlabProjectID, assignment.DefaultBranch, title)
		if err != nil {
			var apiErr *APIError
			if errors.As(err, &apiErr) && apiErr.StatusCode == http.StatusConflict {
				// Nothing to merge — this team's fork is already up to date
				// with the template's default branch. Not a failure.
				continue
			}
			slog.ErrorContext(ctx, "gitlab: template sync: create cross-fork mr failed (continuing with remaining teams)",
				"assignment_id", assignmentID, "team_id", team.ID, "error", err)
			continue
		}
		s.notifyTeam(ctx, &team, notifications.New{
			Type:      "gitlab.template_synced",
			Title:     fmt.Sprintf("Template update available for %q", assignment.Title),
			Body:      strPtr("A merge request with the latest template changes has been opened on your team's project."),
			Priority:  notifications.PriorityNormal,
			DedupeKey: fmt.Sprintf("gitlab.template_synced:%s:%s", team.ID, title),
		})
	}
	return nil
}

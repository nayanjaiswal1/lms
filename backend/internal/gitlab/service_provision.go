package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/mindforge/backend/internal/jobs"
)

// Job handler keys — string literals (not a shared constants package
// reference) because internal/jobs/handlers imports this package to build
// its GitlabProvisionTeamHandler/GitlabSyncMembersHandler, so this package
// cannot import handlers back without a cycle. Matches the same pattern
// internal/assessment/handler_attempt.go uses for "eval.subjective". These
// two literals MUST stay in sync with handlers.HandlerGitlabProvisionTeam
// and handlers.HandlerGitlabSyncMembers in internal/jobs/handlers/constants.go.
const (
	jobProvisionTeam = "gitlab.provision_team"
	jobSyncMembers   = "gitlab.sync_members"
)

// provisionTeamTimeoutMS bounds one provision_team job run — forking +
// polling import status can take longer than the job system's 30s default.
const provisionTeamTimeoutMS = 180000

// ─── assignment CRUD ────────────────────────────────────────────────────────

// CreateAssignment inserts a new draft assignment. Publishing (see
// PublishAssignment) is a separate, explicit instructor action — nothing
// here touches GitLab.
func (s *Service) CreateAssignment(ctx context.Context, orgID, userID string, a ProjectAssignment) (*ProjectAssignment, error) {
	if err := s.validateInstallationOverride(ctx, orgID, a.InstallationID); err != nil {
		return nil, err
	}
	a.OrgID = orgID
	a.CreatedBy = userID
	a.Status = AssignmentStatusDraft
	return s.repo.CreateAssignment(ctx, a)
}

// validateInstallationOverride enforces gitlab_org_config.allow_project_override
// before letting a non-nil installation override onto an assignment;
// clearing one back to nil (follow the org default) is always allowed
// regardless of policy — the policy gates picking a non-default host, not
// un-picking one. Also doubles as tenant isolation for the field:
// GetInstallationByID is org+id scoped, so a foreign-org id resolves
// ErrNotFound rather than silently attaching to the wrong org's credential.
func (s *Service) validateInstallationOverride(ctx context.Context, orgID string, installationID *string) error {
	if installationID == nil {
		return nil
	}
	cfg, err := s.GetOrgConfig(ctx, orgID)
	if err != nil {
		return err
	}
	if !cfg.AllowProjectOverride {
		return ErrOverrideNotAllowed
	}
	_, err = s.repo.GetInstallationByID(ctx, orgID, *installationID)
	return err
}

// SetAssignmentInstallation pins (installationID non-nil) or clears (nil,
// reverting to the org's default installation) which pool entry this
// assignment's teams provision against. A dedicated action rather than a
// field on UpdateAssignment's AssignmentPatch: that patch is COALESCE-based
// (nil means "leave untouched"), which can't express "explicitly clear back
// to default."
func (s *Service) SetAssignmentInstallation(ctx context.Context, orgID, id string, installationID *string) (*ProjectAssignment, error) {
	if err := s.validateInstallationOverride(ctx, orgID, installationID); err != nil {
		return nil, err
	}
	if err := s.repo.SetAssignmentInstallation(ctx, orgID, id, installationID); err != nil {
		return nil, err
	}
	return s.repo.GetAssignment(ctx, orgID, id)
}

// GetAssignment returns a single org-scoped assignment.
func (s *Service) GetAssignment(ctx context.Context, orgID, id string) (*ProjectAssignment, error) {
	return s.repo.GetAssignment(ctx, orgID, id)
}

// ListAssignments lists an org's assignments, optionally filtered to one batch.
func (s *Service) ListAssignments(ctx context.Context, orgID string, batchID *string) ([]ProjectAssignment, error) {
	return s.repo.ListAssignments(ctx, orgID, batchID)
}

// UpdateAssignment applies a partial patch to an assignment's editable fields.
func (s *Service) UpdateAssignment(ctx context.Context, orgID, id string, p AssignmentPatch) (*ProjectAssignment, error) {
	return s.repo.UpdateAssignment(ctx, orgID, id, p)
}

// DeleteAssignment removes a draft assignment (see Repo.DeleteAssignment's
// own doc comment for why published ones can't be deleted this way).
func (s *Service) DeleteAssignment(ctx context.Context, orgID, id string) error {
	return s.repo.DeleteAssignment(ctx, orgID, id)
}

// PublishAssignment transitions a draft assignment to active and enqueues
// gitlab.provision_team for every team already created under it. Teams
// created after publish are enqueued individually by CreateTeam instead, so
// this only needs to catch teams that pre-date the publish action.
func (s *Service) PublishAssignment(ctx context.Context, orgID, assignmentID string) (*ProjectAssignment, error) {
	a, err := s.repo.SetAssignmentStatus(ctx, orgID, assignmentID, AssignmentStatusDraft, AssignmentStatusActive)
	if err != nil {
		return nil, err
	}
	teams, err := s.repo.ListTeams(ctx, orgID, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: publish assignment: list teams: %w", err)
	}
	for _, t := range teams {
		if err := s.enqueueProvisionTeam(ctx, orgID, t.ID, true); err != nil {
			slog.ErrorContext(ctx, "gitlab: enqueue provision_team on publish failed", "team_id", t.ID, "error", err)
		}
	}
	return a, nil
}

// ─── team CRUD ──────────────────────────────────────────────────────────────

// CreateTeam inserts a team under assignmentID. If the assignment is already
// active, provisioning is enqueued immediately; otherwise the team just sits
// pending until the assignment is published (see PublishAssignment).
func (s *Service) CreateTeam(ctx context.Context, orgID, userID, assignmentID, name, slug string) (*ProjectTeam, error) {
	assignment, err := s.repo.GetAssignment(ctx, orgID, assignmentID)
	if err != nil {
		return nil, err
	}
	createdBy := userID
	team, err := s.repo.CreateTeam(ctx, ProjectTeam{
		OrgID:        orgID,
		AssignmentID: assignmentID,
		Name:         name,
		Slug:         slug,
		CreatedBy:    &createdBy,
	})
	if err != nil {
		return nil, err
	}
	if assignment.Status == AssignmentStatusActive {
		if err := s.enqueueProvisionTeam(ctx, orgID, team.ID, true); err != nil {
			slog.ErrorContext(ctx, "gitlab: enqueue provision_team on team create failed", "team_id", team.ID, "error", err)
		}
	}
	return team, nil
}

// ListTeams lists every team under an assignment.
func (s *Service) ListTeams(ctx context.Context, orgID, assignmentID string) ([]ProjectTeam, error) {
	if _, err := s.repo.GetAssignment(ctx, orgID, assignmentID); err != nil {
		return nil, err
	}
	return s.repo.ListTeams(ctx, orgID, assignmentID)
}

// UpdateTeam applies a partial patch to a team's name/slug.
func (s *Service) UpdateTeam(ctx context.Context, orgID, teamID string, p TeamPatch) (*ProjectTeam, error) {
	return s.repo.UpdateTeam(ctx, orgID, teamID, p)
}

// DeleteTeam removes MindForge's own team row (see Repo.DeleteTeam's own doc
// comment for why the underlying GitLab project is left untouched).
func (s *Service) DeleteTeam(ctx context.Context, orgID, teamID string) error {
	return s.repo.DeleteTeam(ctx, orgID, teamID)
}

// ReprovisionTeam force-enqueues a fresh gitlab.provision_team job with no
// idempotency key — unlike the automatic publish/create triggers (which key
// on "gl-prov-"+teamID to avoid a double-fork race), a staff member
// explicitly retrying a team always gets a new attempt even though the
// original job's idempotency key is still on file.
func (s *Service) ReprovisionTeam(ctx context.Context, orgID, teamID string) error {
	if _, err := s.repo.GetTeam(ctx, orgID, teamID); err != nil {
		return err
	}
	return s.enqueueProvisionTeam(ctx, orgID, teamID, false)
}

func (s *Service) enqueueProvisionTeam(ctx context.Context, orgID, teamID string, idempotent bool) error {
	timeout := provisionTeamTimeoutMS
	params := jobs.EnqueueParams{
		Handler:   jobProvisionTeam,
		Priority:  jobs.PriorityHigh,
		Payload:   map[string]string{"team_id": teamID},
		OrgID:     &orgID,
		TimeoutMS: &timeout,
	}
	if idempotent {
		key := "gl-prov-" + teamID
		params.IdempotencyKey = &key
	}
	_, err := jobs.Enqueue(ctx, s.pool, s.jobsRegistry, params)
	if err != nil && !errors.Is(err, jobs.ErrDuplicateKey) {
		return fmt.Errorf("gitlab: enqueue provision_team: %w", err)
	}
	return nil
}

// ─── provisioning (gitlab.provision_team job body) ─────────────────────────

// ProvisionTeam runs the full per-team provisioning flow: ensure the
// assignment's subgroup exists, fork the template project into it, poll the
// fork's import until finished, protect the default branch, and sync roster
// membership. Called by the gitlab.provision_team job handler. Safe to run
// more than once for the same team — each step only acts when its
// precondition (no subgroup yet / no fork yet) still holds, so a retry after
// a partial failure or an explicit reprovision resumes rather than redoing
// completed work.
func (s *Service) ProvisionTeam(ctx context.Context, teamID string) error {
	team, err := s.repo.GetTeamByID(ctx, teamID)
	if err != nil {
		return fmt.Errorf("gitlab: provision team: get team: %w", err)
	}
	assignment, err := s.repo.GetAssignmentByID(ctx, team.AssignmentID)
	if err != nil {
		return fmt.Errorf("gitlab: provision team: get assignment: %w", err)
	}
	if assignment.TemplateProjectID == nil && (assignment.TemplateProjectPath == nil || *assignment.TemplateProjectPath == "") {
		err := fmt.Errorf("assignment %s has no template project configured (neither template_project_id nor template_project_path)", assignment.ID)
		msg := err.Error()
		_ = s.repo.SetTeamProvisionStatus(ctx, teamID, ProvisionFailed, &msg)
		return err
	}

	if err := s.repo.SetTeamProvisionStatus(ctx, teamID, ProvisionProvisioning, nil); err != nil {
		return err
	}

	if stepsErr := s.provisionTeamSteps(ctx, team, assignment); stepsErr != nil {
		msg := stepsErr.Error()
		if err := s.repo.SetTeamProvisionStatus(ctx, teamID, ProvisionFailed, &msg); err != nil {
			slog.ErrorContext(ctx, "gitlab: mark team provision failed", "team_id", teamID, "error", err)
		}
		return stepsErr
	}
	return s.repo.MarkTeamReady(ctx, teamID)
}

func (s *Service) provisionTeamSteps(ctx context.Context, team *ProjectTeam, assignment *ProjectAssignment) error {
	client, err := s.clientFor(ctx, assignment.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("resolve installation client: %w", err)
	}
	inst, err := s.resolveInstallation(ctx, assignment.OrgID, assignment.InstallationID)
	if err != nil {
		return fmt.Errorf("get installation: %w", err)
	}
	if inst.RootGroupID == nil {
		return fmt.Errorf("installation has no root_group_id configured")
	}

	// ── resolve + validate the template (once; persists template_project_id
	// back onto the assignment the first time it's only given as a path) ──
	template, err := s.resolveTemplateProject(ctx, client, assignment)
	if err != nil {
		return fmt.Errorf("resolve template project: %w", err)
	}

	// ── ensure the assignment's subgroup exists (once per assignment) ──
	groupID := assignment.GitlabGroupID
	if groupID == nil {
		groupPath := "asg-" + assignment.ID
		group, err := client.CreateGroup(ctx, assignment.Title, groupPath, *inst.RootGroupID, assignment.Visibility)
		if err != nil {
			return fmt.Errorf("create assignment subgroup: %w", err)
		}
		if err := s.repo.SetAssignmentGroup(ctx, assignment.ID, group.ID, group.FullPath); err != nil {
			return fmt.Errorf("persist assignment subgroup: %w", err)
		}
		groupID = &group.ID
	}

	// ── ensure this team's fork exists ──
	projectID := team.GitlabProjectID
	if projectID == nil {
		fork, err := client.ForkProject(ctx, template.ID, *groupID, team.Slug, team.Name)
		if err != nil {
			return fmt.Errorf("fork template project: %w", err)
		}
		if err := s.repo.SetTeamForkResult(ctx, team.ID, fork.ID, fork.PathWithNamespace, fork.WebURL); err != nil {
			return fmt.Errorf("persist forked project: %w", err)
		}
		projectID = &fork.ID

		// Forks inherit the source's visibility by default; force it back to
		// the assignment's configured visibility (never public — §0 decision #3).
		if _, err := client.UpdateProject(ctx, *projectID, assignment.Visibility); err != nil {
			return fmt.Errorf("set fork visibility: %w", err)
		}
	}

	if err := s.pollImportFinished(ctx, client, *projectID); err != nil {
		return fmt.Errorf("wait for fork import: %w", err)
	}

	if assignment.ProtectDefaultBranch {
		if err := client.ProtectBranch(ctx, *projectID, assignment.DefaultBranch, AccessLevelDeveloper, AccessLevelMaintainer); err != nil {
			return fmt.Errorf("protect default branch: %w", err)
		}
	}

	// ── register the activity webhook (once per team) ──
	if team.GitlabHookID == nil {
		if err := s.registerTeamWebhook(ctx, client, team, *projectID, assignment.InstallationID); err != nil {
			return fmt.Errorf("register webhook: %w", err)
		}
	}

	if err := s.SyncTeamMembers(ctx, team.ID); err != nil {
		return fmt.Errorf("sync members: %w", err)
	}
	return nil
}

// registerTeamWebhook registers the org's Batch 3 activity hook
// (push/merge_requests/pipeline/issues/note events — see
// client_hooks.go's AddProjectHook) against a freshly forked team project
// and persists the resulting hook ID. Idempotent to call again: guarded by
// team.GitlabHookID == nil in provisionTeamSteps above, so a retry after a
// partial failure never registers a second hook.
func (s *Service) registerTeamWebhook(ctx context.Context, client *Client, team *ProjectTeam, projectID int64, installationID *string) error {
	secret, instID, err := s.ensureWebhookSecret(ctx, team.OrgID, installationID)
	if err != nil {
		return fmt.Errorf("ensure webhook secret: %w", err)
	}
	hook, err := client.AddProjectHook(ctx, projectID, s.webhookURL(), secret)
	if err != nil {
		return fmt.Errorf("add project hook: %w", err)
	}
	if err := s.repo.SetTeamHookID(ctx, team.ID, hook.ID); err != nil {
		return fmt.Errorf("persist hook id: %w", err)
	}
	// A hook now genuinely exists for this installation — stop treating it as
	// poll-only (see SetInstallationWebhookMode's own doc comment). Best-effort:
	// a failure here doesn't undo the hook registration above.
	if err := s.repo.SetInstallationWebhookMode(ctx, instID, "webhook"); err != nil {
		slog.ErrorContext(ctx, "gitlab: set installation webhook mode failed", "installation_id", instID, "error", err)
	}
	return nil
}

// ensureWebhookSecret returns the resolved installation's webhook secret in
// plaintext (and its ID, so the caller doesn't need a second lookup),
// generating and persisting one (encrypted via s.vault) the first time it's
// needed — installations created before Batch 3 have no secret on file yet,
// so this is lazy rather than only ever set at connect time.
func (s *Service) ensureWebhookSecret(ctx context.Context, orgID string, installationID *string) (secret, resolvedInstallationID string, err error) {
	inst, err := s.resolveInstallation(ctx, orgID, installationID)
	if err != nil {
		return "", "", fmt.Errorf("get installation: %w", err)
	}
	if inst.WebhookSecretEnc != nil {
		dec, err := s.vault.Decrypt(inst.WebhookSecretEnc)
		if err != nil {
			return "", "", fmt.Errorf("decrypt webhook secret: %w", err)
		}
		return string(dec), inst.ID, nil
	}

	secret, err = randomState() // reuses oauth.go's random-hex generator; same entropy needs, no reason for a second implementation
	if err != nil {
		return "", "", fmt.Errorf("generate webhook secret: %w", err)
	}
	enc, err := s.vault.Encrypt([]byte(secret))
	if err != nil {
		return "", "", fmt.Errorf("encrypt webhook secret: %w", err)
	}
	if err := s.repo.SetInstallationWebhookSecret(ctx, inst.ID, enc); err != nil {
		return "", "", fmt.Errorf("persist webhook secret: %w", err)
	}
	return secret, inst.ID, nil
}

// webhookURL is the public endpoint GitLab delivers project hook events to —
// see handler_webhook.go / routes.go's RegisterPublicRoutes.
func (s *Service) webhookURL() string {
	return s.cfg.BackendURL + "/api/gitlab/webhook"
}

// resolveTemplateProject looks up the assignment's template project — by
// numeric ID if one is already on file, or by path (persisting the resolved
// ID back onto the assignment) when the assignment was only ever given a
// path. Also enforces kind-herding-cookie.md §0 decision #3: the template
// must be private or internal, never public, since a public template would
// leak into the visibility of every team's fork.
func (s *Service) resolveTemplateProject(ctx context.Context, client *Client, assignment *ProjectAssignment) (*Project, error) {
	var project *Project
	var err error
	if assignment.TemplateProjectID != nil {
		project, err = client.GetProject(ctx, *assignment.TemplateProjectID)
	} else {
		project, err = client.GetProjectByPath(ctx, *assignment.TemplateProjectPath)
	}
	if err != nil {
		return nil, fmt.Errorf("look up template project: %w", err)
	}
	if project.Visibility == "public" {
		return nil, fmt.Errorf("template project %q is public — it must be private or internal before any team can fork it", project.PathWithNamespace)
	}
	if assignment.TemplateProjectID == nil {
		if err := s.repo.SetAssignmentTemplateID(ctx, assignment.ID, project.ID); err != nil {
			return nil, fmt.Errorf("persist resolved template project id: %w", err)
		}
	}
	return project, nil
}

const (
	importPollInterval = 3 * time.Second
	importPollAttempts = 30
)

// pollImportFinished waits for a fresh fork's import_status to leave the
// "in progress" states. GitLab omits import_status entirely (empty string)
// or reports "none" for forks that complete synchronously — both are
// treated the same as "finished".
func (s *Service) pollImportFinished(ctx context.Context, client *Client, projectID int64) error {
	for attempt := 0; attempt < importPollAttempts; attempt++ {
		project, err := client.GetProject(ctx, projectID)
		if err != nil {
			return err
		}
		switch project.ImportStatus {
		case "", "none", "finished":
			return nil
		case "failed":
			return fmt.Errorf("gitlab reported import failed for project %d", projectID)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(importPollInterval):
		}
	}
	return fmt.Errorf("import for project %d did not finish within %d attempts", projectID, importPollAttempts)
}

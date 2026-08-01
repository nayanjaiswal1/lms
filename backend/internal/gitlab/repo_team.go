package gitlab

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/mindforge/backend/internal/db"
)

// ─── project_assignments ───────────────────────────────────────────────────

const assignmentColumns = `
	id, org_id, batch_id, course_id, lab_id, title, slug, description,
	template_project_id, template_project_path, gitlab_group_id, gitlab_group_path,
	installation_id, visibility, required_approvals, protect_default_branch, default_branch,
	starts_at, due_at, status, created_by, created_at, updated_at`

func scanAssignment(row pgx.Row) (*ProjectAssignment, error) {
	var a ProjectAssignment
	err := row.Scan(
		&a.ID, &a.OrgID, &a.BatchID, &a.CourseID, &a.LabID, &a.Title, &a.Slug, &a.Description,
		&a.TemplateProjectID, &a.TemplateProjectPath, &a.GitlabGroupID, &a.GitlabGroupPath,
		&a.InstallationID, &a.Visibility, &a.RequiredApprovals, &a.ProtectDefaultBranch, &a.DefaultBranch,
		&a.StartsAt, &a.DueAt, &a.Status, &a.CreatedBy, &a.CreatedAt, &a.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan assignment: %w", err)
	}
	return &a, nil
}

// CreateAssignment inserts a new draft assignment.
func (r *Repo) CreateAssignment(ctx context.Context, a ProjectAssignment) (*ProjectAssignment, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_assignments
			(org_id, batch_id, course_id, lab_id, title, slug, description,
			 template_project_id, template_project_path, installation_id, visibility,
			 required_approvals, protect_default_branch, default_branch,
			 starts_at, due_at, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
		 RETURNING `+assignmentColumns,
		a.OrgID, a.BatchID, a.CourseID, a.LabID, a.Title, a.Slug, a.Description,
		a.TemplateProjectID, a.TemplateProjectPath, a.InstallationID, a.Visibility,
		a.RequiredApprovals, a.ProtectDefaultBranch, a.DefaultBranch,
		a.StartsAt, a.DueAt, a.CreatedBy,
	)
	assignment, err := scanAssignment(row)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("gitlab: create assignment: %w", err)
	}
	return assignment, nil
}

// GetAssignment returns a single org-scoped assignment.
func (r *Repo) GetAssignment(ctx context.Context, orgID, id string) (*ProjectAssignment, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+assignmentColumns+` FROM project_assignments WHERE id = $1 AND org_id = $2`, id, orgID)
	return scanAssignment(row)
}

// GetAssignmentByID returns an assignment by id alone, with no org scoping —
// used internally by job handlers, which only carry a team_id/assignment_id
// payload and resolve org_id from the row itself, not from a request's claims.
func (r *Repo) GetAssignmentByID(ctx context.Context, id string) (*ProjectAssignment, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+assignmentColumns+` FROM project_assignments WHERE id = $1`, id)
	return scanAssignment(row)
}

// ListAssignments lists an org's assignments, optionally filtered to one batch.
func (r *Repo) ListAssignments(ctx context.Context, orgID string, batchID *string) ([]ProjectAssignment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+assignmentColumns+` FROM project_assignments
		 WHERE org_id = $1 AND ($2::uuid IS NULL OR batch_id = $2)
		 ORDER BY created_at DESC`,
		orgID, batchID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list assignments: %w", err)
	}
	defer rows.Close()

	out := []ProjectAssignment{}
	for rows.Next() {
		a, err := scanAssignment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *a)
	}
	return out, rows.Err()
}

// UpdateAssignment applies a partial patch (nil fields left untouched).
func (r *Repo) UpdateAssignment(ctx context.Context, orgID, id string, p AssignmentPatch) (*ProjectAssignment, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_assignments SET
			title = COALESCE($3, title),
			description = COALESCE($4, description),
			visibility = COALESCE($5, visibility),
			required_approvals = COALESCE($6, required_approvals),
			protect_default_branch = COALESCE($7, protect_default_branch),
			default_branch = COALESCE($8, default_branch),
			starts_at = COALESCE($9, starts_at),
			due_at = COALESCE($10, due_at),
			updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+assignmentColumns,
		id, orgID, p.Title, p.Description, p.Visibility, p.RequiredApprovals,
		p.ProtectDefaultBranch, p.DefaultBranch, p.StartsAt, p.DueAt,
	)
	a, err := scanAssignment(row)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: update assignment: %w", err)
	}
	return a, nil
}

// DeleteAssignment hard-deletes a draft assignment (cascades to its teams).
// Restricted to status='draft' — once published, real GitLab groups/forks
// exist that a silent DB-only delete would orphan with no record left
// behind; archiving (not deleting) is the right action for a live assignment,
// and isn't part of Batch 2's scope.
func (r *Repo) DeleteAssignment(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM project_assignments WHERE id = $1 AND org_id = $2 AND status = 'draft'`,
		id, orgID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: delete assignment: %w", err)
	}
	if tag.RowsAffected() == 0 {
		var exists bool
		_ = r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM project_assignments WHERE id = $1 AND org_id = $2)`, id, orgID).Scan(&exists)
		if !exists {
			return ErrNotFound
		}
		return ErrConflict
	}
	return nil
}

// SetAssignmentStatus transitions an assignment from `from` to `to`, failing
// with ErrConflict if its current status doesn't match `from` (e.g. publish
// called twice) and ErrNotFound if the assignment doesn't exist at all.
func (r *Repo) SetAssignmentStatus(ctx context.Context, orgID, id, from, to string) (*ProjectAssignment, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_assignments SET status = $4, updated_at = now()
		 WHERE id = $1 AND org_id = $2 AND status = $3
		 RETURNING `+assignmentColumns,
		id, orgID, from, to,
	)
	a, err := scanAssignment(row)
	if err == nil {
		return a, nil
	}
	if !errors.Is(err, ErrNotFound) {
		return nil, err
	}
	if _, getErr := r.GetAssignment(ctx, orgID, id); getErr != nil {
		return nil, getErr
	}
	return nil, ErrConflict
}

// SetAssignmentTemplateID persists a template project's numeric ID the
// first time it's resolved from a path-only assignment (see
// Service.resolveTemplateProject), so later provisioning runs and reprovision
// calls don't need to re-resolve the path against GitLab every time.
func (r *Repo) SetAssignmentTemplateID(ctx context.Context, assignmentID string, templateProjectID int64) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_assignments SET template_project_id = $2, updated_at = now() WHERE id = $1`,
		assignmentID, templateProjectID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set assignment template id: %w", err)
	}
	return nil
}

// SetAssignmentGroup persists the GitLab subgroup created for this
// assignment the first time any of its teams is provisioned.
// SetAssignmentInstallation pins (or, when installationID is nil, clears —
// reverting to the org's default installation) which pool installation this
// assignment's teams provision against. Org-scoped: callable directly from a
// request handler (unlike SetAssignmentGroup below, only ever called from
// the already-org-validated provisioning job path), so it must not let one
// org repoint another org's assignment.
func (r *Repo) SetAssignmentInstallation(ctx context.Context, orgID, id string, installationID *string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE project_assignments SET installation_id = $3, updated_at = now() WHERE id = $1 AND org_id = $2`,
		id, orgID, installationID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set assignment installation: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repo) SetAssignmentGroup(ctx context.Context, assignmentID string, groupID int64, groupPath string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_assignments SET gitlab_group_id = $2, gitlab_group_path = $3, updated_at = now() WHERE id = $1`,
		assignmentID, groupID, groupPath,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set assignment group: %w", err)
	}
	return nil
}

// ─── project_teams ──────────────────────────────────────────────────────────

const teamColumns = `
	id, org_id, assignment_id, name, slug, gitlab_project_id, gitlab_project_path,
	gitlab_web_url, gitlab_hook_id, pages_url, provision_status, provision_error,
	provisioned_at, created_by, created_at, updated_at`

func scanTeam(row pgx.Row) (*ProjectTeam, error) {
	var t ProjectTeam
	err := row.Scan(
		&t.ID, &t.OrgID, &t.AssignmentID, &t.Name, &t.Slug, &t.GitlabProjectID, &t.GitlabProjectPath,
		&t.GitlabWebURL, &t.GitlabHookID, &t.PagesURL, &t.ProvisionStatus, &t.ProvisionError,
		&t.ProvisionedAt, &t.CreatedBy, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan team: %w", err)
	}
	return &t, nil
}

// CreateTeam inserts a new team under an assignment, provision_status='pending'.
func (r *Repo) CreateTeam(ctx context.Context, t ProjectTeam) (*ProjectTeam, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_teams (org_id, assignment_id, name, slug, created_by)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING `+teamColumns,
		t.OrgID, t.AssignmentID, t.Name, t.Slug, t.CreatedBy,
	)
	team, err := scanTeam(row)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("gitlab: create team: %w", err)
	}
	return team, nil
}

// GetTeam returns a single org-scoped team.
func (r *Repo) GetTeam(ctx context.Context, orgID, teamID string) (*ProjectTeam, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+teamColumns+` FROM project_teams WHERE id = $1 AND org_id = $2`, teamID, orgID)
	return scanTeam(row)
}

// GetTeamByID returns a team by id alone — used internally by job handlers
// (see GetAssignmentByID's own doc comment for why).
func (r *Repo) GetTeamByID(ctx context.Context, teamID string) (*ProjectTeam, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+teamColumns+` FROM project_teams WHERE id = $1`, teamID)
	return scanTeam(row)
}

// ListTeams lists every team under an assignment.
func (r *Repo) ListTeams(ctx context.Context, orgID, assignmentID string) ([]ProjectTeam, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+teamColumns+` FROM project_teams
		 WHERE org_id = $1 AND assignment_id = $2
		 ORDER BY created_at`,
		orgID, assignmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list teams: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeam{}
	for rows.Next() {
		t, err := scanTeam(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

// ListTeamsNeedingSync returns every provisioned team (gitlab_project_id set)
// that has at least one member row not yet reconciled with GitLab — the
// gitlab.sync_members cron sweep's own work queue.
func (r *Repo) ListTeamsNeedingSync(ctx context.Context) ([]ProjectTeam, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+teamColumns+` FROM project_teams t
		 WHERE t.gitlab_project_id IS NOT NULL
		   AND EXISTS (
		     SELECT 1 FROM project_team_members m
		     WHERE m.team_id = t.id AND m.sync_status <> 'synced'
		   )
		 ORDER BY t.created_at`,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list teams needing sync: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeam{}
	for rows.Next() {
		t, err := scanTeam(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

// GetTeamByGitlabProjectID resolves a team by its forked GitLab project's
// numeric ID (UNIQUE) — used by the webhook receiver to map an inbound
// payload's project_id to the org/team it belongs to.
func (r *Repo) GetTeamByGitlabProjectID(ctx context.Context, gitlabProjectID int64) (*ProjectTeam, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+teamColumns+` FROM project_teams WHERE gitlab_project_id = $1`, gitlabProjectID)
	return scanTeam(row)
}

// SetTeamHookID persists the numeric ID of the project webhook registered
// during provisioning (see Service.provisionTeamSteps) — checked on every
// reprovision so a team's hook is only ever registered once.
func (r *Repo) SetTeamHookID(ctx context.Context, teamID string, hookID int64) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_teams SET gitlab_hook_id = $2, updated_at = now() WHERE id = $1`,
		teamID, hookID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set team hook id: %w", err)
	}
	return nil
}

// ListTeamsNeedingPoll returns every provisioned team whose installation
// runs webhook_mode='poll' (no reachable webhook at all), or that has
// received no webhook event in the last staleThreshold — i.e. a hook that
// may be silently broken. The gitlab.poll_sync cron job's own work queue.
func (r *Repo) ListTeamsNeedingPoll(ctx context.Context, staleThreshold time.Duration) ([]ProjectTeam, error) {
	staleInterval := fmt.Sprintf("%d seconds", int(staleThreshold.Seconds()))
	rows, err := r.pool.Query(ctx,
		`SELECT t.id, t.org_id, t.assignment_id, t.name, t.slug, t.gitlab_project_id, t.gitlab_project_path,
		        t.gitlab_web_url, t.gitlab_hook_id, t.pages_url, t.provision_status, t.provision_error,
		        t.provisioned_at, t.created_by, t.created_at, t.updated_at
		 FROM project_teams t
		 JOIN gitlab_installations i ON i.org_id = t.org_id
		 WHERE t.gitlab_project_id IS NOT NULL
		   AND (
		     i.webhook_mode = 'poll'
		     OR NOT EXISTS (
		       SELECT 1 FROM gitlab_webhook_events e
		       WHERE e.project_id = t.gitlab_project_id AND e.received_at > now() - $1::interval
		     )
		   )
		 ORDER BY t.created_at`,
		staleInterval,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list teams needing poll: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeam{}
	for rows.Next() {
		t, err := scanTeam(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

// UpdateTeam applies a partial patch to a team's name/slug.
func (r *Repo) UpdateTeam(ctx context.Context, orgID, teamID string, p TeamPatch) (*ProjectTeam, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_teams SET
			name = COALESCE($3, name),
			slug = COALESCE($4, slug),
			updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+teamColumns,
		teamID, orgID, p.Name, p.Slug,
	)
	t, err := scanTeam(row)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, ErrNotFound
		}
		if db.IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("gitlab: update team: %w", err)
	}
	return t, nil
}

// DeleteTeam hard-deletes MindForge's own team row (cascades its members).
// It does not archive or delete the underlying GitLab project — that would
// silently destroy a team's real repo history from a simple DB action;
// GitLab-side cleanup is a deliberate, explicit follow-up action this batch
// doesn't build (no client.ArchiveProject call here).
func (r *Repo) DeleteTeam(ctx context.Context, orgID, teamID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM project_teams WHERE id = $1 AND org_id = $2`, teamID, orgID)
	if err != nil {
		return fmt.Errorf("gitlab: delete team: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetTeamProvisionStatus records the provisioning job's current state.
func (r *Repo) SetTeamProvisionStatus(ctx context.Context, teamID, status string, provisionError *string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_teams SET provision_status = $2, provision_error = $3, updated_at = now() WHERE id = $1`,
		teamID, status, provisionError,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set team provision status: %w", err)
	}
	return nil
}

// SetTeamForkResult persists the newly-forked GitLab project's identity.
func (r *Repo) SetTeamForkResult(ctx context.Context, teamID string, gitlabProjectID int64, path, webURL string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_teams SET gitlab_project_id = $2, gitlab_project_path = $3, gitlab_web_url = $4, updated_at = now() WHERE id = $1`,
		teamID, gitlabProjectID, path, webURL,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set team fork result: %w", err)
	}
	return nil
}

// UpdateTeamPagesURL records a freshly (re)detected GitLab Pages URL — see
// service_webhook.go's maybeRefreshPagesURL, called after a pipeline
// succeeds (Batch 6).
func (r *Repo) UpdateTeamPagesURL(ctx context.Context, teamID, pagesURL string) error {
	_, err := r.pool.Exec(ctx, `UPDATE project_teams SET pages_url = $2, updated_at = now() WHERE id = $1`, teamID, pagesURL)
	if err != nil {
		return fmt.Errorf("gitlab: update team pages url: %w", err)
	}
	return nil
}

// MarkTeamReady marks a team's provisioning fully complete.
func (r *Repo) MarkTeamReady(ctx context.Context, teamID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_teams SET provision_status = 'ready', provision_error = NULL, provisioned_at = now(), updated_at = now() WHERE id = $1`,
		teamID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: mark team ready: %w", err)
	}
	return nil
}

// ─── project_team_members ───────────────────────────────────────────────────

const memberColumns = `
	team_id, user_id, assignment_id, role, gitlab_access_level,
	sync_status, sync_error, synced_at, added_by, added_at`

func scanMember(row pgx.Row) (*ProjectTeamMember, error) {
	var m ProjectTeamMember
	err := row.Scan(
		&m.TeamID, &m.UserID, &m.AssignmentID, &m.Role, &m.GitlabAccessLevel,
		&m.SyncStatus, &m.SyncError, &m.SyncedAt, &m.AddedBy, &m.AddedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan team member: %w", err)
	}
	return &m, nil
}

// AddTeamMember inserts a new roster row, sync_status='pending'. Returns
// ErrAlreadyOnTeam when the composite-FK-backed UNIQUE(assignment_id,
// user_id) constraint rejects the insert (student already on a different
// team for this assignment), or ErrConflict for any other uniqueness
// violation (e.g. re-adding the same user to the same team).
func (r *Repo) AddTeamMember(ctx context.Context, m ProjectTeamMember) (*ProjectTeamMember, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_team_members (team_id, user_id, assignment_id, role, gitlab_access_level, added_by)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING `+memberColumns,
		m.TeamID, m.UserID, m.AssignmentID, m.Role, m.GitlabAccessLevel, m.AddedBy,
	)
	member, err := scanMember(row)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			if pgErr.ConstraintName == "project_team_members_assignment_user_key" {
				return nil, ErrAlreadyOnTeam
			}
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("gitlab: add team member: %w", err)
	}
	return member, nil
}

// GetTeamMember returns one member row.
func (r *Repo) GetTeamMember(ctx context.Context, teamID, userID string) (*ProjectTeamMember, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+memberColumns+` FROM project_team_members WHERE team_id = $1 AND user_id = $2`, teamID, userID)
	return scanMember(row)
}

// ListTeamMembers lists a team's roster, joined with users for display name/email.
func (r *Repo) ListTeamMembers(ctx context.Context, teamID string) ([]ProjectTeamMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT m.team_id, m.user_id, m.assignment_id, m.role, m.gitlab_access_level,
		        m.sync_status, m.sync_error, m.synced_at, m.added_by, m.added_at,
		        u.name, u.email
		 FROM project_team_members m
		 JOIN users u ON u.id = m.user_id
		 WHERE m.team_id = $1
		 ORDER BY m.added_at`,
		teamID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list team members: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeamMember{}
	for rows.Next() {
		var m ProjectTeamMember
		if err := rows.Scan(
			&m.TeamID, &m.UserID, &m.AssignmentID, &m.Role, &m.GitlabAccessLevel,
			&m.SyncStatus, &m.SyncError, &m.SyncedAt, &m.AddedBy, &m.AddedAt,
			&m.Name, &m.Email,
		); err != nil {
			return nil, fmt.Errorf("gitlab: scan team member: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ListMembersNeedingSync returns a team's members not yet successfully added/
// edited on GitLab (pending or previously failed — both worth retrying).
func (r *Repo) ListMembersNeedingSync(ctx context.Context, teamID string) ([]ProjectTeamMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+memberColumns+` FROM project_team_members WHERE team_id = $1 AND sync_status IN ('pending', 'failed')`,
		teamID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list members needing sync: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeamMember{}
	for rows.Next() {
		m, err := scanMember(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *m)
	}
	return out, rows.Err()
}

// ListMembersRemoving returns a team's members flagged for GitLab-side removal.
func (r *Repo) ListMembersRemoving(ctx context.Context, teamID string) ([]ProjectTeamMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+memberColumns+` FROM project_team_members WHERE team_id = $1 AND sync_status = 'removing'`,
		teamID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list members removing: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeamMember{}
	for rows.Next() {
		m, err := scanMember(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *m)
	}
	return out, rows.Err()
}

// MarkMemberRemoving flags a member for GitLab-side removal by the next
// sync_members run rather than deleting the row immediately (see
// SyncStatusRemoving's own doc comment for why).
func (r *Repo) MarkMemberRemoving(ctx context.Context, teamID, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE project_team_members SET sync_status = 'removing', sync_error = NULL WHERE team_id = $1 AND user_id = $2`,
		teamID, userID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: mark member removing: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateMemberSyncResult records the outcome of one add/edit/remove attempt.
func (r *Repo) UpdateMemberSyncResult(ctx context.Context, teamID, userID, status string, syncErr *string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_team_members
		 SET sync_status = $3, sync_error = $4,
		     synced_at = CASE WHEN $3 = 'synced' THEN now() ELSE synced_at END
		 WHERE team_id = $1 AND user_id = $2`,
		teamID, userID, status, syncErr,
	)
	if err != nil {
		return fmt.Errorf("gitlab: update member sync result: %w", err)
	}
	return nil
}

// DeleteTeamMember hard-deletes a roster row — used both when removing a
// member from a not-yet-provisioned team (nothing on GitLab to reconcile
// first) and by SyncTeamMembers once a 'removing' member's GitLab access has
// actually been revoked.
func (r *Repo) DeleteTeamMember(ctx context.Context, teamID, userID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM project_team_members WHERE team_id = $1 AND user_id = $2`, teamID, userID)
	if err != nil {
		return fmt.Errorf("gitlab: delete team member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

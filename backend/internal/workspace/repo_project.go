package workspace

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

const projectColumns = `id, org_id, title, requirement, requirement_version, skills, team_size_min, team_size_max,
	interest_deadline, key_prefix, project_status, brief_status, share_token, share_token_rotated_at,
	accepting_interests, brief_wiki_page_id, team_id, cohort_id, gitlab_enabled, sprints_enabled, wip_limit, item_seq,
	health_thresholds, activated_at, brief_agreed_at, completed_at, feedback_closes_at, created_by, created_at, updated_at`

func scanProject(row pgx.Row) (*Project, error) {
	var p Project
	var health []byte
	err := row.Scan(
		&p.ID, &p.OrgID, &p.Title, &p.Requirement, &p.RequirementVersion, &p.Skills, &p.TeamSizeMin, &p.TeamSizeMax,
		&p.InterestDeadline, &p.KeyPrefix, &p.ProjectStatus, &p.BriefStatus, &p.ShareToken, &p.ShareTokenRotatedAt,
		&p.AcceptingInterests, &p.BriefWikiPageID, &p.TeamID, &p.CohortID, &p.GitlabEnabled, &p.SprintsEnabled, &p.WipLimit, &p.ItemSeq,
		&health, &p.ActivatedAt, &p.BriefAgreedAt, &p.CompletedAt, &p.FeedbackClosesAt, &p.CreatedBy, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan project: %w", err)
	}
	if len(health) > 0 {
		if err := json.Unmarshal(health, &p.HealthThresholds); err != nil {
			return nil, fmt.Errorf("workspace: unmarshal health_thresholds: %w", err)
		}
	}
	return &p, nil
}

// InsertProject inserts the workspace_projects row. p's zero-value fields
// (ProjectStatus, BriefStatus, RequirementVersion, WipLimit, HealthThresholds)
// take their column defaults.
func (r *Repo) InsertProject(ctx context.Context, db DBTX, p Project) (*Project, error) {
	skills := p.Skills
	if skills == nil {
		skills = []string{}
	}
	row := db.QueryRow(ctx,
		`INSERT INTO workspace_projects
			(org_id, title, requirement, skills, team_size_min, team_size_max, interest_deadline,
			 key_prefix, share_token, gitlab_enabled, sprints_enabled, created_by, team_id, cohort_id)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		 RETURNING `+projectColumns,
		p.OrgID, p.Title, p.Requirement, skills, p.TeamSizeMin, p.TeamSizeMax, p.InterestDeadline,
		p.KeyPrefix, p.ShareToken, p.GitlabEnabled, p.SprintsEnabled, p.CreatedBy, p.TeamID, p.CohortID,
	)
	return scanProject(row)
}

// GetProject returns a project scoped to its org — defense in depth on top
// of the ProjectCtx the caller already resolved.
func (r *Repo) GetProject(ctx context.Context, db DBTX, orgID, projectID string) (*Project, error) {
	return scanProject(db.QueryRow(ctx,
		`SELECT `+projectColumns+` FROM workspace_projects WHERE id = $1 AND org_id = $2`,
		projectID, orgID))
}

// GetProjectOrgID resolves a project id straight to its org id, with no org
// already in hand to scope by — RequestDocChange's own case, called from
// inside wiki's UpdatePage hook with only a page id (see GetFeatureByDocPage).
func (r *Repo) GetProjectOrgID(ctx context.Context, db DBTX, projectID string) (string, error) {
	var orgID string
	err := db.QueryRow(ctx, `SELECT org_id FROM workspace_projects WHERE id = $1`, projectID).Scan(&orgID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("workspace: get project org id: %w", err)
	}
	return orgID, nil
}

// projectColumnsQualified is projectColumns qualified with "p." — needed only
// by GetProjectByShareToken, which joins organizations and would otherwise
// have an ambiguous "id" between the two tables.
const projectColumnsQualified = `p.id, p.org_id, p.title, p.requirement, p.requirement_version, p.skills, p.team_size_min, p.team_size_max,
	p.interest_deadline, p.key_prefix, p.project_status, p.brief_status, p.share_token, p.share_token_rotated_at,
	p.accepting_interests, p.brief_wiki_page_id, p.team_id, p.cohort_id, p.gitlab_enabled, p.sprints_enabled, p.wip_limit, p.item_seq,
	p.health_thresholds, p.activated_at, p.brief_agreed_at, p.completed_at, p.feedback_closes_at, p.created_by, p.created_at, p.updated_at`

// GetProjectByShareToken resolves the public share page's project, plus its
// org's display name. Rotating the token overwrites this row's own
// share_token, so an old link simply stops matching (02 §4.2).
func (r *Repo) GetProjectByShareToken(ctx context.Context, db DBTX, shareToken string) (*Project, string, error) {
	var orgName string
	var p Project
	var health []byte
	err := db.QueryRow(ctx,
		`SELECT `+projectColumnsQualified+`, o.name FROM workspace_projects p JOIN organizations o ON o.id = p.org_id WHERE p.share_token = $1`,
		shareToken,
	).Scan(
		&p.ID, &p.OrgID, &p.Title, &p.Requirement, &p.RequirementVersion, &p.Skills, &p.TeamSizeMin, &p.TeamSizeMax,
		&p.InterestDeadline, &p.KeyPrefix, &p.ProjectStatus, &p.BriefStatus, &p.ShareToken, &p.ShareTokenRotatedAt,
		&p.AcceptingInterests, &p.BriefWikiPageID, &p.TeamID, &p.CohortID, &p.GitlabEnabled, &p.SprintsEnabled, &p.WipLimit, &p.ItemSeq,
		&health, &p.ActivatedAt, &p.BriefAgreedAt, &p.CompletedAt, &p.FeedbackClosesAt, &p.CreatedBy, &p.CreatedAt, &p.UpdatedAt,
		&orgName,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	if err != nil {
		return nil, "", fmt.Errorf("workspace: get project by share token: %w", err)
	}
	if len(health) > 0 {
		if err := json.Unmarshal(health, &p.HealthThresholds); err != nil {
			return nil, "", fmt.Errorf("workspace: unmarshal health_thresholds: %w", err)
		}
	}
	return &p, orgName, nil
}

// LockProject SELECTs ... FOR UPDATE inside tx — the lock a status change or
// seat-affecting write must hold across both its check and its write (02 §8).
func (r *Repo) LockProject(ctx context.Context, tx pgx.Tx, projectID string) (*Project, error) {
	return scanProject(tx.QueryRow(ctx,
		`SELECT `+projectColumns+` FROM workspace_projects WHERE id = $1 FOR UPDATE`, projectID))
}

// KeyPrefixTaken reports whether org+prefix is already used by another
// project. excludeProjectID, if non-empty, ignores that project's own row
// (UpdateProject keeping its existing prefix).
func (r *Repo) KeyPrefixTaken(ctx context.Context, db DBTX, orgID, prefix, excludeProjectID string) (bool, error) {
	var taken bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM workspace_projects WHERE org_id = $1 AND key_prefix = $2 AND ($3 = '' OR id::text <> $3))`,
		orgID, prefix, excludeProjectID,
	).Scan(&taken)
	if err != nil {
		return false, fmt.Errorf("workspace: check key prefix: %w", err)
	}
	return taken, nil
}

// projectPatch is UpdateProject's fully-resolved set of column values —
// service_project.go fills every field from the existing row COALESCEd with
// the request's overrides, so this stays a plain UPDATE with no per-field
// COALESCE branching (skills/interest_deadline can't distinguish "clear" from
// "unset" through COALESCE alone; the service already resolved that).
type projectPatch struct {
	Title              string
	Skills             []string
	TeamSizeMin        int
	TeamSizeMax        int
	InterestDeadline   *time.Time
	KeyPrefix          string
	AcceptingInterests bool
	GitlabEnabled      bool
	SprintsEnabled     bool
	WipLimit           int
	HealthThresholds   HealthThreshold
}

// UpdateProject applies a fully-resolved patch.
func (r *Repo) UpdateProject(ctx context.Context, db DBTX, projectID string, p projectPatch) (*Project, error) {
	health, err := json.Marshal(p.HealthThresholds)
	if err != nil {
		return nil, fmt.Errorf("workspace: marshal health_thresholds: %w", err)
	}
	skills := p.Skills
	if skills == nil {
		skills = []string{}
	}
	row := db.QueryRow(ctx,
		`UPDATE workspace_projects SET
			title = $2, skills = $3, team_size_min = $4, team_size_max = $5, interest_deadline = $6,
			key_prefix = $7, accepting_interests = $8, gitlab_enabled = $9, sprints_enabled = $10,
			wip_limit = $11, health_thresholds = $12, updated_at = now()
		 WHERE id = $1
		 RETURNING `+projectColumns,
		projectID, p.Title, skills, p.TeamSizeMin, p.TeamSizeMax, p.InterestDeadline,
		p.KeyPrefix, p.AcceptingInterests, p.GitlabEnabled, p.SprintsEnabled, p.WipLimit, health,
	)
	return scanProject(row)
}

// UpdateProjectStatus performs `UPDATE ... WHERE project_status = from`
// (0 rows means another request already moved it — ErrConflict) and stamps
// the lifecycle timestamps a transition triggers. tx must already hold the
// project row's lock (LockProject).
func (r *Repo) UpdateProjectStatus(ctx context.Context, tx pgx.Tx, projectID, from, to string, setBriefClarifying, setActivatedAt, setCompleted bool, feedbackWindow time.Duration) (*Project, error) {
	row := tx.QueryRow(ctx,
		`UPDATE workspace_projects SET
			project_status = $3,
			brief_status = CASE WHEN $4::boolean AND brief_status <> 'agreed' THEN 'clarifying' ELSE brief_status END,
			activated_at = CASE WHEN $5::boolean AND activated_at IS NULL THEN now() ELSE activated_at END,
			completed_at = CASE WHEN $6::boolean THEN now() ELSE completed_at END,
			feedback_closes_at = CASE WHEN $6::boolean THEN now() + make_interval(secs => $7::double precision) ELSE feedback_closes_at END,
			updated_at = now()
		 WHERE id = $1 AND project_status = $2
		 RETURNING `+projectColumns,
		projectID, from, to, setBriefClarifying, setActivatedAt, setCompleted, feedbackWindow.Seconds(),
	)
	p, err := scanProject(row)
	if errors.Is(err, ErrNotFound) {
		return nil, ErrConflict
	}
	return p, err
}

// RotateShareToken overwrites the share token unconditionally — the old link
// 404s on its very next use (02 §4.2).
func (r *Repo) RotateShareToken(ctx context.Context, db DBTX, projectID, newToken string) error {
	tag, err := db.Exec(ctx,
		`UPDATE workspace_projects SET share_token = $2, share_token_rotated_at = now(), updated_at = now() WHERE id = $1`,
		projectID, newToken,
	)
	if err != nil {
		return fmt.Errorf("workspace: rotate share token: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetProjectWikiSpace stores the wiki_space_id/brief_wiki_page_id pointer.
// Phase 1 only wires the space; brief_wiki_page_id stays NULL until Phase 3.
func (r *Repo) GetProjectWikiSpace(ctx context.Context, db DBTX, projectID string) (id, slug *string, err error) {
	err = db.QueryRow(ctx, `SELECT id, slug FROM wiki_spaces WHERE project_id = $1`, projectID).Scan(&id, &slug)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, nil
	}
	if err != nil {
		return nil, nil, fmt.Errorf("workspace: get project wiki space: %w", err)
	}
	return id, slug, nil
}

// ─── requirement versions ──────────────────────────────────────────────────

// InsertRequirementVersion appends a requirement_versions row.
func (r *Repo) InsertRequirementVersion(ctx context.Context, db DBTX, projectID string, version int, text, createdBy string) error {
	var createdByArg any
	if createdBy != "" {
		createdByArg = createdBy
	}
	if _, err := db.Exec(ctx,
		`INSERT INTO requirement_versions (project_id, version, raw_requirement, created_by) VALUES ($1,$2,$3,$4)`,
		projectID, version, text, createdByArg,
	); err != nil {
		return fmt.Errorf("workspace: insert requirement version: %w", err)
	}
	return nil
}

// ListRequirementVersions returns every version, newest first.
func (r *Repo) ListRequirementVersions(ctx context.Context, db DBTX, projectID string) ([]RequirementVersion, error) {
	rows, err := db.Query(ctx,
		`SELECT version, raw_requirement, created_by, created_at FROM requirement_versions
		  WHERE project_id = $1 ORDER BY version DESC`, projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list requirement versions: %w", err)
	}
	defer rows.Close()

	out := []RequirementVersion{}
	for rows.Next() {
		var v RequirementVersion
		if err := rows.Scan(&v.Version, &v.RawRequirement, &v.CreatedBy, &v.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan requirement version: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// UpdateRequirementText sets the current requirement text/version and,
// unless the brief was already agreed on a later version, reopens brief
// review by dropping brief_status back to clarifying.
func (r *Repo) UpdateRequirementText(ctx context.Context, db DBTX, projectID, text string, newVersion int) (*Project, error) {
	row := db.QueryRow(ctx,
		`UPDATE workspace_projects SET
			requirement = $2, requirement_version = $3,
			brief_status = CASE WHEN brief_status = 'agreed' THEN 'clarifying' ELSE brief_status END,
			updated_at = now()
		 WHERE id = $1
		 RETURNING `+projectColumns,
		projectID, text, newVersion,
	)
	return scanProject(row)
}

// ─── list ───────────────────────────────────────────────────────────────────

const projectSummaryColumns = `p.id, p.title, p.key_prefix, p.project_status, p.brief_status,
	COALESCE(pm.role, 'owner') AS my_role,
	(SELECT count(*) FROM project_members m2 WHERE m2.project_id = p.id AND m2.status = 'active') AS member_count,
	p.team_size_max, p.created_at, p.team_id, pt.provision_status`

func scanProjectSummary(row pgx.Row) (ProjectSummary, error) {
	var s ProjectSummary
	err := row.Scan(&s.ID, &s.Title, &s.KeyPrefix, &s.ProjectStatus, &s.BriefStatus, &s.MyRole, &s.MemberCount, &s.TeamSizeMax, &s.CreatedAt, &s.TeamID, &s.ProvisionStatus)
	return s, err
}

// ListProjects returns every project the caller is an active member of; when
// overseer is true (projects.oversee), every project in the org instead.
func (r *Repo) ListProjects(ctx context.Context, orgID, userID string, overseer bool, cohortID string, cursorAt time.Time, cursorID string, limit int) ([]ProjectSummary, error) {
	var rows pgx.Rows
	var err error
	if cursorID == "" {
		rows, err = r.pool.Query(ctx,
			`SELECT `+projectSummaryColumns+`
			   FROM workspace_projects p
			   LEFT JOIN project_teams pt ON pt.id = p.team_id
			   LEFT JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $2 AND pm.status = 'active'
			  WHERE p.org_id = $1 AND ($3::boolean OR pm.user_id IS NOT NULL)
			    AND ($5 = '' OR p.cohort_id::text = $5)
			  ORDER BY p.created_at ASC, p.id ASC LIMIT $4`,
			orgID, userID, overseer, limit, cohortID)
	} else {
		rows, err = r.pool.Query(ctx,
			`SELECT `+projectSummaryColumns+`
			   FROM workspace_projects p
			   LEFT JOIN project_teams pt ON pt.id = p.team_id
			   LEFT JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $2 AND pm.status = 'active'
			  WHERE p.org_id = $1 AND ($3::boolean OR pm.user_id IS NOT NULL)
			    AND ($7 = '' OR p.cohort_id::text = $7)
			    AND (p.created_at, p.id) > ($5, $6)
			  ORDER BY p.created_at ASC, p.id ASC LIMIT $4`,
			orgID, userID, overseer, limit, cursorAt, cursorID, cohortID)
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: list projects: %w", err)
	}
	defer rows.Close()

	out := []ProjectSummary{}
	for rows.Next() {
		s, err := scanProjectSummary(rows)
		if err != nil {
			return nil, fmt.Errorf("workspace: scan project summary: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ListInvitations returns every project the user has a pending (status
// invited) project_members row on — GET /api/workspaces/invitations.
func (r *Repo) ListInvitations(ctx context.Context, db DBTX, orgID, userID string) ([]ProjectSummary, error) {
	rows, err := db.Query(ctx,
		`SELECT `+projectSummaryColumns+`
		   FROM workspace_projects p
		   LEFT JOIN project_teams pt ON pt.id = p.team_id
		   JOIN project_members pm ON pm.project_id = p.id AND pm.user_id = $2 AND pm.status = 'invited'
		  WHERE p.org_id = $1
		  ORDER BY p.created_at DESC`,
		orgID, userID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list invitations: %w", err)
	}
	defer rows.Close()

	out := []ProjectSummary{}
	for rows.Next() {
		s, err := scanProjectSummary(rows)
		if err != nil {
			return nil, fmt.Errorf("workspace: scan invitation: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// GitlabInfo is the provisioned gitlab project behind a workspace's team.
type GitlabInfo struct {
	WebURL, PagesURL, ProvisionStatus, ProvisionError *string
}

// GetProjectGitlab returns the project_teams gitlab fields for a workspace;
// all nil when it has no team.
func (r *Repo) GetProjectGitlab(ctx context.Context, db DBTX, projectID string) (GitlabInfo, error) {
	var g GitlabInfo
	err := db.QueryRow(ctx,
		`SELECT t.gitlab_web_url, t.pages_url, t.provision_status, t.provision_error
		   FROM workspace_projects p JOIN project_teams t ON t.id = p.team_id WHERE p.id = $1`,
		projectID).Scan(&g.WebURL, &g.PagesURL, &g.ProvisionStatus, &g.ProvisionError)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return g, fmt.Errorf("workspace: get project gitlab: %w", err)
	}
	return g, nil
}

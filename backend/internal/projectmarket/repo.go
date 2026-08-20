package projectmarket

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/db"
)

// Repo is the data-access layer for the project marketplace domain. Every
// method takes an orgID and filters on it, so a caller can never reach
// another org's rows.
type Repo struct {
	pool *pgxpool.Pool
}

// NewRepo constructs a Repo over the shared connection pool.
func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// Domain errors surfaced by the repo and service; the handler maps these to
// HTTP codes.
var (
	// ErrNotFound — row does not exist or is not visible to the org/caller.
	ErrNotFound = errors.New("projectmarket: not found")
	// ErrConflict — a uniqueness or state-transition rule was violated.
	ErrConflict = errors.New("projectmarket: conflict")
	// ErrRequirementClosed — the requirement is not accepting applications
	// (not status=open, or past its application_deadline).
	ErrRequirementClosed = errors.New("projectmarket: this requirement is not accepting applications")
	// ErrAlreadyApplied — the student already has an application against
	// this requirement (project_applications' UNIQUE(requirement_id, user_id)).
	ErrAlreadyApplied = errors.New("projectmarket: you have already applied to this requirement")
)

// ─── project_requirements ──────────────────────────────────────────────────

const requirementColumns = `
	id, org_id, title, brief, required_skills, team_size_min, team_size_max,
	application_deadline, status, created_by, created_at, updated_at`

// requirementColumnsAliased is requirementColumns qualified with "req." — a
// literal duplicate rather than a generic prefixer, since exactly one query
// (ListBoard) needs it.
const requirementColumnsAliased = `
	req.id, req.org_id, req.title, req.brief, req.required_skills, req.team_size_min, req.team_size_max,
	req.application_deadline, req.status, req.created_by, req.created_at, req.updated_at`

func scanRequirement(row pgx.Row) (*ProjectRequirement, error) {
	var req ProjectRequirement
	err := row.Scan(
		&req.ID, &req.OrgID, &req.Title, &req.Brief, &req.RequiredSkills, &req.TeamSizeMin, &req.TeamSizeMax,
		&req.ApplicationDeadline, &req.Status, &req.CreatedBy, &req.CreatedAt, &req.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("projectmarket: scan requirement: %w", err)
	}
	return &req, nil
}

// CreateRequirement inserts a new draft requirement.
func (r *Repo) CreateRequirement(ctx context.Context, req ProjectRequirement) (*ProjectRequirement, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_requirements
			(org_id, title, brief, required_skills, team_size_min, team_size_max, application_deadline, status, created_by)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		 RETURNING `+requirementColumns,
		req.OrgID, req.Title, req.Brief, req.RequiredSkills, req.TeamSizeMin, req.TeamSizeMax,
		req.ApplicationDeadline, req.Status, req.CreatedBy,
	)
	return scanRequirement(row)
}

// GetRequirement returns a single org-scoped requirement.
func (r *Repo) GetRequirement(ctx context.Context, orgID, id string) (*ProjectRequirement, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+requirementColumns+` FROM project_requirements WHERE id = $1 AND org_id = $2`,
		id, orgID,
	)
	return scanRequirement(row)
}

// ListRequirements returns every requirement in the org, newest first — the
// staff management list (all statuses).
func (r *Repo) ListRequirements(ctx context.Context, orgID string) ([]ProjectRequirement, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+requirementColumns+` FROM project_requirements WHERE org_id = $1 ORDER BY created_at DESC`,
		orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("projectmarket: list requirements: %w", err)
	}
	defer rows.Close()

	var out []ProjectRequirement
	for rows.Next() {
		req, err := scanRequirement(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *req)
	}
	return out, rows.Err()
}

// ListBoard returns every open, not-yet-expired requirement plus its
// application_count and, when userID is non-empty, the caller's own
// application status against it — the open board any org member browses.
func (r *Repo) ListBoard(ctx context.Context, orgID, userID string) ([]RequirementBoardRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+requirementColumnsAliased+`,
			COUNT(app.id) AS application_count,
			MAX(CASE WHEN app.user_id = $2 THEN app.status END) AS my_status
		 FROM project_requirements req
		 LEFT JOIN project_applications app ON app.requirement_id = req.id
		 WHERE req.org_id = $1 AND req.status = 'open' AND req.application_deadline > now()
		 GROUP BY req.id
		 ORDER BY req.application_deadline`,
		orgID, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("projectmarket: list board: %w", err)
	}
	defer rows.Close()

	var out []RequirementBoardRow
	for rows.Next() {
		var row RequirementBoardRow
		if err := rows.Scan(
			&row.ID, &row.OrgID, &row.Title, &row.Brief, &row.RequiredSkills, &row.TeamSizeMin, &row.TeamSizeMax,
			&row.ApplicationDeadline, &row.Status, &row.CreatedBy, &row.CreatedAt, &row.UpdatedAt,
			&row.ApplicationCount, &row.MyStatus,
		); err != nil {
			return nil, fmt.Errorf("projectmarket: scan board row: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// UpdateRequirement applies a partial patch to a requirement's editable fields.
func (r *Repo) UpdateRequirement(ctx context.Context, orgID, id string, p RequirementPatch) (*ProjectRequirement, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_requirements SET
			title = COALESCE($3, title),
			brief = COALESCE($4, brief),
			required_skills = COALESCE($5, required_skills),
			team_size_min = COALESCE($6, team_size_min),
			team_size_max = COALESCE($7, team_size_max),
			application_deadline = COALESCE($8, application_deadline),
			updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+requirementColumns,
		id, orgID, p.Title, p.Brief, p.RequiredSkills, p.TeamSizeMin, p.TeamSizeMax, p.ApplicationDeadline,
	)
	return scanRequirement(row)
}

// SetRequirementStatus transitions a requirement from fromStatus to
// toStatus, returning ErrConflict if its current status doesn't match
// fromStatus (mirrors gitlab.Repo.SetAssignmentStatus's own guard).
func (r *Repo) SetRequirementStatus(ctx context.Context, orgID, id, fromStatus, toStatus string) (*ProjectRequirement, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_requirements SET status = $4, updated_at = now()
		 WHERE id = $1 AND org_id = $2 AND status = $3
		 RETURNING `+requirementColumns,
		id, orgID, fromStatus, toStatus,
	)
	req, err := scanRequirement(row)
	if errors.Is(err, ErrNotFound) {
		// Distinguish "doesn't exist" from "exists but wrong status" so the
		// service can return the more useful ErrConflict for the latter.
		if _, getErr := r.GetRequirement(ctx, orgID, id); getErr == nil {
			return nil, ErrConflict
		}
		return nil, ErrNotFound
	}
	return req, err
}

// ─── project_applications ──────────────────────────────────────────────────

const applicationColumns = `
	id, org_id, requirement_id, user_id, motivation, resume_text, status, reviewed_by, reviewed_at, applied_at,
	ai_score, ai_rationale, ai_scored_at`

// applicationColumnsAliased is applicationColumns qualified with "app." — a
// literal duplicate rather than a generic prefixer, since exactly one query
// (ListApplicationsForStaff) needs it.
const applicationColumnsAliased = `
	app.id, app.org_id, app.requirement_id, app.user_id, app.motivation, app.resume_text, app.status,
	app.reviewed_by, app.reviewed_at, app.applied_at, app.ai_score, app.ai_rationale, app.ai_scored_at`

func scanApplication(row pgx.Row) (*ProjectApplication, error) {
	var app ProjectApplication
	err := row.Scan(
		&app.ID, &app.OrgID, &app.RequirementID, &app.UserID, &app.Motivation, &app.ResumeText,
		&app.Status, &app.ReviewedBy, &app.ReviewedAt, &app.AppliedAt,
		&app.AIScore, &app.AIRationale, &app.AIScoredAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("projectmarket: scan application: %w", err)
	}
	return &app, nil
}

// CreateApplication inserts a student's application against an open
// requirement. Returns ErrAlreadyApplied on a UNIQUE(requirement_id,
// user_id) violation.
func (r *Repo) CreateApplication(ctx context.Context, app ProjectApplication) (*ProjectApplication, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_applications (org_id, requirement_id, user_id, motivation, resume_text, status)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING `+applicationColumns,
		app.OrgID, app.RequirementID, app.UserID, app.Motivation, app.ResumeText, app.Status,
	)
	created, err := scanApplication(row)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, ErrAlreadyApplied
		}
		return nil, err
	}
	return created, nil
}

// GetApplication returns a single org-scoped application.
func (r *Repo) GetApplication(ctx context.Context, orgID, id string) (*ProjectApplication, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+applicationColumns+` FROM project_applications WHERE id = $1 AND org_id = $2`,
		id, orgID,
	)
	return scanApplication(row)
}

// ListApplicationsForStaff returns every application against a requirement,
// joined with the applicant's name/email, best AI score first (nulls
// last — i.e. unscored applications sort after scored ones) so a staff
// reviewer sees the AI's ranking without a separate sort step.
func (r *Repo) ListApplicationsForStaff(ctx context.Context, orgID, requirementID string) ([]ProjectApplication, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+applicationColumnsAliased+`, u.name, u.email
		 FROM project_applications app
		 JOIN users u ON u.id = app.user_id
		 WHERE app.org_id = $1 AND app.requirement_id = $2
		 ORDER BY app.ai_score DESC NULLS LAST, app.applied_at`,
		orgID, requirementID,
	)
	if err != nil {
		return nil, fmt.Errorf("projectmarket: list applications for staff: %w", err)
	}
	defer rows.Close()

	var out []ProjectApplication
	for rows.Next() {
		var app ProjectApplication
		if err := rows.Scan(
			&app.ID, &app.OrgID, &app.RequirementID, &app.UserID, &app.Motivation, &app.ResumeText,
			&app.Status, &app.ReviewedBy, &app.ReviewedAt, &app.AppliedAt,
			&app.AIScore, &app.AIRationale, &app.AIScoredAt,
			&app.Name, &app.Email,
		); err != nil {
			return nil, fmt.Errorf("projectmarket: scan staff application row: %w", err)
		}
		out = append(out, app)
	}
	return out, rows.Err()
}

// ListUnscoredApplications returns every application against a requirement
// that ScoreRequirement hasn't scored yet — the "AI called once" cache check
// (see service_score.go), scoped so a re-run never re-scores or re-bills an
// already-scored application.
func (r *Repo) ListUnscoredApplications(ctx context.Context, orgID, requirementID string) ([]ProjectApplication, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+applicationColumns+` FROM project_applications
		 WHERE org_id = $1 AND requirement_id = $2 AND ai_score IS NULL
		 ORDER BY applied_at`,
		orgID, requirementID,
	)
	if err != nil {
		return nil, fmt.Errorf("projectmarket: list unscored applications: %w", err)
	}
	defer rows.Close()

	var out []ProjectApplication
	for rows.Next() {
		app, err := scanApplication(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *app)
	}
	return out, rows.Err()
}

// SetApplicationScore persists one AI scoring result — called at most once
// per application (ListUnscoredApplications is the caller's own guard
// against calling it twice).
func (r *Repo) SetApplicationScore(ctx context.Context, id string, score float64, rationale string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_applications SET ai_score = $2, ai_rationale = $3, ai_scored_at = now() WHERE id = $1`,
		id, score, rationale,
	)
	if err != nil {
		return fmt.Errorf("projectmarket: set application score: %w", err)
	}
	return nil
}

// ListSelectedApplications returns every "selected" application against a
// requirement — CreateTeamFromSelection's roster source.
func (r *Repo) ListSelectedApplications(ctx context.Context, orgID, requirementID string) ([]ProjectApplication, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+applicationColumns+` FROM project_applications
		 WHERE org_id = $1 AND requirement_id = $2 AND status = 'selected'`,
		orgID, requirementID,
	)
	if err != nil {
		return nil, fmt.Errorf("projectmarket: list selected applications: %w", err)
	}
	defer rows.Close()

	var out []ProjectApplication
	for rows.Next() {
		app, err := scanApplication(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *app)
	}
	return out, rows.Err()
}

// ListMyApplications returns the authenticated student's own applications
// across every requirement, newest first.
func (r *Repo) ListMyApplications(ctx context.Context, orgID, userID string) ([]ProjectApplication, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+applicationColumns+` FROM project_applications
		 WHERE org_id = $1 AND user_id = $2 ORDER BY applied_at DESC`,
		orgID, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("projectmarket: list my applications: %w", err)
	}
	defer rows.Close()

	var out []ProjectApplication
	for rows.Next() {
		app, err := scanApplication(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *app)
	}
	return out, rows.Err()
}

// SetApplicationStatus records a staff review decision.
func (r *Repo) SetApplicationStatus(ctx context.Context, orgID, id, status, reviewedBy string) (*ProjectApplication, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_applications SET status = $3, reviewed_by = $4, reviewed_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+applicationColumns,
		id, orgID, status, reviewedBy,
	)
	return scanApplication(row)
}

// WithdrawApplication deletes a student's own application, scoped to userID
// so a student can never withdraw someone else's. Returns ErrNotFound if no
// such application exists for this caller.
func (r *Repo) WithdrawApplication(ctx context.Context, orgID, id, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM project_applications WHERE id = $1 AND org_id = $2 AND user_id = $3`,
		id, orgID, userID,
	)
	if err != nil {
		return fmt.Errorf("projectmarket: withdraw application: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

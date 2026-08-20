package gitlab

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/db"
)

// ─── project_checkpoints ────────────────────────────────────────────────────

const checkpointColumns = `
	id, org_id, assignment_id, title, description, position, due_at, weight,
	requires_mr, requires_ci_pass, kind, gitlab_milestone_id, created_at, updated_at`

func scanCheckpoint(row pgx.Row) (*ProjectCheckpoint, error) {
	var cp ProjectCheckpoint
	err := row.Scan(
		&cp.ID, &cp.OrgID, &cp.AssignmentID, &cp.Title, &cp.Description, &cp.Position, &cp.DueAt, &cp.Weight,
		&cp.RequiresMR, &cp.RequiresCIPass, &cp.Kind, &cp.GitlabMilestoneID, &cp.CreatedAt, &cp.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan checkpoint: %w", err)
	}
	return &cp, nil
}

// NextCheckpointPosition returns one past the highest existing position for
// an assignment (1 if it has none yet) — used when a caller creates a
// checkpoint without specifying an explicit position.
func (r *Repo) NextCheckpointPosition(ctx context.Context, assignmentID string) (int, error) {
	var next int
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(MAX(position), 0) + 1 FROM project_checkpoints WHERE assignment_id = $1`,
		assignmentID,
	).Scan(&next)
	if err != nil {
		return 0, fmt.Errorf("gitlab: next checkpoint position: %w", err)
	}
	return next, nil
}

// CreateCheckpoint inserts a new checkpoint under an assignment.
func (r *Repo) CreateCheckpoint(ctx context.Context, cp ProjectCheckpoint) (*ProjectCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_checkpoints
			(org_id, assignment_id, title, description, position, due_at, weight, requires_mr, requires_ci_pass, kind)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		 RETURNING `+checkpointColumns,
		cp.OrgID, cp.AssignmentID, cp.Title, cp.Description, cp.Position, cp.DueAt, cp.Weight, cp.RequiresMR, cp.RequiresCIPass, cp.Kind,
	)
	created, err := scanCheckpoint(row)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, ErrConflict
		}
		return nil, fmt.Errorf("gitlab: create checkpoint: %w", err)
	}
	return created, nil
}

// GetCheckpoint returns a single org-scoped checkpoint.
func (r *Repo) GetCheckpoint(ctx context.Context, orgID, id string) (*ProjectCheckpoint, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+checkpointColumns+` FROM project_checkpoints WHERE id = $1 AND org_id = $2`, id, orgID)
	return scanCheckpoint(row)
}

// GetCheckpointByID returns a checkpoint by id alone, with no org scoping —
// used internally by webhook ingest, which only carries a team/assignment
// context, not a request's claims (see Repo.GetAssignmentByID's own doc
// comment for the same reasoning).
func (r *Repo) GetCheckpointByID(ctx context.Context, id string) (*ProjectCheckpoint, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+checkpointColumns+` FROM project_checkpoints WHERE id = $1`, id)
	return scanCheckpoint(row)
}

// ListCheckpoints lists every checkpoint under an assignment, in Position
// order, with every team's submission row against it embedded via a
// LATERAL json_agg subquery — one query for the whole assignment rather than
// this method's former plain checkpoint list plus a
// ListTeamCheckpointsByCheckpoint round trip per checkpoint the frontend
// detail page used to make (GetCheckpointSubmissions called once per
// checkpoint in a Promise.all). row_to_json's column aliases are written to
// match ProjectTeamCheckpoint's own json tags exactly, so the aggregated
// JSON unmarshals straight into it below with no field-by-field mapping.
func (r *Repo) ListCheckpoints(ctx context.Context, orgID, assignmentID string) ([]CheckpointWithSubmissions, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT pc.id, pc.org_id, pc.assignment_id, pc.title, pc.description, pc.position, pc.due_at, pc.weight,
		        pc.requires_mr, pc.requires_ci_pass, pc.kind, pc.gitlab_milestone_id, pc.created_at, pc.updated_at,
		        COALESCE(s.submissions, '[]'::json)
		 FROM project_checkpoints pc
		 LEFT JOIN LATERAL (
		   SELECT json_agg(row_to_json(z) ORDER BY z.created_at) AS submissions
		   FROM (
		     SELECT id, org_id, team_id, checkpoint_id, mr_iid, mr_id, mr_web_url, mr_state,
		            approvals_count, ci_status, ci_pipeline_id, snapshot_sha, snapshot_at,
		            is_late, late_commit_count, score, feedback, graded_by, graded_at, status,
		            created_at, updated_at
		     FROM project_team_checkpoints ptc
		     WHERE ptc.checkpoint_id = pc.id
		   ) z
		 ) s ON true
		 WHERE pc.org_id = $1 AND pc.assignment_id = $2
		 ORDER BY pc.position`,
		orgID, assignmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list checkpoints: %w", err)
	}
	defer rows.Close()

	out := []CheckpointWithSubmissions{}
	for rows.Next() {
		var cp ProjectCheckpoint
		var submissionsRaw []byte
		if err := rows.Scan(
			&cp.ID, &cp.OrgID, &cp.AssignmentID, &cp.Title, &cp.Description, &cp.Position, &cp.DueAt, &cp.Weight,
			&cp.RequiresMR, &cp.RequiresCIPass, &cp.Kind, &cp.GitlabMilestoneID, &cp.CreatedAt, &cp.UpdatedAt,
			&submissionsRaw,
		); err != nil {
			return nil, fmt.Errorf("gitlab: scan checkpoint: %w", err)
		}
		var submissions []ProjectTeamCheckpoint
		if err := json.Unmarshal(submissionsRaw, &submissions); err != nil {
			return nil, fmt.Errorf("gitlab: unmarshal checkpoint submissions: %w", err)
		}
		out = append(out, CheckpointWithSubmissions{ProjectCheckpoint: cp, Submissions: submissions})
	}
	return out, rows.Err()
}

// UpdateCheckpoint applies a partial patch (nil fields left untouched).
func (r *Repo) UpdateCheckpoint(ctx context.Context, orgID, id string, p CheckpointPatch) (*ProjectCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_checkpoints SET
			title = COALESCE($3, title),
			description = COALESCE($4, description),
			due_at = COALESCE($5, due_at),
			weight = COALESCE($6, weight),
			requires_mr = COALESCE($7, requires_mr),
			requires_ci_pass = COALESCE($8, requires_ci_pass),
			kind = COALESCE($9, kind),
			updated_at = now()
		 WHERE id = $1 AND org_id = $2
		 RETURNING `+checkpointColumns,
		id, orgID, p.Title, p.Description, p.DueAt, p.Weight, p.RequiresMR, p.RequiresCIPass, p.Kind,
	)
	cp, err := scanCheckpoint(row)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: update checkpoint: %w", err)
	}
	return cp, nil
}

// DeleteCheckpoint hard-deletes a checkpoint (cascades its team-checkpoint
// submission rows) — unlike DeleteAssignment/DeleteTeam, checkpoints have no
// GitLab-side resource of their own to orphan (only the MRs bound to them
// do, and those live on GitLab regardless), so no draft-only restriction.
func (r *Repo) DeleteCheckpoint(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM project_checkpoints WHERE id = $1 AND org_id = $2`, id, orgID)
	if err != nil {
		return fmt.Errorf("gitlab: delete checkpoint: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetCheckpointMilestoneID persists the GitLab group milestone created for a
// checkpoint (see Service.CreateCheckpoint's best-effort milestone-creation
// step) — the write side of the milestone<->checkpoint mapping that
// FindCheckpointByMilestone reads back on the Issue Hook.
func (r *Repo) SetCheckpointMilestoneID(ctx context.Context, checkpointID string, milestoneID int64) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_checkpoints SET gitlab_milestone_id = $2, updated_at = now() WHERE id = $1`,
		checkpointID, milestoneID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: set checkpoint milestone id: %w", err)
	}
	return nil
}

// FindCheckpointByMilestone resolves the checkpoint under assignmentID whose
// gitlab_milestone_id matches milestoneID — the read side of the mapping,
// used by the Issue Hook (ingestIssueEvent) to set gitlab_issues.checkpoint_id.
// Returns ErrNotFound (not an error the caller needs to surface) when no
// checkpoint has that milestone yet — the expected state for every
// checkpoint until CreateCheckpoint's milestone creation has run for it.
func (r *Repo) FindCheckpointByMilestone(ctx context.Context, assignmentID string, milestoneID int64) (*ProjectCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+checkpointColumns+` FROM project_checkpoints WHERE assignment_id = $1 AND gitlab_milestone_id = $2`,
		assignmentID, milestoneID,
	)
	return scanCheckpoint(row)
}

// FindOpenCheckpointForTeam resolves the checkpoint an incoming MR or
// pipeline event should bind/mirror to: the lowest-position checkpoint under
// the team's assignment that isn't already graded for this team. This is
// deliberately the simple rule kind-herding-cookie.md allows ("bind to open
// checkpoint") rather than branch-name parsing or any other inference from
// the payload — a team only ever has one checkpoint "in flight" at a time in
// the common case, and an already-graded checkpoint is never rebound.
// Returns ErrNotFound if the assignment has no checkpoints configured yet.
func (r *Repo) FindOpenCheckpointForTeam(ctx context.Context, assignmentID, teamID string) (*ProjectCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT pc.id, pc.org_id, pc.assignment_id, pc.title, pc.description, pc.position, pc.due_at, pc.weight,
		        pc.requires_mr, pc.requires_ci_pass, pc.kind, pc.gitlab_milestone_id, pc.created_at, pc.updated_at
		 FROM project_checkpoints pc
		 LEFT JOIN project_team_checkpoints ptc
		   ON ptc.checkpoint_id = pc.id AND ptc.team_id = $2
		 WHERE pc.assignment_id = $1
		   AND (ptc.status IS NULL OR ptc.status <> 'graded')
		 ORDER BY pc.position ASC
		 LIMIT 1`,
		assignmentID, teamID,
	)
	return scanCheckpoint(row)
}

// ListCheckpointsForTeam returns every checkpoint under assignmentID, LEFT
// JOINed against teamID's own project_team_checkpoints row (never another
// team's) — the query the student-scoped "my checkpoints" surface reads,
// called only after Service.GetMyProjectCheckpoints has already verified via
// GetMyProject that the caller belongs to teamID. LEFT JOIN (not INNER) is
// required here: a checkpoint with no submission yet from this team must
// still appear, just with nil submission fields, rather than being silently
// dropped from the list.
func (r *Repo) ListCheckpointsForTeam(ctx context.Context, assignmentID, teamID string) ([]MyCheckpointRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT pc.id, pc.title, pc.description, pc.position, pc.due_at, pc.weight, pc.requires_mr, pc.requires_ci_pass, pc.kind,
		        ptc.mr_web_url, ptc.mr_state, ptc.approvals_count, ptc.ci_status, ptc.score, ptc.feedback, ptc.status
		 FROM project_checkpoints pc
		 LEFT JOIN project_team_checkpoints ptc
		   ON ptc.checkpoint_id = pc.id AND ptc.team_id = $2
		 WHERE pc.assignment_id = $1
		 ORDER BY pc.position`,
		assignmentID, teamID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list checkpoints for team: %w", err)
	}
	defer rows.Close()

	out := []MyCheckpointRow{}
	for rows.Next() {
		var row MyCheckpointRow
		if err := rows.Scan(
			&row.CheckpointID, &row.Title, &row.Description, &row.Position, &row.DueAt, &row.Weight, &row.RequiresMR, &row.RequiresCIPass, &row.Kind,
			&row.MRWebURL, &row.MRState, &row.ApprovalsCount, &row.CIStatus, &row.Score, &row.Feedback, &row.Status,
		); err != nil {
			return nil, fmt.Errorf("gitlab: scan my checkpoint row: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// ─── project_team_checkpoints ───────────────────────────────────────────────

const teamCheckpointColumns = `
	id, org_id, team_id, checkpoint_id, mr_iid, mr_id, mr_web_url, mr_state,
	approvals_count, ci_status, ci_pipeline_id, snapshot_sha, snapshot_at,
	is_late, late_commit_count, score, feedback, graded_by, graded_at, status,
	created_at, updated_at`

func scanTeamCheckpoint(row pgx.Row) (*ProjectTeamCheckpoint, error) {
	var t ProjectTeamCheckpoint
	err := row.Scan(
		&t.ID, &t.OrgID, &t.TeamID, &t.CheckpointID, &t.MRIID, &t.MRID, &t.MRWebURL, &t.MRState,
		&t.ApprovalsCount, &t.CIStatus, &t.CIPipelineID, &t.SnapshotSHA, &t.SnapshotAt,
		&t.IsLate, &t.LateCommitCount, &t.Score, &t.Feedback, &t.GradedBy, &t.GradedAt, &t.Status,
		&t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan team checkpoint: %w", err)
	}
	return &t, nil
}

// GetTeamCheckpoint returns one team's submission row for one checkpoint.
func (r *Repo) GetTeamCheckpoint(ctx context.Context, teamID, checkpointID string) (*ProjectTeamCheckpoint, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+teamCheckpointColumns+` FROM project_team_checkpoints WHERE team_id = $1 AND checkpoint_id = $2`, teamID, checkpointID)
	return scanTeamCheckpoint(row)
}

// ListTeamCheckpointsByCheckpoint lists every team's submission row for one
// checkpoint — GET .../checkpoints/{checkpointID}/submissions.
func (r *Repo) ListTeamCheckpointsByCheckpoint(ctx context.Context, checkpointID string) ([]ProjectTeamCheckpoint, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+teamCheckpointColumns+` FROM project_team_checkpoints WHERE checkpoint_id = $1 ORDER BY created_at`,
		checkpointID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list team checkpoints by checkpoint: %w", err)
	}
	defer rows.Close()

	out := []ProjectTeamCheckpoint{}
	for rows.Next() {
		t, err := scanTeamCheckpoint(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

// UpsertTeamCheckpointMR inserts (or refreshes) a team's MR-as-submission
// binding, keyed UNIQUE(team_id, checkpoint_id). newStatus is applied only
// when non-nil (the caller maps MR state -> status transition — see
// Service.bindMRToCheckpoint; states other than opened/merged leave the
// existing status untouched, both on insert — where it defaults to 'open' —
// and on a later update of the same row).
func (r *Repo) UpsertTeamCheckpointMR(ctx context.Context, orgID, teamID, checkpointID string, mrIID, mrID int64, mrWebURL, mrState string, newStatus *string) (*ProjectTeamCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_team_checkpoints
			(org_id, team_id, checkpoint_id, mr_iid, mr_id, mr_web_url, mr_state, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7, COALESCE($8, 'open'))
		 ON CONFLICT (team_id, checkpoint_id) DO UPDATE SET
			mr_iid = EXCLUDED.mr_iid,
			mr_id = EXCLUDED.mr_id,
			mr_web_url = EXCLUDED.mr_web_url,
			mr_state = EXCLUDED.mr_state,
			status = COALESCE($8, project_team_checkpoints.status),
			updated_at = now()
		 RETURNING `+teamCheckpointColumns,
		orgID, teamID, checkpointID, mrIID, mrID, mrWebURL, mrState, newStatus,
	)
	updated, err := scanTeamCheckpoint(row)
	if err != nil {
		return nil, fmt.Errorf("gitlab: upsert team checkpoint mr: %w", err)
	}
	return updated, nil
}

// RecomputeCheckpointApprovals recounts project_team_checkpoints.approvals_count
// for whichever checkpoint mrID is currently bound to (matched via
// team_id+mr_iid — see UpsertTeamCheckpointMR), from distinct non-author
// approving reviewers on gitlab_merge_requests.reviews jsonb array
// (kind-herding-cookie.md §0.4's layer-1 enforcement — active on Free/CE and
// Premium/Ultimate alike, since it depends only on the 'approval' kind,
// not GitLab's own approvals API). A no-op when the MR isn't bound to any
// checkpoint yet, or has no approval notes yet — the caller doesn't need to
// check first.
func (r *Repo) RecomputeCheckpointApprovals(ctx context.Context, mrID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_team_checkpoints ptc
		 SET approvals_count = sub.cnt, updated_at = now()
		 FROM (
		   SELECT mr.team_id, mr.mr_iid, COUNT(DISTINCT (rv->>'reviewer_gitlab_user_id')::bigint) AS cnt
		   FROM gitlab_merge_requests mr
		   CROSS JOIN LATERAL jsonb_array_elements(COALESCE(mr.reviews, '[]'::jsonb)) rv
		   WHERE mr.id = $1
		     AND rv->>'kind' = 'approval'
		     AND rv->>'reviewer_gitlab_user_id' IS NOT NULL
		     AND (rv->>'reviewer_gitlab_user_id')::bigint IS DISTINCT FROM mr.author_gitlab_user_id
		   GROUP BY mr.team_id, mr.mr_iid
		 ) sub
		 WHERE ptc.team_id = sub.team_id AND ptc.mr_iid = sub.mr_iid`,
		mrID,
	)
	if err != nil {
		return fmt.Errorf("gitlab: recompute checkpoint approvals: %w", err)
	}
	return nil
}

// UpdateTeamCheckpointCIStatus mirrors a pipeline's status/id onto the team's
// currently-bound submission row for checkpointID. Returns ErrNotFound (not
// an error the caller need surface) when no submission row exists yet for
// this checkpoint — nothing to mirror onto until an MR has bound it.
func (r *Repo) UpdateTeamCheckpointCIStatus(ctx context.Context, teamID, checkpointID, ciStatus string, pipelineID int64) (*ProjectTeamCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_team_checkpoints SET ci_status = $3, ci_pipeline_id = $4, updated_at = now()
		 WHERE team_id = $1 AND checkpoint_id = $2
		 RETURNING `+teamCheckpointColumns,
		teamID, checkpointID, ciStatus, pipelineID,
	)
	updated, err := scanTeamCheckpoint(row)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: update team checkpoint ci status: %w", err)
	}
	return updated, nil
}

// SetTeamCheckpointStatus transitions a submission row's status inside the
// caller's own transaction tx — Service.TryMergeCheckpoint uses this so the
// status flip and its accompanying team notification commit atomically (see
// its own doc comment for the full ordering reasoning). The WHERE clause
// excludes rows already 'merged'/'graded' so a duplicate call (e.g. a raced
// double-click) is a harmless no-op rather than a redundant overwrite.
func (r *Repo) SetTeamCheckpointStatus(ctx context.Context, tx pgx.Tx, teamID, checkpointID, status string) (*ProjectTeamCheckpoint, error) {
	row := tx.QueryRow(ctx,
		`UPDATE project_team_checkpoints SET status = $3, updated_at = now()
		 WHERE team_id = $1 AND checkpoint_id = $2 AND status NOT IN ('merged', 'graded')
		 RETURNING `+teamCheckpointColumns,
		teamID, checkpointID, status,
	)
	updated, err := scanTeamCheckpoint(row)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			// Either already merged/graded (guard above) or the row doesn't
			// exist — either way, fetch the current row so the caller still
			// gets a sensible response instead of an error.
			current, getErr := r.GetTeamCheckpoint(ctx, teamID, checkpointID)
			if getErr != nil {
				return nil, getErr
			}
			return current, nil
		}
		return nil, fmt.Errorf("gitlab: set team checkpoint status: %w", err)
	}
	return updated, nil
}

// ─── Batch 6: deadline snapshot ─────────────────────────────────────────────

// DueCheckpointSnapshot is one (team, checkpoint) pair past due_at that
// hasn't been HEAD-snapshotted yet — gitlab.deadline_snapshot's own work
// queue (see Repo.ListDueCheckpointsNeedingSnapshot).
type DueCheckpointSnapshot struct {
	OrgID           string
	TeamID          string
	CheckpointID    string
	GitlabProjectID int64
	DefaultBranch   string
	InstallationID  *string
}

// ListDueCheckpointsNeedingSnapshot returns every (team, checkpoint) pair
// where the checkpoint's due_at has passed and this team has no snapshot on
// file yet — either no project_team_checkpoints row at all (a team that
// never submitted an MR against this checkpoint) or a row whose snapshot_at
// is still null (LEFT JOIN, not INNER, is required for exactly that reason).
// Only provisioned teams (gitlab_project_id set) are candidates — an
// unprovisioned team has no repo to snapshot.
func (r *Repo) ListDueCheckpointsNeedingSnapshot(ctx context.Context) ([]DueCheckpointSnapshot, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT t.org_id, t.id, pc.id, t.gitlab_project_id, a.default_branch, a.installation_id
		 FROM project_checkpoints pc
		 JOIN project_assignments a ON a.id = pc.assignment_id
		 JOIN project_teams t ON t.assignment_id = pc.assignment_id
		 LEFT JOIN project_team_checkpoints ptc ON ptc.team_id = t.id AND ptc.checkpoint_id = pc.id
		 WHERE pc.due_at IS NOT NULL AND pc.due_at < now()
		   AND t.gitlab_project_id IS NOT NULL
		   AND ptc.snapshot_at IS NULL`,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list due checkpoints needing snapshot: %w", err)
	}
	defer rows.Close()

	out := []DueCheckpointSnapshot{}
	for rows.Next() {
		var d DueCheckpointSnapshot
		if err := rows.Scan(&d.OrgID, &d.TeamID, &d.CheckpointID, &d.GitlabProjectID, &d.DefaultBranch, &d.InstallationID); err != nil {
			return nil, fmt.Errorf("gitlab: scan due checkpoint snapshot: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// SnapshotTeamCheckpoint records team's HEAD sha as of "now" for
// checkpointID — inserting a fresh project_team_checkpoints row if the team
// never submitted an MR yet (status defaults to 'open'), or setting
// snapshot_sha/snapshot_at on an existing row. COALESCE on both makes this
// idempotent: a second call for the same team+checkpoint (this job's own
// retry, or two cron ticks racing before the first's write is visible) never
// overwrites an already-taken snapshot with a later HEAD — the snapshot must
// be taken once, at (or as close as this cron's 5-minute cadence allows to)
// the actual deadline, not refreshed on every later tick.
func (r *Repo) SnapshotTeamCheckpoint(ctx context.Context, orgID, teamID, checkpointID, sha string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO project_team_checkpoints (org_id, team_id, checkpoint_id, snapshot_sha, snapshot_at)
		 VALUES ($1, $2, $3, $4, now())
		 ON CONFLICT (team_id, checkpoint_id) DO UPDATE SET
			snapshot_sha = COALESCE(project_team_checkpoints.snapshot_sha, EXCLUDED.snapshot_sha),
			snapshot_at = COALESCE(project_team_checkpoints.snapshot_at, EXCLUDED.snapshot_at),
			updated_at = now()`,
		orgID, teamID, checkpointID, sha,
	)
	if err != nil {
		return fmt.Errorf("gitlab: snapshot team checkpoint: %w", err)
	}
	return nil
}

// GradeTeamCheckpoint records an instructor's score/feedback and transitions
// the submission to 'graded'.
func (r *Repo) GradeTeamCheckpoint(ctx context.Context, teamID, checkpointID string, score float64, feedback *string, gradedBy string) (*ProjectTeamCheckpoint, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE project_team_checkpoints SET
			score = $3, feedback = $4, graded_by = $5, graded_at = now(), status = 'graded', updated_at = now()
		 WHERE team_id = $1 AND checkpoint_id = $2
		 RETURNING `+teamCheckpointColumns,
		teamID, checkpointID, score, feedback, gradedBy,
	)
	updated, err := scanTeamCheckpoint(row)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: grade team checkpoint: %w", err)
	}
	return updated, nil
}

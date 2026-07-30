package gitlab

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// ─── project_originality_reports ───────────────────────────────────────────

const originalityReportColumns = `
	id, org_id, assignment_id, status, teams_scanned, files_scanned, error,
	requested_by, requested_at, completed_at`

func scanOriginalityReport(row pgx.Row) (*ProjectOriginalityReport, error) {
	var rpt ProjectOriginalityReport
	err := row.Scan(&rpt.ID, &rpt.OrgID, &rpt.AssignmentID, &rpt.Status, &rpt.TeamsScanned, &rpt.FilesScanned,
		&rpt.Error, &rpt.RequestedBy, &rpt.RequestedAt, &rpt.CompletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan originality report: %w", err)
	}
	return &rpt, nil
}

// CreateOriginalityReport inserts a new pending scan run for an assignment —
// the synchronous half of RequestOriginalityScan; the actual scan runs in
// the gitlab.originality_scan job (see RunOriginalityScan).
func (r *Repo) CreateOriginalityReport(ctx context.Context, orgID, assignmentID, requestedBy string) (*ProjectOriginalityReport, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_originality_reports (org_id, assignment_id, requested_by)
		 VALUES ($1, $2, $3)
		 RETURNING `+originalityReportColumns,
		orgID, assignmentID, requestedBy,
	)
	report, err := scanOriginalityReport(row)
	if err != nil {
		return nil, fmt.Errorf("gitlab: create originality report: %w", err)
	}
	return report, nil
}

// GetOriginalityReportByID loads a report by id alone — used internally by
// the job handler, which only carries a report_id payload (see
// GetAssignmentByID's own doc comment for the same org-scoping reasoning).
func (r *Repo) GetOriginalityReportByID(ctx context.Context, id string) (*ProjectOriginalityReport, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+originalityReportColumns+` FROM project_originality_reports WHERE id = $1`, id)
	return scanOriginalityReport(row)
}

// ListOriginalityReports lists every scan run for an assignment, newest first.
func (r *Repo) ListOriginalityReports(ctx context.Context, assignmentID string) ([]ProjectOriginalityReport, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+originalityReportColumns+` FROM project_originality_reports WHERE assignment_id = $1 ORDER BY requested_at DESC`,
		assignmentID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list originality reports: %w", err)
	}
	defer rows.Close()

	out := []ProjectOriginalityReport{}
	for rows.Next() {
		rpt, err := scanOriginalityReport(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *rpt)
	}
	return out, rows.Err()
}

// SetOriginalityReportStatus transitions a report's status without touching
// its progress counters — used for the pending->running and any->failed
// transitions (see CompleteOriginalityReport for the success path, which
// also records the final counts).
func (r *Repo) SetOriginalityReportStatus(ctx context.Context, id, status string, errMsg *string) error {
	_, err := r.pool.Exec(ctx, `UPDATE project_originality_reports SET status = $2, error = $3 WHERE id = $1`, id, status, errMsg)
	if err != nil {
		return fmt.Errorf("gitlab: set originality report status: %w", err)
	}
	return nil
}

// CompleteOriginalityReport marks a scan run complete with its final counts.
func (r *Repo) CompleteOriginalityReport(ctx context.Context, id string, teamsScanned, filesScanned int) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_originality_reports
		 SET status = 'complete', teams_scanned = $2, files_scanned = $3, error = NULL, completed_at = now()
		 WHERE id = $1`,
		id, teamsScanned, filesScanned,
	)
	if err != nil {
		return fmt.Errorf("gitlab: complete originality report: %w", err)
	}
	return nil
}

// ─── project_originality_matches ───────────────────────────────────────────

// DeleteOriginalityMatches clears a report's prior matches — called at the
// start of RunOriginalityScan so a retried job (e.g. after a transient
// archive-download failure mid-run) never leaves duplicate rows from its
// first, incomplete attempt.
func (r *Repo) DeleteOriginalityMatches(ctx context.Context, reportID string) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM project_originality_matches WHERE report_id = $1`, reportID)
	if err != nil {
		return fmt.Errorf("gitlab: delete originality matches: %w", err)
	}
	return nil
}

// InsertOriginalityMatch persists one file-pair whose similarity crossed
// originalityMatchThreshold.
func (r *Repo) InsertOriginalityMatch(ctx context.Context, m ProjectOriginalityMatch) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO project_originality_matches
			(report_id, team_a_id, team_b_id, file_path_a, file_path_b, similarity, matched_lines, sample)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		m.ReportID, m.TeamAID, m.TeamBID, m.FilePathA, m.FilePathB, m.Similarity, m.MatchedLines, m.Sample,
	)
	if err != nil {
		return fmt.Errorf("gitlab: insert originality match: %w", err)
	}
	return nil
}

// ListOriginalityMatches lists a report's matches, most similar first.
func (r *Repo) ListOriginalityMatches(ctx context.Context, reportID string) ([]ProjectOriginalityMatch, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, report_id, team_a_id, team_b_id, file_path_a, file_path_b, similarity, matched_lines, sample
		 FROM project_originality_matches WHERE report_id = $1 ORDER BY similarity DESC`,
		reportID,
	)
	if err != nil {
		return nil, fmt.Errorf("gitlab: list originality matches: %w", err)
	}
	defer rows.Close()

	out := []ProjectOriginalityMatch{}
	for rows.Next() {
		var m ProjectOriginalityMatch
		if err := rows.Scan(&m.ID, &m.ReportID, &m.TeamAID, &m.TeamBID, &m.FilePathA, &m.FilePathB, &m.Similarity, &m.MatchedLines, &m.Sample); err != nil {
			return nil, fmt.Errorf("gitlab: scan originality match: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ─── project_handoffs ───────────────────────────────────────────────────────

const handoffColumns = `
	id, org_id, team_id, user_id, mode, target_namespace_id, target_namespace_path,
	new_project_id, new_web_url, status, error, requested_at, completed_at`

func scanHandoff(row pgx.Row) (*ProjectHandoff, error) {
	var h ProjectHandoff
	err := row.Scan(&h.ID, &h.OrgID, &h.TeamID, &h.UserID, &h.Mode, &h.TargetNamespaceID, &h.TargetNamespacePath,
		&h.NewProjectID, &h.NewWebURL, &h.Status, &h.Error, &h.RequestedAt, &h.CompletedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("gitlab: scan handoff: %w", err)
	}
	return &h, nil
}

// UpsertHandoff creates a new handoff request, or resets an existing one
// back to pending — UNIQUE(team_id, user_id) means a student can only ever
// have one handoff record on file per team; retriggering (e.g. after a
// failure, or picking a different mode/target) intentionally resets
// mode/target/status/result rather than erroring, since "try again" is the
// expected use of a second call here.
func (r *Repo) UpsertHandoff(ctx context.Context, h ProjectHandoff) (*ProjectHandoff, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO project_handoffs (org_id, team_id, user_id, mode, target_namespace_id, target_namespace_path)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (team_id, user_id) DO UPDATE SET
			mode = EXCLUDED.mode,
			target_namespace_id = EXCLUDED.target_namespace_id,
			target_namespace_path = EXCLUDED.target_namespace_path,
			new_project_id = NULL,
			new_web_url = NULL,
			status = 'pending',
			error = NULL,
			requested_at = now(),
			completed_at = NULL
		 RETURNING `+handoffColumns,
		h.OrgID, h.TeamID, h.UserID, h.Mode, h.TargetNamespaceID, h.TargetNamespacePath,
	)
	handoff, err := scanHandoff(row)
	if err != nil {
		return nil, fmt.Errorf("gitlab: upsert handoff: %w", err)
	}
	return handoff, nil
}

// GetHandoffByID loads a handoff by id alone — used internally by the job
// handler (see GetAssignmentByID's own doc comment for why).
func (r *Repo) GetHandoffByID(ctx context.Context, id string) (*ProjectHandoff, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+handoffColumns+` FROM project_handoffs WHERE id = $1`, id)
	return scanHandoff(row)
}

// SetHandoffStatus transitions a handoff's status (pending->running,
// any->failed) without touching its result fields.
func (r *Repo) SetHandoffStatus(ctx context.Context, id, status string, errMsg *string) error {
	_, err := r.pool.Exec(ctx, `UPDATE project_handoffs SET status = $2, error = $3 WHERE id = $1`, id, status, errMsg)
	if err != nil {
		return fmt.Errorf("gitlab: set handoff status: %w", err)
	}
	return nil
}

// CompleteHandoff records the resulting GitLab project's identity and marks
// the handoff complete.
func (r *Repo) CompleteHandoff(ctx context.Context, id string, newProjectID int64, newWebURL string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE project_handoffs SET status = 'complete', new_project_id = $2, new_web_url = $3, error = NULL, completed_at = now() WHERE id = $1`,
		id, newProjectID, newWebURL,
	)
	if err != nil {
		return fmt.Errorf("gitlab: complete handoff: %w", err)
	}
	return nil
}

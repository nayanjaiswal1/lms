package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

const interestColumns = `id, project_id, name, email, skills, portfolio_url, message, status,
	invite_id, user_id, ai_score, ai_rationale, ai_scored_at, reviewed_by, reviewed_at, created_at, updated_at`

func scanInterest(row pgx.Row) (*Interest, error) {
	var i Interest
	err := row.Scan(&i.ID, &i.ProjectID, &i.Name, &i.Email, &i.Skills, &i.PortfolioURL, &i.Message, &i.Status,
		&i.InviteID, &i.UserID, &i.AIScore, &i.AIRationale, &i.AIScoredAt, &i.ReviewedBy, &i.ReviewedAt, &i.CreatedAt, &i.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan interest: %w", err)
	}
	return &i, nil
}

// UpsertInterest inserts a new interest, or refreshes an existing one that is
// still 'new' or a 'rejected' row past the 30-day reapply cooldown (01 §4).
// An anonymous upsert (nil userID) never touches a row already tied to an
// account, and an account only takes over an unclaimed row or its own. Returns
// false (no error) when the row exists but is outside those cases —
// the caller (SubmitInterest) treats that identically to success
// (D14's single generic acknowledgement).
func (r *Repo) UpsertInterest(ctx context.Context, db DBTX, projectID string, userID *string, name, email string, skills []string, portfolioURL, message *string, cooldown time.Duration) (bool, error) {
	if skills == nil {
		skills = []string{}
	}
	var id string
	err := db.QueryRow(ctx,
		`INSERT INTO project_interests (project_id, name, email, skills, portfolio_url, message, user_id)
		 VALUES ($1,$2,$3,$4,$5,$6,$8)
		 ON CONFLICT (project_id, email) DO UPDATE
		   SET name = EXCLUDED.name, skills = EXCLUDED.skills, portfolio_url = EXCLUDED.portfolio_url,
		       message = EXCLUDED.message, user_id = COALESCE(EXCLUDED.user_id, project_interests.user_id), status = 'new', ai_score = NULL, ai_rationale = NULL,
		       ai_scored_at = NULL, reviewed_by = NULL, reviewed_at = NULL, updated_at = now()
		 WHERE (project_interests.user_id IS NULL OR project_interests.user_id = EXCLUDED.user_id)
		   AND (project_interests.status = 'new'
		    OR (project_interests.status = 'rejected' AND project_interests.reviewed_at < now() - make_interval(secs => $7::double precision)))
		 RETURNING id`,
		projectID, name, email, skills, portfolioURL, message, cooldown.Seconds(), userID,
	).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("workspace: upsert interest: %w", err)
	}
	return true, nil
}

// ListInterests is the manager+ review list, cursor-paginated, optionally
// filtered by status.
func (r *Repo) ListInterests(ctx context.Context, db DBTX, projectID, status string, cursorAt time.Time, cursorID string, limit int) ([]Interest, error) {
	var rows pgx.Rows
	var err error
	switch {
	case status != "" && cursorID != "":
		rows, err = db.Query(ctx,
			`SELECT `+interestColumns+` FROM project_interests
			  WHERE project_id = $1 AND status = $2 AND (created_at, id) < ($3, $4)
			  ORDER BY created_at DESC, id DESC LIMIT $5`,
			projectID, status, cursorAt, cursorID, limit)
	case status != "":
		rows, err = db.Query(ctx,
			`SELECT `+interestColumns+` FROM project_interests
			  WHERE project_id = $1 AND status = $2
			  ORDER BY created_at DESC, id DESC LIMIT $3`,
			projectID, status, limit)
	case cursorID != "":
		rows, err = db.Query(ctx,
			`SELECT `+interestColumns+` FROM project_interests
			  WHERE project_id = $1 AND (created_at, id) < ($2, $3)
			  ORDER BY created_at DESC, id DESC LIMIT $4`,
			projectID, cursorAt, cursorID, limit)
	default:
		rows, err = db.Query(ctx,
			`SELECT `+interestColumns+` FROM project_interests
			  WHERE project_id = $1
			  ORDER BY created_at DESC, id DESC LIMIT $2`,
			projectID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: list interests: %w", err)
	}
	defer rows.Close()

	out := []Interest{}
	for rows.Next() {
		i, err := scanInterest(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *i)
	}
	return out, rows.Err()
}

// GetInterest fetches one interest scoped to its project.
func (r *Repo) GetInterest(ctx context.Context, db DBTX, projectID, interestID string) (*Interest, error) {
	return scanInterest(db.QueryRow(ctx,
		`SELECT `+interestColumns+` FROM project_interests WHERE id = $1 AND project_id = $2`,
		interestID, projectID))
}

// AcceptInterest flips status new->accepted, stamping the reviewer and the
// invite it now points at. 0 rows (already reviewed by a concurrent request)
// surfaces as ErrAlreadyReviewed. Must run after the project's seat count has
// already been checked, in the same transaction (the project row lock
// serializes concurrent accepts, so nothing itself re-checks the seat count
// here).
func (r *Repo) AcceptInterest(ctx context.Context, tx pgx.Tx, projectID, interestID, reviewedBy string, inviteID *string) (*Interest, error) {
	row := tx.QueryRow(ctx,
		`UPDATE project_interests SET status = 'accepted', reviewed_by = $3, reviewed_at = now(), invite_id = $4, updated_at = now()
		  WHERE id = $2 AND project_id = $1 AND status = 'new'
		  RETURNING `+interestColumns,
		projectID, interestID, reviewedBy, inviteID,
	)
	i, err := scanInterest(row)
	if errors.Is(err, ErrNotFound) {
		return nil, ErrAlreadyReviewed
	}
	return i, err
}

// MarkInterestJoined flips an accepted interest to joined and records the
// account it resolved to — the direct "email is already an org member" path
// (the invite path's own join happens later, inside orgs.Join).
func (r *Repo) MarkInterestJoined(ctx context.Context, tx pgx.Tx, projectID, interestID, userID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE project_interests SET status = 'joined', user_id = $3, updated_at = now() WHERE id = $2 AND project_id = $1`,
		projectID, interestID, userID,
	); err != nil {
		return fmt.Errorf("workspace: mark interest joined: %w", err)
	}
	return nil
}

// RejectInterest flips status new->rejected.
func (r *Repo) RejectInterest(ctx context.Context, db DBTX, projectID, interestID, reviewedBy string) (*Interest, error) {
	row := db.QueryRow(ctx,
		`UPDATE project_interests SET status = 'rejected', reviewed_by = $3, reviewed_at = now(), updated_at = now()
		  WHERE id = $2 AND project_id = $1 AND status = 'new'
		  RETURNING `+interestColumns,
		projectID, interestID, reviewedBy,
	)
	i, err := scanInterest(row)
	if errors.Is(err, ErrNotFound) {
		return nil, ErrAlreadyReviewed
	}
	return i, err
}

// SetInterestAIScore persists a rank result once, clamped by the caller.
func (r *Repo) SetInterestAIScore(ctx context.Context, db DBTX, interestID string, score float64, rationale string) error {
	if _, err := db.Exec(ctx,
		`UPDATE project_interests SET ai_score = $2, ai_rationale = $3, ai_scored_at = now() WHERE id = $1`,
		interestID, score, rationale,
	); err != nil {
		return fmt.Errorf("workspace: set interest ai score: %w", err)
	}
	return nil
}

// CountAcceptedPendingInterests counts accepted interests whose linked
// invite hasn't been accepted, revoked, or has expired yet — the reserved-
// seat half of the seat definition (contract-phase1.md).
func (r *Repo) CountAcceptedPendingInterests(ctx context.Context, db DBTX, projectID string) (int, error) {
	var n int
	err := db.QueryRow(ctx,
		`SELECT count(*) FROM project_interests i
		   LEFT JOIN org_invites inv ON inv.id = i.invite_id
		  WHERE i.project_id = $1 AND i.status = 'accepted'
		    AND (i.invite_id IS NULL OR (inv.accepted_at IS NULL AND inv.revoked_at IS NULL AND inv.expires_at > now()))`,
		projectID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("workspace: count accepted pending interests: %w", err)
	}
	return n, nil
}

// ExpireInvitedInterests flips accepted interests whose linked invite has
// expired or was revoked back to invite_expired, releasing the seat they
// reserved. Returns the number of rows changed.
func (r *Repo) ExpireInvitedInterests(ctx context.Context) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE project_interests i SET status = 'invite_expired', updated_at = now()
		   FROM org_invites inv
		  WHERE i.invite_id = inv.id AND i.status = 'accepted'
		    AND inv.accepted_at IS NULL AND (inv.revoked_at IS NOT NULL OR inv.expires_at <= now())`,
	)
	if err != nil {
		return 0, fmt.Errorf("workspace: expire invited interests: %w", err)
	}
	return tag.RowsAffected(), nil
}

// purgeBatchLimit bounds one purge pass so the daily job never holds a huge
// transaction/lock set on project_interests (02 §4.7).
const purgeBatchLimit = 1000

// PurgeInterests deletes stale interests (new/rejected/invite_expired older
// than the retention window, or any non-joined row on a project that's been
// cancelled/archived for that long) and scrubs PII off old joined rows.
// Returns the number of rows deleted (scrubbed rows are not counted).
func (r *Repo) PurgeInterests(ctx context.Context, retention time.Duration) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`WITH victims AS (
		   SELECT i.id FROM project_interests i
		   LEFT JOIN workspace_projects p ON p.id = i.project_id
		   WHERE (i.status IN ('new', 'rejected', 'invite_expired') AND i.updated_at < now() - make_interval(secs => $1::double precision))
		      OR (i.status <> 'joined' AND p.project_status IN ('cancelled', 'archived')
		          AND p.updated_at < now() - make_interval(secs => $1::double precision))
		   LIMIT `+fmt.Sprint(purgeBatchLimit)+`
		 )
		 DELETE FROM project_interests WHERE id IN (SELECT id FROM victims)`,
		retention.Seconds(),
	)
	if err != nil {
		return 0, fmt.Errorf("workspace: purge interests: %w", err)
	}

	if _, err := r.pool.Exec(ctx,
		`UPDATE project_interests SET message = NULL, portfolio_url = NULL
		  WHERE status = 'joined' AND updated_at < now() - make_interval(secs => $1::double precision)
		    AND (message IS NOT NULL OR portfolio_url IS NOT NULL)`,
		retention.Seconds(),
	); err != nil {
		return 0, fmt.Errorf("workspace: scrub joined interests: %w", err)
	}
	return tag.RowsAffected(), nil
}

// ListDiscoverable returns recruiting workspaces in the org that are open
// (accepting, deadline not passed) and the user is not already an active or
// invited member of, oldest first.
func (r *Repo) ListDiscoverable(ctx context.Context, orgID, userID string, cursorAt time.Time, cursorID string, limit int) ([]DiscoverProject, error) {
	if cursorID == "" { // zero cursor sorts before every row
		cursorID = "00000000-0000-0000-0000-000000000000"
	}
	rows, err := r.pool.Query(ctx,
		`SELECT p.id, p.title, left(p.requirement, $4), p.skills, p.team_size_min, p.team_size_max, p.interest_deadline,
		        EXISTS (SELECT 1 FROM project_interests i WHERE i.project_id = p.id AND i.user_id = $2), p.created_at
		   FROM workspace_projects p
		  WHERE p.org_id = $1 AND p.project_status = 'recruiting' AND p.accepting_interests
		    AND (p.interest_deadline IS NULL OR p.interest_deadline > now())
		    AND NOT EXISTS (SELECT 1 FROM project_members m WHERE m.project_id = p.id AND m.user_id = $2 AND m.status IN ('active','invited'))
		    AND (p.created_at, p.id) > ($5, $6::uuid)
		  ORDER BY p.created_at ASC, p.id ASC LIMIT $3`,
		orgID, userID, limit, DiscoverSummaryLen, cursorAt, cursorID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list discoverable: %w", err)
	}
	defer rows.Close()
	out := []DiscoverProject{}
	for rows.Next() {
		var d DiscoverProject
		if err := rows.Scan(&d.ID, &d.Title, &d.Summary, &d.Skills, &d.TeamSizeMin, &d.TeamSizeMax, &d.InterestDeadline, &d.HasApplied, &d.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan discoverable: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// ListMyInterests returns the user's interests with the workspace they target.
func (r *Repo) ListMyInterests(ctx context.Context, orgID, userID string) ([]MyInterest, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT i.id, p.id, p.title, p.project_status, i.status, i.created_at
		   FROM project_interests i JOIN workspace_projects p ON p.id = i.project_id
		  WHERE i.user_id = $1 AND p.org_id = $2
		  ORDER BY i.created_at DESC, i.id DESC LIMIT $3`, userID, orgID, MyInterestsMax)
	if err != nil {
		return nil, fmt.Errorf("workspace: list my interests: %w", err)
	}
	defer rows.Close()
	out := []MyInterest{}
	for rows.Next() {
		var m MyInterest
		if err := rows.Scan(&m.ID, &m.WorkspaceID, &m.WorkspaceTitle, &m.WorkspaceState, &m.Status, &m.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan my interest: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// GetUserNameEmail reads the identity a logged-in applicant is submitted under.
func (r *Repo) GetUserNameEmail(ctx context.Context, db DBTX, userID string) (name, email string, err error) {
	err = db.QueryRow(ctx, `SELECT name, email::text FROM users WHERE id = $1`, userID).Scan(&name, &email)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNotFound
	}
	if err != nil {
		return "", "", fmt.Errorf("workspace: get user identity: %w", err)
	}
	return name, email, nil
}

// InterestExistsForEmail reports whether (project, email) already has a row
// in any status other than a rejected one (rejected rows may reapply). An
// unclaimed anonymous 'new' row does not count: the logged-in applicant adopts it.
func (r *Repo) InterestExistsForEmail(ctx context.Context, db DBTX, projectID, email string) (bool, error) {
	var exists bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM project_interests WHERE project_id = $1 AND email = $2 AND status <> 'rejected' AND NOT (status = 'new' AND user_id IS NULL))`,
		projectID, email).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("workspace: interest exists: %w", err)
	}
	return exists, nil
}

// IsActiveOrInvitedMember reports a seat-holding or pending membership.
func (r *Repo) IsActiveOrInvitedMember(ctx context.Context, db DBTX, projectID, userID string) (bool, error) {
	var ok bool
	err := db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM project_members WHERE project_id = $1 AND user_id = $2 AND status IN ('active','invited'))`,
		projectID, userID).Scan(&ok)
	if err != nil {
		return false, fmt.Errorf("workspace: member exists: %w", err)
	}
	return ok, nil
}

// WithdrawInterest deletes the user's own interest while it is still 'new'.
func (r *Repo) WithdrawInterest(ctx context.Context, db DBTX, projectID, userID string) error {
	tag, err := db.Exec(ctx,
		`DELETE FROM project_interests WHERE project_id = $1 AND user_id = $2 AND status = 'new'`, projectID, userID)
	if err != nil {
		return fmt.Errorf("workspace: withdraw interest: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

package workspace

import (
	"context"
	"errors"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5"
)

// repo_feedback.go — Phase 5 (contract-phase5.md 5b) data layer for
// peer_feedback and the member outcome report (migration 040 + existing
// Phase 1-4 tables).

// HasSharedWork reports whether userA and userB were both assignees (any
// role) on at least one non-archived item in projectID — SubmitPeerFeedback's
// own "worked together" gate (ErrNoSharedWork).
func (r *Repo) HasSharedWork(ctx context.Context, db DBTX, projectID, userA, userB string) (bool, error) {
	var shared bool
	if err := db.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM work_item_assignees a1
		   JOIN work_item_assignees a2 ON a2.item_id = a1.item_id AND a2.user_id = $3
		   JOIN work_items w ON w.id = a1.item_id
		  WHERE w.project_id = $1 AND a1.user_id = $2)`,
		projectID, userA, userB,
	).Scan(&shared); err != nil {
		return false, fmt.Errorf("workspace: check shared work: %w", err)
	}
	return shared, nil
}

// ListRateableMembers returns every active member of projectID (other than
// callerID) who shares at least one item with callerID — GetFeedback's own
// "who can I rate" list.
func (r *Repo) ListRateableMembers(ctx context.Context, db DBTX, projectID, callerID string) ([]PersonRef, error) {
	rows, err := db.Query(ctx,
		`SELECT DISTINCT pm.user_id, u.name
		   FROM project_members pm
		   JOIN users u ON u.id = pm.user_id
		  WHERE pm.project_id = $1 AND pm.user_id <> $2 AND pm.status = 'active'
		    AND EXISTS (
		      SELECT 1 FROM work_item_assignees a1
		      JOIN work_item_assignees a2 ON a2.item_id = a1.item_id AND a2.user_id = $2
		      JOIN work_items w ON w.id = a1.item_id
		     WHERE w.project_id = $1 AND a1.user_id = pm.user_id)
		  ORDER BY u.name`,
		projectID, callerID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list rateable members: %w", err)
	}
	defer rows.Close()
	out := []PersonRef{}
	for rows.Next() {
		var p PersonRef
		if err := rows.Scan(&p.UserID, &p.Name); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// UpsertPeerFeedback inserts or (while the window is still open) replaces
// one caller's rating of one teammate.
func (r *Repo) UpsertPeerFeedback(ctx context.Context, db DBTX, projectID, fromUser, toUser string, rating int, comment *string) error {
	if _, err := db.Exec(ctx,
		`INSERT INTO peer_feedback (project_id, from_user, to_user, rating, comment)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (project_id, from_user, to_user)
		 DO UPDATE SET rating = EXCLUDED.rating, comment = EXCLUDED.comment, updated_at = now()`,
		projectID, fromUser, toUser, rating, comment,
	); err != nil {
		return fmt.Errorf("workspace: upsert peer feedback: %w", err)
	}
	return nil
}

// peer_feedback.from_user/to_user are ON DELETE SET NULL, so a rater or
// ratee whose account was later deleted must be scanned as a nullable id —
// PersonRef.UserID falls back to "" the same way ActorName falls back to
// "Former member" elsewhere in this package.
func scanPeerFeedbackRows(rows pgx.Rows) ([]PeerFeedbackRow, error) {
	defer rows.Close()
	out := []PeerFeedbackRow{}
	for rows.Next() {
		var row PeerFeedbackRow
		var fromID, toID *string
		if err := rows.Scan(&fromID, &row.FromUser.Name, &toID, &row.ToUser.Name,
			&row.Rating, &row.Comment, &row.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan peer feedback row: %w", err)
		}
		if fromID != nil {
			row.FromUser.UserID = *fromID
		}
		if toID != nil {
			row.ToUser.UserID = *toID
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

const peerFeedbackRowSelect = `pf.from_user, COALESCE(fu.name, 'Former member'), pf.to_user, COALESCE(tu.name, 'Former member'),
	pf.rating, pf.comment, pf.created_at`

// ListGivenFeedback returns every rating fromUser has given in projectID.
func (r *Repo) ListGivenFeedback(ctx context.Context, db DBTX, projectID, fromUser string) ([]PeerFeedbackRow, error) {
	rows, err := db.Query(ctx,
		`SELECT `+peerFeedbackRowSelect+`
		   FROM peer_feedback pf
		   LEFT JOIN users fu ON fu.id = pf.from_user
		   LEFT JOIN users tu ON tu.id = pf.to_user
		  WHERE pf.project_id = $1 AND pf.from_user = $2
		  ORDER BY pf.created_at DESC`,
		projectID, fromUser)
	if err != nil {
		return nil, fmt.Errorf("workspace: list given feedback: %w", err)
	}
	return scanPeerFeedbackRows(rows)
}

// ListAllFeedback returns every rating in projectID — owner/overseer only
// (D15).
func (r *Repo) ListAllFeedback(ctx context.Context, db DBTX, projectID string) ([]PeerFeedbackRow, error) {
	rows, err := db.Query(ctx,
		`SELECT `+peerFeedbackRowSelect+`
		   FROM peer_feedback pf
		   LEFT JOIN users fu ON fu.id = pf.from_user
		   LEFT JOIN users tu ON tu.id = pf.to_user
		  WHERE pf.project_id = $1
		  ORDER BY tu.name, pf.created_at DESC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list all feedback: %w", err)
	}
	return scanPeerFeedbackRows(rows)
}

// FeedbackReceivedStats returns toUser's average rating, sorted comments, and
// distinct rater count — MyFeedback's own "average + comments only after ≥3
// raters" input (02 §7.1), and the same average an owner sees unconditionally
// (BuildMemberReport).
func (r *Repo) FeedbackReceivedStats(ctx context.Context, db DBTX, projectID, toUser string) (avg float64, comments []string, raters int, err error) {
	if err = db.QueryRow(ctx,
		`SELECT COALESCE(AVG(rating), 0), count(*) FROM peer_feedback WHERE project_id = $1 AND to_user = $2`,
		projectID, toUser,
	).Scan(&avg, &raters); err != nil {
		return 0, nil, 0, fmt.Errorf("workspace: feedback received stats: %w", err)
	}
	rows, qerr := db.Query(ctx,
		`SELECT comment FROM peer_feedback WHERE project_id = $1 AND to_user = $2 AND comment IS NOT NULL AND btrim(comment) <> ''`,
		projectID, toUser)
	if qerr != nil {
		return 0, nil, 0, fmt.Errorf("workspace: feedback comments: %w", qerr)
	}
	defer rows.Close()
	comments = []string{}
	for rows.Next() {
		var c string
		if err := rows.Scan(&c); err != nil {
			return 0, nil, 0, err
		}
		comments = append(comments, c)
	}
	if err := rows.Err(); err != nil {
		return 0, nil, 0, err
	}
	sort.Strings(comments)
	return avg, comments, raters, nil
}

// SetShowcaseOptIn updates the caller's own showcase opt-in flag.
func (r *Repo) SetShowcaseOptIn(ctx context.Context, db DBTX, projectID, userID string, optIn bool) error {
	tag, err := db.Exec(ctx,
		`UPDATE project_members SET showcase_opt_in = $3 WHERE project_id = $1 AND user_id = $2`,
		projectID, userID, optIn,
	)
	if err != nil {
		return fmt.Errorf("workspace: set showcase opt-in: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// memberReportBase holds the person/role/showcase fields MemberReport starts
// from — the one row every report needs regardless of which stats a caller
// may see.
type memberReportBase struct {
	Person        PersonRef
	Role          string
	ShowcaseOptIn bool
}

// GetMemberReportBase resolves the reported-on member's identity/role/
// showcase flag, or ErrNotFound if they were never a member of this project.
func (r *Repo) GetMemberReportBase(ctx context.Context, db DBTX, projectID, userID string) (*memberReportBase, error) {
	var b memberReportBase
	err := db.QueryRow(ctx,
		`SELECT pm.user_id, u.name, pm.role, pm.showcase_opt_in
		   FROM project_members pm JOIN users u ON u.id = pm.user_id
		  WHERE pm.project_id = $1 AND pm.user_id = $2`,
		projectID, userID,
	).Scan(&b.Person.UserID, &b.Person.Name, &b.Role, &b.ShowcaseOptIn)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: get member report base: %w", err)
	}
	return &b, nil
}

// MemberReportCounters is every count-shaped field BuildMemberReport needs
// from a handful of small, indexed queries — grouped into one struct so the
// service layer stays a single readable assembly step.
type MemberReportCounters struct {
	ItemsOwned       int
	ItemsDoneOwned   int
	ItemsReviewed    int
	ItemsTested      int
	ReopensCaused    int
	DocApprovals     int
	ReviewComments   int
	MinutesLogged    int
	MeetingsAttended int
	MeetingsMissed   int
	StandupsPosted   int
}

// MemberReportCounts runs every MemberReportCounters sub-query.
func (r *Repo) MemberReportCounts(ctx context.Context, db DBTX, projectID, userID string) (MemberReportCounters, error) {
	var c MemberReportCounters
	if err := db.QueryRow(ctx,
		`SELECT
			count(*) FILTER (WHERE a.role = 'owner'),
			count(*) FILTER (WHERE a.role = 'owner' AND w.status = 'done'),
			count(*) FILTER (WHERE a.role = 'tester' AND w.status = 'done')
		   FROM work_item_assignees a JOIN work_items w ON w.id = a.item_id
		  WHERE w.project_id = $1 AND a.user_id = $2 AND w.archived_at IS NULL`,
		projectID, userID,
	).Scan(&c.ItemsOwned, &c.ItemsDoneOwned, &c.ItemsTested); err != nil {
		return c, fmt.Errorf("workspace: member report: item counts: %w", err)
	}
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_item_events e JOIN work_items w ON w.id = e.item_id
		  WHERE w.project_id = $1 AND e.kind = 'status' AND e.to_value = 'reopened' AND e.actor_id = $2`,
		projectID, userID,
	).Scan(&c.ReopensCaused); err != nil {
		return c, fmt.Errorf("workspace: member report: reopens: %w", err)
	}
	if err := db.QueryRow(ctx,
		`SELECT count(*) FILTER (WHERE r.target = 'code'),
		        count(*) FILTER (WHERE r.target = 'doc' AND r.verdict = 'approved'),
		        count(*) FILTER (WHERE r.comment IS NOT NULL AND btrim(r.comment) <> '')
		   FROM work_item_reviews r WHERE r.project_id = $1 AND r.reviewer_id = $2`,
		projectID, userID,
	).Scan(&c.ItemsReviewed, &c.DocApprovals, &c.ReviewComments); err != nil {
		return c, fmt.Errorf("workspace: member report: reviews: %w", err)
	}
	if err := db.QueryRow(ctx,
		`SELECT COALESCE(SUM(minutes), 0) FROM work_item_time_logs WHERE project_id = $1 AND user_id = $2`,
		projectID, userID,
	).Scan(&c.MinutesLogged); err != nil {
		return c, fmt.Errorf("workspace: member report: minutes logged: %w", err)
	}
	if err := db.QueryRow(ctx,
		`SELECT count(*) FILTER (WHERE ma.status = 'attended'), count(*) FILTER (WHERE ma.status = 'missed')
		   FROM meeting_attendance ma JOIN project_meetings pm ON pm.calendar_event_id = ma.calendar_event_id
		  WHERE pm.project_id = $1 AND ma.user_id = $2`,
		projectID, userID,
	).Scan(&c.MeetingsAttended, &c.MeetingsMissed); err != nil {
		return c, fmt.Errorf("workspace: member report: meetings: %w", err)
	}
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM standup_updates WHERE project_id = $1 AND user_id = $2`,
		projectID, userID,
	).Scan(&c.StandupsPosted); err != nil {
		return c, fmt.Errorf("workspace: member report: standups: %w", err)
	}
	return c, nil
}

// MemberReportGitlabCounts returns MR-opened/merged counts for userID on a
// GitLab-linked project's own team — zero/zero when teamID is nil (no GitLab
// project yet), the same shape GitlabQualitySignals uses.
func (r *Repo) MemberReportGitlabCounts(ctx context.Context, db DBTX, teamID, userID string) (opened, merged int, err error) {
	if err = db.QueryRow(ctx,
		`SELECT count(*), count(*) FILTER (WHERE merged_at IS NOT NULL)
		   FROM gitlab_merge_requests WHERE team_id = $1 AND author_user_id = $2`,
		teamID, userID,
	).Scan(&opened, &merged); err != nil {
		return 0, 0, fmt.Errorf("workspace: member report: gitlab counts: %w", err)
	}
	return opened, merged, nil
}

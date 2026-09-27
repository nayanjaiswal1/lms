package workspace

import (
	"context"
	"fmt"
	"time"
)

// repo_reminders.go — the two read-only sweeps SendBriefReminders and
// SendDocReviewReminders (service_reminders.go) run every tick. Each query
// selects only the columns its reminder actually needs, not a full row, since
// neither ever writes these rows back.

// reminderQuestion is one unanswered requirement_questions row old enough to
// remind about.
type reminderQuestion struct {
	ID        string
	ProjectID string
	OrgID     string
	AskedBy   *string
	CreatedAt time.Time
}

// ListUnansweredQuestionsOlderThan returns every unanswered question created
// before cutoff, for the brief reminder job.
func (r *Repo) ListUnansweredQuestionsOlderThan(ctx context.Context, cutoff time.Time) ([]reminderQuestion, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT q.id, q.project_id, p.org_id, q.asked_by, q.created_at
		   FROM requirement_questions q JOIN workspace_projects p ON p.id = q.project_id
		  WHERE q.answered_at IS NULL AND q.created_at < $1`,
		cutoff)
	if err != nil {
		return nil, fmt.Errorf("workspace: list unanswered questions: %w", err)
	}
	defer rows.Close()
	out := []reminderQuestion{}
	for rows.Next() {
		var q reminderQuestion
		if err := rows.Scan(&q.ID, &q.ProjectID, &q.OrgID, &q.AskedBy, &q.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan unanswered question: %w", err)
		}
		out = append(out, q)
	}
	return out, rows.Err()
}

// reminderDoc is one in_review feature doc idle since idleSince, for the doc
// review reminder job.
type reminderDoc struct {
	ItemID    string
	Key       string
	ProjectID string
	OrgID     string
	IdleSince time.Time
}

// ListStaleInReviewDocs returns every feature whose doc has been in_review
// since before cutoff, measured from its last 'doc'/'review' event (falling
// back to updated_at for a doc that has had no event logged since — should
// not happen once SubmitDoc always logs one, but keeps the query correct
// regardless).
func (r *Repo) ListStaleInReviewDocs(ctx context.Context, cutoff time.Time) ([]reminderDoc, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT w.id, w.key_num, p.key_prefix, w.project_id, p.org_id, idle.idle_since
		   FROM work_items w
		   JOIN workspace_projects p ON p.id = w.project_id
		   CROSS JOIN LATERAL (
		     SELECT COALESCE(MAX(e.created_at), w.updated_at) AS idle_since
		       FROM work_item_events e WHERE e.item_id = w.id AND e.kind IN ('doc','review')
		   ) idle
		  WHERE w.type = 'feature' AND w.doc_status = 'in_review' AND w.archived_at IS NULL
		    AND idle.idle_since < $1`,
		cutoff)
	if err != nil {
		return nil, fmt.Errorf("workspace: list stale in-review docs: %w", err)
	}
	defer rows.Close()
	out := []reminderDoc{}
	for rows.Next() {
		var d reminderDoc
		var keyNum int
		var keyPrefix string
		if err := rows.Scan(&d.ItemID, &keyNum, &keyPrefix, &d.ProjectID, &d.OrgID, &d.IdleSince); err != nil {
			return nil, fmt.Errorf("workspace: scan stale in-review doc: %w", err)
		}
		d.Key = fmt.Sprintf("%s-%d", keyPrefix, keyNum)
		out = append(out, d)
	}
	return out, rows.Err()
}

// GetProjectOwnerUserID returns the active owner's user id, if any — the
// brief reminder job's 3-day recipient.
func (r *Repo) GetProjectOwnerUserID(ctx context.Context, db DBTX, projectID string) (string, error) {
	var id string
	err := db.QueryRow(ctx,
		`SELECT user_id FROM project_members WHERE project_id = $1 AND status = 'active' AND role = 'owner' LIMIT 1`,
		projectID,
	).Scan(&id)
	if err != nil {
		return "", nil // no active owner (e.g. transferred mid-flight) — caller treats "" as "skip"
	}
	return id, nil
}

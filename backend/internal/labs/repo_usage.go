package labs

import (
	"context"
	"fmt"
	"time"
)

// ─── Usage metering (writer) ─────────────────────────────────────────────────
//
// lab_usage_events existed in the schema with no writer and no reader before
// this file — every cost/reporting feature docs/labs.md describes for it was
// schema-only. RecordSessionContainerUsage / RecordSessionContainerUsageBatch
// are the writer: called once per session, at the moment it closes out
// (EndSession, finalizeTaskPass's completion path, and every reaper closure
// in jobs/handlers/labs.go). The partial UNIQUE index from migration 011
// (session_id WHERE event_type='container_seconds') makes the write safe to
// call more than once for the same session — the reaper in particular
// retries on failure, and a retried batch must not double-bill an org.
//
// The billed quantity is elapsed wall-clock time minus paused_seconds: a
// paused container holds no CPU (see docs/labs.md paused_seconds comment),
// so counting paused time as container_seconds would overcharge for exactly
// the optimization idle-pause exists to provide.

// RecordSessionContainerUsage inserts one container_seconds usage event for
// sessionID, if the session actually had a container and no event has been
// recorded for it yet. Safe to call on a session with no container (code
// labs) or one that already has a recorded event — both are no-ops.
func (r *Repo) RecordSessionContainerUsage(ctx context.Context, sessionID string) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO lab_usage_events (org_id, session_id, event_type, quantity, image)
		SELECT s.org_id, s.id, 'container_seconds',
		       GREATEST(0, EXTRACT(EPOCH FROM (COALESCE(s.completed_at, now()) - s.started_at))::bigint - s.paused_seconds),
		       l.environment
		FROM lab_sessions s
		JOIN lab_definitions l ON l.id = s.lab_id
		WHERE s.id = $1 AND s.container_id IS NOT NULL
		ON CONFLICT (session_id) WHERE event_type = 'container_seconds' DO NOTHING`,
		sessionID,
	); err != nil {
		return fmt.Errorf("labs.Repo.RecordSessionContainerUsage: %w", err)
	}
	return nil
}

// RecordSessionContainerUsageBatch is RecordSessionContainerUsage for many
// sessions in one round trip — used by the reaper, which closes out up to
// 100 sessions per tick and would otherwise need a query per row.
func (r *Repo) RecordSessionContainerUsageBatch(ctx context.Context, sessionIDs []string) error {
	if len(sessionIDs) == 0 {
		return nil
	}
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO lab_usage_events (org_id, session_id, event_type, quantity, image)
		SELECT s.org_id, s.id, 'container_seconds',
		       GREATEST(0, EXTRACT(EPOCH FROM (COALESCE(s.completed_at, now()) - s.started_at))::bigint - s.paused_seconds),
		       l.environment
		FROM lab_sessions s
		JOIN lab_definitions l ON l.id = s.lab_id
		WHERE s.id = ANY($1) AND s.container_id IS NOT NULL
		ON CONFLICT (session_id) WHERE event_type = 'container_seconds' DO NOTHING`,
		sessionIDs,
	); err != nil {
		return fmt.Errorf("labs.Repo.RecordSessionContainerUsageBatch: %w", err)
	}
	return nil
}

// ─── Usage reporting (reader) ────────────────────────────────────────────────
//
// Three rollups over the same lab_usage_events + lab_sessions data, one per
// grain an org admin actually asks "who/what is burning compute" about:
// the whole org, per course, per student. All three are windowed and scoped
// to a single org_id — there is no cross-org variant, matching every other
// admin-facing lab query in this package.

// OrgLabUsage is the org-wide rollup: total container time, total sessions,
// and a breakdown by lab so a spike is traceable to a specific lab/image.
type OrgLabUsage struct {
	TotalContainerSeconds int64         `json:"total_container_seconds"`
	TotalSessions         int           `json:"total_sessions"`
	ByLab                 []LabUsageRow `json:"by_lab"`
}

// LabUsageRow is one lab's contribution to an org-wide usage window.
type LabUsageRow struct {
	LabID            string `json:"lab_id"`
	LabTitle         string `json:"lab_title"`
	Image            string `json:"image"`
	Sessions         int    `json:"sessions"`
	ContainerSeconds int64  `json:"container_seconds"`
}

// GetOrgLabUsage summarizes container_seconds usage for orgID within the
// trailing window, both as a total and broken out per lab.
func (r *Repo) GetOrgLabUsage(ctx context.Context, orgID string, window time.Duration) (*OrgLabUsage, error) {
	since := time.Now().Add(-window)

	var out OrgLabUsage
	if err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(u.quantity), 0), COUNT(DISTINCT u.session_id)
		FROM lab_usage_events u
		WHERE u.org_id = $1 AND u.event_type = 'container_seconds' AND u.recorded_at > $2`,
		orgID, since,
	).Scan(&out.TotalContainerSeconds, &out.TotalSessions); err != nil {
		return nil, fmt.Errorf("labs.Repo.GetOrgLabUsage: totals: %w", err)
	}

	rows, err := r.pool.Query(ctx, `
		SELECT l.id, l.title, l.environment, COUNT(*)::int, SUM(u.quantity)::bigint
		FROM lab_usage_events u
		JOIN lab_sessions s ON s.id = u.session_id
		JOIN lab_definitions l ON l.id = s.lab_id
		WHERE u.org_id = $1 AND u.event_type = 'container_seconds' AND u.recorded_at > $2
		GROUP BY l.id, l.title, l.environment
		ORDER BY SUM(u.quantity) DESC`,
		orgID, since,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.GetOrgLabUsage: by lab: %w", err)
	}
	defer rows.Close()

	out.ByLab = []LabUsageRow{}
	for rows.Next() {
		var row LabUsageRow
		if err := rows.Scan(&row.LabID, &row.LabTitle, &row.Image, &row.Sessions, &row.ContainerSeconds); err != nil {
			return nil, fmt.Errorf("labs.Repo.GetOrgLabUsage: scan: %w", err)
		}
		out.ByLab = append(out.ByLab, row)
	}
	return &out, rows.Err()
}

// CourseLabUsageRow is one course's contribution to an org-wide usage
// window. Standalone/course-less labs (module_id NULL or course_id NULL)
// are excluded — there is no course to attribute them to.
type CourseLabUsageRow struct {
	CourseID         string `json:"course_id"`
	CourseTitle      string `json:"course_title"`
	Sessions         int    `json:"sessions"`
	StudentCount     int    `json:"student_count"`
	ContainerSeconds int64  `json:"container_seconds"`
}

// GetCourseLabUsage breaks down container_seconds usage by course for orgID
// within the trailing window.
func (r *Repo) GetCourseLabUsage(ctx context.Context, orgID string, window time.Duration) ([]CourseLabUsageRow, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT c.id, c.title, COUNT(*)::int, COUNT(DISTINCT s.user_id)::int, SUM(u.quantity)::bigint
		FROM lab_usage_events u
		JOIN lab_sessions s ON s.id = u.session_id
		JOIN lab_definitions l ON l.id = s.lab_id
		JOIN courses c ON c.id = l.course_id
		WHERE u.org_id = $1 AND u.event_type = 'container_seconds' AND u.recorded_at > $2
		GROUP BY c.id, c.title
		ORDER BY SUM(u.quantity) DESC`,
		orgID, time.Now().Add(-window),
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.GetCourseLabUsage: %w", err)
	}
	defer rows.Close()

	out := []CourseLabUsageRow{}
	for rows.Next() {
		var row CourseLabUsageRow
		if err := rows.Scan(&row.CourseID, &row.CourseTitle, &row.Sessions, &row.StudentCount, &row.ContainerSeconds); err != nil {
			return nil, fmt.Errorf("labs.Repo.GetCourseLabUsage: scan: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// StudentLabUsageRow is one student's contribution to an org-wide usage
// window.
type StudentLabUsageRow struct {
	UserID           string `json:"user_id"`
	Name             string `json:"name"`
	Email            string `json:"email"`
	Sessions         int    `json:"sessions"`
	ContainerSeconds int64  `json:"container_seconds"`
}

// GetStudentLabUsage breaks down container_seconds usage by student for
// orgID within the trailing window, highest usage first — the shape an admin
// wants for spotting a single account burning disproportionate compute.
func (r *Repo) GetStudentLabUsage(ctx context.Context, orgID string, window time.Duration, limit int) ([]StudentLabUsageRow, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT s.user_id, u.name, u.email, COUNT(*)::int, SUM(ev.quantity)::bigint
		FROM lab_usage_events ev
		JOIN lab_sessions s ON s.id = ev.session_id
		JOIN users u ON u.id = s.user_id
		WHERE ev.org_id = $1 AND ev.event_type = 'container_seconds' AND ev.recorded_at > $2
		GROUP BY s.user_id, u.name, u.email
		ORDER BY SUM(ev.quantity) DESC
		LIMIT $3`,
		orgID, time.Now().Add(-window), limit,
	)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.GetStudentLabUsage: %w", err)
	}
	defer rows.Close()

	out := []StudentLabUsageRow{}
	for rows.Next() {
		var row StudentLabUsageRow
		if err := rows.Scan(&row.UserID, &row.Name, &row.Email, &row.Sessions, &row.ContainerSeconds); err != nil {
			return nil, fmt.Errorf("labs.Repo.GetStudentLabUsage: scan: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

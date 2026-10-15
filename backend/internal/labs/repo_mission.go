package labs

import (
	"context"
	"fmt"
)

// StartMission starts the mission clock: the session keeps its original time
// budget (expires_at - started_at) but counts it from now. A no-op when the
// mission already started or the session is not running.
func (r *Repo) StartMission(ctx context.Context, sessionID, userID string) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE lab_sessions
		SET mission_started_at = now(), expires_at = now() + (expires_at - started_at)
		WHERE id=$1 AND user_id=$2 AND mission_started_at IS NULL
		  AND status='running' AND expires_at > now()`,
		sessionID, userID,
	); err != nil {
		return fmt.Errorf("labs.Repo.StartMission: %w", err)
	}
	return nil
}

// InsertActivity stores a validated batch, dropping whatever would push the
// session past ActivityMaxPerSession.
func (r *Repo) InsertActivity(ctx context.Context, sessionID string, events []ActivityEventInput) error {
	types := make([]string, len(events))
	details := make([]string, len(events))
	values := make([]int32, len(events))
	for i, e := range events {
		types[i], details[i], values[i] = e.Type, e.Detail, int32(e.Value)
	}
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO lab_activity_events (session_id, event_type, detail, value)
		SELECT $1, t.event_type, t.detail, t.value
		FROM unnest($2::text[], $3::text[], $4::int[]) WITH ORDINALITY AS t(event_type, detail, value, ord)
		WHERE t.ord <= GREATEST(0, $5::bigint - (SELECT count(*) FROM lab_activity_events WHERE session_id = $1))
		ORDER BY t.ord`,
		sessionID, types, details, values, ActivityMaxPerSession,
	); err != nil {
		return fmt.Errorf("labs.Repo.InsertActivity: %w", err)
	}
	return nil
}

// ActivitySummary aggregates a session's recorded events.
func (r *Repo) ActivitySummary(ctx context.Context, sessionID string) (*ActivitySummary, error) {
	sum := ActivitySummary{FilesOpened: []ActivityFile{}, Recent: []ActivityEvent{}}
	if err := r.pool.QueryRow(ctx, `
		SELECT count(*) FILTER (WHERE event_type = 'tab_away'),
		       COALESCE(sum(value) FILTER (WHERE event_type = 'tab_away'), 0),
		       count(*) FILTER (WHERE event_type = 'paste'),
		       COALESCE(sum(value) FILTER (WHERE event_type = 'paste'), 0)
		FROM lab_activity_events WHERE session_id = $1`, sessionID,
	).Scan(&sum.TabAwayCount, &sum.TabAwayTotalMs, &sum.PasteCount, &sum.PasteChars); err != nil {
		return nil, fmt.Errorf("labs.Repo.ActivitySummary: totals: %w", err)
	}

	files, err := r.pool.Query(ctx, `
		SELECT detail, count(*) FROM lab_activity_events
		WHERE session_id = $1 AND event_type = 'file_open'
		GROUP BY detail ORDER BY count(*) DESC, detail LIMIT $2`, sessionID, ActivityFilesLimit)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ActivitySummary: files: %w", err)
	}
	defer files.Close()
	for files.Next() {
		var f ActivityFile
		if err := files.Scan(&f.Path, &f.Opens); err != nil {
			return nil, fmt.Errorf("labs.Repo.ActivitySummary: scan file: %w", err)
		}
		sum.FilesOpened = append(sum.FilesOpened, f)
	}
	if err := files.Err(); err != nil {
		return nil, fmt.Errorf("labs.Repo.ActivitySummary: files rows: %w", err)
	}

	recent, err := r.pool.Query(ctx, `
		SELECT event_type, detail, value, occurred_at FROM lab_activity_events
		WHERE session_id = $1 ORDER BY occurred_at DESC, id DESC LIMIT $2`, sessionID, ActivityRecentLimit)
	if err != nil {
		return nil, fmt.Errorf("labs.Repo.ActivitySummary: recent: %w", err)
	}
	defer recent.Close()
	for recent.Next() {
		var e ActivityEvent
		if err := recent.Scan(&e.Type, &e.Detail, &e.Value, &e.OccurredAt); err != nil {
			return nil, fmt.Errorf("labs.Repo.ActivitySummary: scan event: %w", err)
		}
		sum.Recent = append(sum.Recent, e)
	}
	if err := recent.Err(); err != nil {
		return nil, fmt.Errorf("labs.Repo.ActivitySummary: recent rows: %w", err)
	}
	return &sum, nil
}

// SetDebugUI merges debug_ui into org_settings.labs, leaving the namespace's
// other keys (concurrency, durations, allowed images) untouched.
func (r *Repo) SetDebugUI(ctx context.Context, orgID, mode string) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO org_settings (org_id, labs, updated_at)
		VALUES ($1, jsonb_build_object('debug_ui', $2::text), now())
		ON CONFLICT (org_id) DO UPDATE
		SET labs = org_settings.labs || jsonb_build_object('debug_ui', $2::text), updated_at = now()`,
		orgID, mode,
	); err != nil {
		return fmt.Errorf("labs.Repo.SetDebugUI: %w", err)
	}
	return nil
}

package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_meetings.go — project_meetings / meeting_attendance / standup_updates
// data layer (contract-phase3.md's Meetings/Standups section).

// InsertMeeting appends the project_meetings row for a calendar event already
// created (calendar.Service.CreateEvent runs its own transaction — see
// service_meetings.go's own doc comment on why this isn't one shared tx).
func (r *Repo) InsertMeeting(ctx context.Context, db DBTX, calendarEventID, projectID, kind string, itemID, notesPageID *string, createdBy string) error {
	if _, err := db.Exec(ctx,
		`INSERT INTO project_meetings (calendar_event_id, project_id, kind, item_id, notes_wiki_page_id, created_by)
		 VALUES ($1,$2,$3,$4,$5,$6)`,
		calendarEventID, projectID, kind, itemID, notesPageID, createdBy,
	); err != nil {
		return fmt.Errorf("workspace: insert meeting: %w", err)
	}
	return nil
}

const meetingColumns = `m.calendar_event_id, m.kind, e.title, e.starts_at, e.ends_at, e.recurrence_rule, e.meeting_url,
	m.item_id, m.notes_wiki_page_id, m.created_by, m.created_at`

func scanMeeting(row pgx.Row) (*Meeting, error) {
	var mt Meeting
	err := row.Scan(&mt.CalendarEventID, &mt.Kind, &mt.Title, &mt.StartsAt, &mt.EndsAt, &mt.RecurrenceRule, &mt.MeetingURL,
		&mt.ItemID, &mt.NotesWikiPageID, &mt.CreatedBy, &mt.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan meeting: %w", err)
	}
	return &mt, nil
}

// ListMeetings cursor-paginates a project's meetings, newest-scheduled first.
func (r *Repo) ListMeetings(ctx context.Context, db DBTX, projectID string, cursorAt time.Time, cursorID string, limit int) ([]Meeting, error) {
	var rows pgx.Rows
	var err error
	if cursorAt.IsZero() {
		rows, err = db.Query(ctx,
			`SELECT `+meetingColumns+` FROM project_meetings m JOIN calendar_events e ON e.id = m.calendar_event_id
			  WHERE m.project_id = $1 ORDER BY m.created_at DESC, m.calendar_event_id DESC LIMIT $2`,
			projectID, limit)
	} else {
		rows, err = db.Query(ctx,
			`SELECT `+meetingColumns+` FROM project_meetings m JOIN calendar_events e ON e.id = m.calendar_event_id
			  WHERE m.project_id = $1 AND (m.created_at, m.calendar_event_id) < ($2, $3)
			  ORDER BY m.created_at DESC, m.calendar_event_id DESC LIMIT $4`,
			projectID, cursorAt, cursorID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("workspace: list meetings: %w", err)
	}
	defer rows.Close()
	out := []Meeting{}
	for rows.Next() {
		mt, err := scanMeeting(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *mt)
	}
	return out, rows.Err()
}

// GetMeeting scopes a single meeting to its project — the IDOR guard for
// RecordAttendance/ConvertActionItem.
func (r *Repo) GetMeeting(ctx context.Context, db DBTX, projectID, calendarEventID string) (*Meeting, error) {
	return scanMeeting(db.QueryRow(ctx,
		`SELECT `+meetingColumns+` FROM project_meetings m JOIN calendar_events e ON e.id = m.calendar_event_id
		  WHERE m.calendar_event_id = $1 AND m.project_id = $2`,
		calendarEventID, projectID))
}

// UpsertAttendance records one attendee's status for one occurrence —
// PRIMARY KEY (calendar_event_id, occurrence_at, user_id) makes a re-submit
// for the same occurrence an update, not a duplicate.
func (r *Repo) UpsertAttendance(ctx context.Context, tx pgx.Tx, calendarEventID string, occurrenceAt time.Time, userID, status, recordedBy string) error {
	if _, err := tx.Exec(ctx,
		`INSERT INTO meeting_attendance (calendar_event_id, occurrence_at, user_id, status, recorded_by)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (calendar_event_id, occurrence_at, user_id)
		   DO UPDATE SET status = EXCLUDED.status, recorded_by = EXCLUDED.recorded_by, recorded_at = now()`,
		calendarEventID, occurrenceAt, userID, status, recordedBy,
	); err != nil {
		return fmt.Errorf("workspace: upsert attendance: %w", err)
	}
	return nil
}

// ─── Standups ─────────────────────────────────────────────────────────────────

// UpsertStandup writes today's (or a given day's, but PostStandup always
// passes the caller's current UTC date) update for one user, replacing any
// existing row for that (project, user, day).
func (r *Repo) UpsertStandup(ctx context.Context, db DBTX, projectID, userID, standupOn, yesterday, today string, blockers *string) (*Standup, error) {
	row := db.QueryRow(ctx,
		`INSERT INTO standup_updates (project_id, user_id, standup_on, yesterday, today, blockers)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (project_id, user_id, standup_on)
		   DO UPDATE SET yesterday = EXCLUDED.yesterday, today = EXCLUDED.today, blockers = EXCLUDED.blockers, updated_at = now()
		 RETURNING (SELECT name FROM users WHERE id = $2), standup_on, yesterday, today, blockers, updated_at`,
		projectID, userID, standupOn, yesterday, today, blockers,
	)
	var s Standup
	if err := row.Scan(&s.Name, &s.StandupOn, &s.Yesterday, &s.Today, &s.Blockers, &s.UpdatedAt); err != nil {
		return nil, fmt.Errorf("workspace: upsert standup: %w", err)
	}
	s.UserID = userID
	s.BlockerKeys = []ItemRef{}
	return &s, nil
}

// ListStandups returns every standup posted for one project+day.
func (r *Repo) ListStandups(ctx context.Context, db DBTX, projectID, standupOn string) ([]Standup, error) {
	rows, err := db.Query(ctx,
		`SELECT s.user_id, COALESCE(u.name, 'Former member'), s.standup_on, s.yesterday, s.today, s.blockers, s.updated_at
		   FROM standup_updates s LEFT JOIN users u ON u.id = s.user_id
		  WHERE s.project_id = $1 AND s.standup_on = $2
		  ORDER BY s.updated_at DESC`,
		projectID, standupOn)
	if err != nil {
		return nil, fmt.Errorf("workspace: list standups: %w", err)
	}
	defer rows.Close()
	out := []Standup{}
	for rows.Next() {
		var s Standup
		if err := rows.Scan(&s.UserID, &s.Name, &s.StandupOn, &s.Yesterday, &s.Today, &s.Blockers, &s.UpdatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan standup: %w", err)
		}
		s.BlockerKeys = []ItemRef{}
		out = append(out, s)
	}
	return out, rows.Err()
}

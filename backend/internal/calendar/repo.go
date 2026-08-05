package calendar

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrNotFound is returned when a lookup scoped to an org/user finds no row.
var ErrNotFound = errors.New("calendar: not found")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, committing on success and rolling back on
// any error fn returns. Mirrors mentoring.Repo's tx helper.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("calendar: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("calendar: commit tx: %w", err)
	}
	return nil
}

// rowScanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query).
type rowScanner interface {
	Scan(dest ...any) error
}

const eventColumns = `id, org_id, created_by, event_type, title, notes, meeting_url,
	starts_at, ends_at, all_day, visibility, batch_id, course_id, entity_type, entity_id,
	recurrence_rule, recurrence_parent_id, excluded_occurrences, status, completed_at, priority, created_at, updated_at`

func scanEvent(row rowScanner) (Event, error) {
	var e Event
	err := row.Scan(&e.ID, &e.OrgID, &e.CreatedBy, &e.EventType, &e.Title, &e.Notes, &e.MeetingURL,
		&e.StartsAt, &e.EndsAt, &e.AllDay, &e.Visibility, &e.BatchID, &e.CourseID, &e.EntityType, &e.EntityID,
		&e.RecurrenceRule, &e.RecurrenceParentID, &e.ExcludedOccurrences, &e.Status, &e.CompletedAt, &e.Priority, &e.CreatedAt, &e.UpdatedAt)
	return e, err
}

// CreateTx inserts a new calendar_events row within tx.
func (r *Repo) CreateTx(ctx context.Context, tx pgx.Tx, e Event) (Event, error) {
	row := tx.QueryRow(ctx,
		`INSERT INTO calendar_events (org_id, created_by, event_type, title, notes, meeting_url,
		   starts_at, ends_at, all_day, visibility, batch_id, course_id, entity_type, entity_id,
		   recurrence_rule, recurrence_parent_id, priority)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
		 RETURNING `+eventColumns,
		e.OrgID, e.CreatedBy, e.EventType, e.Title, e.Notes, e.MeetingURL,
		e.StartsAt, e.EndsAt, e.AllDay, e.Visibility, e.BatchID, e.CourseID, e.EntityType, e.EntityID,
		e.RecurrenceRule, e.RecurrenceParentID, e.Priority)
	created, err := scanEvent(row)
	if err != nil {
		return Event{}, fmt.Errorf("calendar: create event: %w", err)
	}
	return created, nil
}

// AddAttendeeTx inserts (or, on conflict, updates the role of) an attendee
// within tx.
func (r *Repo) AddAttendeeTx(ctx context.Context, tx pgx.Tx, eventID, userID, role string) error {
	_, err := tx.Exec(ctx,
		`INSERT INTO calendar_event_attendees (event_id, user_id, role)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (event_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
		eventID, userID, role)
	if err != nil {
		return fmt.Errorf("calendar: add attendee: %w", err)
	}
	return nil
}

// GetByID returns a single event scoped to orgID, real or already-detached
// (recurrence_parent_id set); virtual assessment entries are never persisted
// so they cannot be fetched here.
func (r *Repo) GetByID(ctx context.Context, orgID, eventID string) (Event, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+eventColumns+` FROM calendar_events WHERE id = $1 AND org_id = $2`, eventID, orgID)
	e, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: get event: %w", err)
	}
	return e, nil
}

// GetEventUnscoped returns an event by ID with no org filter. Only used by
// the invite-accept flow, where the possession of a valid (unexpired,
// unaccepted) invite token IS the authorization — there is no caller org
// context yet to scope against.
func (r *Repo) GetEventUnscoped(ctx context.Context, eventID string) (Event, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+eventColumns+` FROM calendar_events WHERE id = $1`, eventID)
	e, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: get event unscoped: %w", err)
	}
	return e, nil
}

// GetAttendees returns every attendee of eventID, enriched with name/email.
func (r *Repo) GetAttendees(ctx context.Context, eventID string) ([]Attendee, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT cea.event_id, cea.user_id, cea.role, cea.rsvp_status, u.name, u.email
		 FROM calendar_event_attendees cea
		 JOIN users u ON u.id = cea.user_id
		 WHERE cea.event_id = $1
		 ORDER BY cea.role, u.name`, eventID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list attendees: %w", err)
	}
	defer rows.Close()
	out := []Attendee{}
	for rows.Next() {
		var a Attendee
		if err := rows.Scan(&a.EventID, &a.UserID, &a.Role, &a.RSVPStatus, &a.Name, &a.Email); err != nil {
			return nil, fmt.Errorf("calendar: scan attendee: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// GetAttendeeRole returns the caller's attendee role on eventID, or ok=false
// if they are not an attendee.
func (r *Repo) GetAttendeeRole(ctx context.Context, eventID, userID string) (role string, ok bool, err error) {
	err = r.pool.QueryRow(ctx,
		`SELECT role FROM calendar_event_attendees WHERE event_id = $1 AND user_id = $2`,
		eventID, userID,
	).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("calendar: get attendee role: %w", err)
	}
	return role, true, nil
}

// Update overwrites the mutable fields of an event scoped to orgID, including
// its recurrence_rule (a scope=series edit may reshape the whole series —
// e.g. weekly to biweekly). recurrence_parent_id/excluded_occurrences/status
// are managed by dedicated methods, not this general-purpose update.
func (r *Repo) Update(ctx context.Context, orgID string, e Event) (Event, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE calendar_events
		 SET title = $1, notes = $2, meeting_url = $3, starts_at = $4, ends_at = $5,
		     all_day = $6, visibility = $7, batch_id = $8, course_id = $9,
		     entity_type = $10, entity_id = $11, recurrence_rule = $12, priority = $13, updated_at = now()
		 WHERE id = $14 AND org_id = $15
		 RETURNING `+eventColumns,
		e.Title, e.Notes, e.MeetingURL, e.StartsAt, e.EndsAt, e.AllDay, e.Visibility,
		e.BatchID, e.CourseID, e.EntityType, e.EntityID, e.RecurrenceRule, e.Priority, e.ID, orgID)
	updated, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: update event: %w", err)
	}
	return updated, nil
}

// CreateDetachedTx inserts a standalone copy of a recurring master's single
// occurrence within tx: recurrence_rule is cleared, recurrence_parent_id
// points at the master, and starts_at/ends_at are pinned to that occurrence.
func (r *Repo) CreateDetachedTx(ctx context.Context, tx pgx.Tx, e Event) (Event, error) {
	row := tx.QueryRow(ctx,
		`INSERT INTO calendar_events (org_id, created_by, event_type, title, notes, meeting_url,
		   starts_at, ends_at, all_day, visibility, batch_id, course_id, entity_type, entity_id,
		   recurrence_parent_id, priority)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
		 RETURNING `+eventColumns,
		e.OrgID, e.CreatedBy, e.EventType, e.Title, e.Notes, e.MeetingURL,
		e.StartsAt, e.EndsAt, e.AllDay, e.Visibility, e.BatchID, e.CourseID, e.EntityType, e.EntityID,
		e.RecurrenceParentID, e.Priority)
	created, err := scanEvent(row)
	if err != nil {
		return Event{}, fmt.Errorf("calendar: create detached occurrence: %w", err)
	}
	return created, nil
}

// AddExcludedOccurrenceTx appends occurrenceStart to the master event's
// excluded_occurrences array within tx, so future ExpandOccurrences calls
// skip the slot now covered by a detached row.
func (r *Repo) AddExcludedOccurrenceTx(ctx context.Context, tx pgx.Tx, orgID, eventID string, occurrenceStart time.Time) error {
	tag, err := tx.Exec(ctx,
		`UPDATE calendar_events
		 SET excluded_occurrences = array_append(excluded_occurrences, $1), updated_at = now()
		 WHERE id = $2 AND org_id = $3`,
		occurrenceStart, eventID, orgID)
	if err != nil {
		return fmt.Errorf("calendar: exclude occurrence: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Cancel marks an event (or an entire recurring series, if eventID is the
// master row) cancelled.
func (r *Repo) Cancel(ctx context.Context, orgID, eventID string) (Event, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE calendar_events SET status = $1, updated_at = now()
		 WHERE id = $2 AND org_id = $3
		 RETURNING `+eventColumns,
		EventStatusCancelled, eventID, orgID)
	e, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: cancel event: %w", err)
	}
	return e, nil
}

// Restore un-cancels an event previously cancelled by Cancel — the mirror
// operation, used to revert an MCP delete_calendar_event call. Only flips a
// currently-cancelled row, so it can't accidentally "restore" an event that
// was never deleted.
func (r *Repo) Restore(ctx context.Context, orgID, eventID string) (Event, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE calendar_events SET status = $1, updated_at = now()
		 WHERE id = $2 AND org_id = $3 AND status = $4
		 RETURNING `+eventColumns,
		EventStatusScheduled, eventID, orgID, EventStatusCancelled)
	e, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: restore event: %w", err)
	}
	return e, nil
}

// UpdateRSVP sets the caller's own rsvp_status on eventID. Returns
// ErrNotFound if the caller is not an attendee of eventID.
func (r *Repo) UpdateRSVP(ctx context.Context, eventID, userID, status string) (Attendee, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE calendar_event_attendees SET rsvp_status = $1
		 WHERE event_id = $2 AND user_id = $3
		 RETURNING event_id, user_id, role, rsvp_status`,
		status, eventID, userID)
	var a Attendee
	err := row.Scan(&a.EventID, &a.UserID, &a.Role, &a.RSVPStatus)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Attendee{}, ErrNotFound
		}
		return Attendee{}, fmt.Errorf("calendar: update rsvp: %w", err)
	}
	return a, nil
}

// CanAccessEvent reports whether userID may view eventID within orgID: they
// are an attendee, the event is org-visibility 'public', or it belongs to a
// batch/course they're a member of.
func (r *Repo) CanAccessEvent(ctx context.Context, orgID, eventID, userID string) (bool, error) {
	var ok bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM calendar_events ce
		   WHERE ce.id = $1 AND ce.org_id = $2
		     AND (
		       EXISTS(SELECT 1 FROM calendar_event_attendees WHERE event_id = ce.id AND user_id = $3)
		       OR ce.visibility = 'public'
		       OR (ce.batch_id IS NOT NULL AND ce.batch_id IN (SELECT batch_id FROM batch_members WHERE user_id = $3))
		       OR (ce.course_id IS NOT NULL AND ce.course_id IN (SELECT course_id FROM enrollments WHERE user_id = $3))
		     )
		 )`, eventID, orgID, userID).Scan(&ok)
	if err != nil {
		return false, fmt.Errorf("calendar: check event access: %w", err)
	}
	return ok, nil
}

// UpdateNotes overwrites only the notes field of an event scoped to orgID.
func (r *Repo) UpdateNotes(ctx context.Context, orgID, eventID string, notes *string) (Event, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE calendar_events SET notes = $1, updated_at = now()
		 WHERE id = $2 AND org_id = $3
		 RETURNING `+eventColumns,
		notes, eventID, orgID)
	e, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: update notes: %w", err)
	}
	return e, nil
}

// SetCompleted checks (completed=true) or unchecks (completed=false) a task
// event scoped to orgID.
func (r *Repo) SetCompleted(ctx context.Context, orgID, eventID string, completed bool) (Event, error) {
	var completedAt *time.Time
	if completed {
		now := time.Now()
		completedAt = &now
	}
	row := r.pool.QueryRow(ctx,
		`UPDATE calendar_events SET completed_at = $1, updated_at = now()
		 WHERE id = $2 AND org_id = $3
		 RETURNING `+eventColumns,
		completedAt, eventID, orgID)
	e, err := scanEvent(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, fmt.Errorf("calendar: set completed: %w", err)
	}
	return e, nil
}

// AttendeeIDRole is a minimal (user_id, role) pair — the data
// ListAttendeeUserIDsTx needs to replicate a master event's attendee list
// onto a newly detached single-occurrence row.
type AttendeeIDRole struct {
	UserID string
	Role   string
}

// ListAttendeeUserIDsTx returns every attendee (user_id, role) for eventID
// within tx — used to copy a recurring master's attendee list onto a newly
// detached single-occurrence row.
func (r *Repo) ListAttendeeUserIDsTx(ctx context.Context, tx pgx.Tx, eventID string) ([]AttendeeIDRole, error) {
	rows, err := tx.Query(ctx, `SELECT user_id, role FROM calendar_event_attendees WHERE event_id = $1`, eventID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list attendee ids: %w", err)
	}
	defer rows.Close()
	var out []AttendeeIDRole
	for rows.Next() {
		var u AttendeeIDRole
		if err := rows.Scan(&u.UserID, &u.Role); err != nil {
			return nil, fmt.Errorf("calendar: scan attendee id: %w", err)
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// ListRange returns every event userID may see in orgID whose window
// overlaps [from, to]: real calendar_events (expanded from recurring rules)
// the user attends, or that belong to a batch/course they're a member of, or
// that are org-visibility 'public' — unioned with read-only virtual entries
// for org assessments, batches, courses, and lessons (course_modules) that
// have a starts_at/ends_at window and that the user is assigned/enrolled to
// see (the assessment condition mirrors assessment.Repo.IsUserAssigned's
// access check).
func (r *Repo) ListRange(ctx context.Context, orgID, userID string, from, to time.Time) ([]Event, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+eventColumns+`
		 FROM calendar_events ce
		 WHERE ce.org_id = $1
		   AND ce.status = 'scheduled'
		   AND (
		     (ce.recurrence_rule IS NULL AND ce.starts_at <= $3 AND COALESCE(ce.ends_at, ce.starts_at) >= $2)
		     OR (ce.recurrence_rule IS NOT NULL AND ce.starts_at <= $3)
		   )
		   AND (
		     EXISTS (SELECT 1 FROM calendar_event_attendees cea WHERE cea.event_id = ce.id AND cea.user_id = $4)
		     OR (ce.batch_id IS NOT NULL AND ce.batch_id IN (SELECT batch_id FROM batch_members WHERE user_id = $4))
		     OR (ce.course_id IS NOT NULL AND ce.course_id IN (SELECT course_id FROM enrollments WHERE user_id = $4))
		     OR ce.visibility = 'public'
		   )`,
		orgID, from, to, userID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list range: %w", err)
	}
	var bases []Event
	for rows.Next() {
		e, err := scanEvent(rows)
		if err != nil {
			rows.Close()
			return nil, fmt.Errorf("calendar: scan event: %w", err)
		}
		bases = append(bases, e)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("calendar: list range rows: %w", err)
	}
	rows.Close()

	out := []Event{}
	for _, e := range bases {
		if e.RecurrenceRule == nil || *e.RecurrenceRule == "" {
			out = append(out, e)
			continue
		}
		occurrences, err := ExpandOccurrences(e, from, to)
		if err != nil {
			return nil, fmt.Errorf("calendar: expand occurrences for event %s: %w", e.ID, err)
		}
		out = append(out, occurrences...)
	}

	virtual, err := r.listVirtualAssessmentEvents(ctx, orgID, userID, from, to)
	if err != nil {
		return nil, err
	}
	out = append(out, virtual...)

	batchEvents, err := r.listVirtualBatchEvents(ctx, orgID, userID, from, to)
	if err != nil {
		return nil, err
	}
	out = append(out, batchEvents...)

	courseEvents, err := r.listVirtualCourseEvents(ctx, orgID, userID, from, to)
	if err != nil {
		return nil, err
	}
	out = append(out, courseEvents...)

	lessonEvents, err := r.listVirtualLessonEvents(ctx, orgID, userID, from, to)
	if err != nil {
		return nil, err
	}
	out = append(out, lessonEvents...)

	return out, nil
}

// listVirtualAssessmentEvents returns read-only Event values (IsVirtual=true,
// EventType=EventTypeAssessment) for every assessment in orgID that has a
// starts_at/ends_at window overlapping [from, to] and that userID may take —
// the same access condition assessment.Repo.IsUserAssigned checks
// (assessment_assignments direct/batch grant, or enrollment in a course
// whose module embeds the assessment), reimplemented here as a set filter
// (rather than imported) because assessment.Repo only exposes a per-ID
// existence check, not a list query, and importing assessment here for one
// query would pull in that package's whole dependency graph.
func (r *Repo) listVirtualAssessmentEvents(ctx context.Context, orgID, userID string, from, to time.Time) ([]Event, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT a.id, a.title, a.starts_at, a.ends_at
		 FROM assessments a
		 WHERE a.org_id = $1
		   AND a.starts_at IS NOT NULL
		   AND a.starts_at <= $3 AND COALESCE(a.ends_at, a.starts_at) >= $2
		   AND (
		     EXISTS (
		       SELECT 1 FROM content_assignments ca
		       WHERE ca.content_type = 'assessment' AND ca.content_id = a.id
		         AND (
		           (ca.assignee_type = 'user' AND ca.assignee_id = $4)
		           OR (ca.assignee_type = 'batch' AND ca.assignee_id IN (
		                 SELECT batch_id FROM batch_members WHERE user_id = $4))
		         )
		     )
		     OR EXISTS (
		       SELECT 1 FROM course_modules cm
		       JOIN enrollments e ON e.course_id = cm.course_id
		       WHERE cm.assessment_id = a.id AND e.user_id = $4
		     )
		   )`,
		orgID, from, to, userID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list virtual assessment events: %w", err)
	}
	defer rows.Close()

	out := []Event{}
	for rows.Next() {
		var e Event
		var endsAt *time.Time
		if err := rows.Scan(&e.ID, &e.Title, &e.StartsAt, &endsAt); err != nil {
			return nil, fmt.Errorf("calendar: scan virtual assessment event: %w", err)
		}
		e.OrgID = orgID
		e.EventType = EventTypeAssessment
		e.EndsAt = endsAt
		e.Visibility = VisibilityPrivate
		e.Status = EventStatusScheduled
		e.IsVirtual = true
		out = append(out, e)
	}
	return out, rows.Err()
}

// listVirtualBatchEvents returns read-only Event values (IsVirtual=true,
// EventType=EventTypeBatch) for every batch in orgID that has a
// starts_at/ends_at window overlapping [from, to] and that userID is a
// member or mentor of.
func (r *Repo) listVirtualBatchEvents(ctx context.Context, orgID, userID string, from, to time.Time) ([]Event, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT b.id, b.name, b.starts_at, b.ends_at
		 FROM batches b
		 WHERE b.org_id = $1
		   AND b.starts_at IS NOT NULL
		   AND b.starts_at <= $3 AND COALESCE(b.ends_at, b.starts_at) >= $2
		   AND (
		     EXISTS (SELECT 1 FROM batch_members bm WHERE bm.batch_id = b.id AND bm.user_id = $4)
		     OR EXISTS (SELECT 1 FROM batch_members bm WHERE bm.batch_id = b.id AND bm.user_id = $4 AND bm.role = 'mentor')
		   )`,
		orgID, from, to, userID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list virtual batch events: %w", err)
	}
	defer rows.Close()

	out := []Event{}
	for rows.Next() {
		var e Event
		var endsAt *time.Time
		if err := rows.Scan(&e.ID, &e.Title, &e.StartsAt, &endsAt); err != nil {
			return nil, fmt.Errorf("calendar: scan virtual batch event: %w", err)
		}
		e.OrgID = orgID
		e.EventType = EventTypeBatch
		e.EndsAt = endsAt
		e.Visibility = VisibilityPrivate
		e.Status = EventStatusScheduled
		e.IsVirtual = true
		out = append(out, e)
	}
	return out, rows.Err()
}

// listVirtualCourseEvents returns read-only Event values (IsVirtual=true,
// EventType=EventTypeCourse) for every course in orgID that has a
// starts_at/ends_at window overlapping [from, to] and that userID is
// enrolled in.
func (r *Repo) listVirtualCourseEvents(ctx context.Context, orgID, userID string, from, to time.Time) ([]Event, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT c.id, c.title, c.starts_at, c.ends_at
		 FROM courses c
		 JOIN enrollments e ON e.course_id = c.id
		 WHERE c.org_id = $1
		   AND e.user_id = $4
		   AND c.starts_at IS NOT NULL
		   AND c.starts_at <= $3 AND COALESCE(c.ends_at, c.starts_at) >= $2`,
		orgID, from, to, userID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list virtual course events: %w", err)
	}
	defer rows.Close()

	out := []Event{}
	for rows.Next() {
		var e Event
		var endsAt *time.Time
		if err := rows.Scan(&e.ID, &e.Title, &e.StartsAt, &endsAt); err != nil {
			return nil, fmt.Errorf("calendar: scan virtual course event: %w", err)
		}
		e.OrgID = orgID
		e.EventType = EventTypeCourse
		e.EndsAt = endsAt
		e.Visibility = VisibilityPrivate
		e.Status = EventStatusScheduled
		e.IsVirtual = true
		out = append(out, e)
	}
	return out, rows.Err()
}

// listVirtualLessonEvents returns read-only Event values (IsVirtual=true,
// EventType=EventTypeLesson) for every course_module (lesson) in orgID that
// has a starts_at/ends_at window overlapping [from, to] and belongs to a
// course userID is enrolled in.
func (r *Repo) listVirtualLessonEvents(ctx context.Context, orgID, userID string, from, to time.Time) ([]Event, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT cm.id, cm.title, cm.starts_at, cm.ends_at
		 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 JOIN enrollments e ON e.course_id = cm.course_id
		 WHERE c.org_id = $1
		   AND e.user_id = $4
		   AND cm.deleted_at IS NULL
		   AND cm.starts_at IS NOT NULL
		   AND cm.starts_at <= $3 AND COALESCE(cm.ends_at, cm.starts_at) >= $2`,
		orgID, from, to, userID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list virtual lesson events: %w", err)
	}
	defer rows.Close()

	out := []Event{}
	for rows.Next() {
		var e Event
		var endsAt *time.Time
		if err := rows.Scan(&e.ID, &e.Title, &e.StartsAt, &endsAt); err != nil {
			return nil, fmt.Errorf("calendar: scan virtual lesson event: %w", err)
		}
		e.OrgID = orgID
		e.EventType = EventTypeLesson
		e.EndsAt = endsAt
		e.Visibility = VisibilityPrivate
		e.Status = EventStatusScheduled
		e.IsVirtual = true
		out = append(out, e)
	}
	return out, rows.Err()
}

// ListDueForReminder returns every scheduled event (across all orgs) whose
// window could contain an occurrence starting within [from, to]: a
// non-recurring event whose own starts_at falls in that window, or a
// recurring master whose series hasn't necessarily ended yet
// (starts_at <= to — the caller must still run ExpandOccurrences on each
// returned master and check whether it actually produced an occurrence
// inside [from, to], since this query can't evaluate COUNT/UNTIL/INTERVAL
// in SQL). Used only by the calendar reminder cron job
// (jobs/handlers/calendar_reminder.go), which is system-wide, not
// org-scoped — unlike every other Repo method here.
func (r *Repo) ListDueForReminder(ctx context.Context, from, to time.Time) ([]Event, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+eventColumns+`
		 FROM calendar_events
		 WHERE status = 'scheduled'
		   AND (
		     (recurrence_rule IS NULL AND starts_at >= $1 AND starts_at <= $2)
		     OR (recurrence_rule IS NOT NULL AND starts_at <= $2)
		   )`,
		from, to)
	if err != nil {
		return nil, fmt.Errorf("calendar: list due for reminder: %w", err)
	}
	defer rows.Close()
	out := []Event{}
	for rows.Next() {
		e, err := scanEvent(rows)
		if err != nil {
			return nil, fmt.Errorf("calendar: scan due event: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ─── personal ICS feed tokens ───────────────────────────────────────────────

// GetFeedTokenHash returns the stored token hash for (userID, orgID), if any.
func (r *Repo) GetFeedTokenHash(ctx context.Context, userID, orgID string) (string, bool, error) {
	var hash string
	err := r.pool.QueryRow(ctx,
		`SELECT token_hash FROM auth_tokens WHERE purpose = 'calendar_feed' AND user_id = $1 AND org_id = $2`,
		userID, orgID,
	).Scan(&hash)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("calendar: get feed token: %w", err)
	}
	return hash, true, nil
}

// UpsertFeedTokenHash stores (replacing any existing) the feed token hash for
// (userID, orgID).
func (r *Repo) UpsertFeedTokenHash(ctx context.Context, userID, orgID, tokenHash string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO auth_tokens (purpose, token_hash, user_id, org_id, payload, expires_at)
		 VALUES ('calendar_feed', $1, $2, $3, '{}'::jsonb, 'infinity'::timestamptz)
		 ON CONFLICT (token_hash) DO UPDATE SET expires_at = 'infinity'::timestamptz`,
		tokenHash, userID, orgID)
	if err != nil {
		return fmt.Errorf("calendar: upsert feed token: %w", err)
	}
	return nil
}

// ResolveFeedTokenHash returns the (userID, orgID) that own tokenHash.
func (r *Repo) ResolveFeedTokenHash(ctx context.Context, tokenHash string) (userID, orgID string, err error) {
	err = r.pool.QueryRow(ctx,
		`SELECT user_id, org_id FROM auth_tokens WHERE purpose = 'calendar_feed' AND token_hash = $1`,
		tokenHash,
	).Scan(&userID, &orgID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNotFound
	}
	if err != nil {
		return "", "", fmt.Errorf("calendar: resolve feed token: %w", err)
	}
	return userID, orgID, nil
}

// ─── external event invites ─────────────────────────────────────────────────

// CreateInvite inserts a pending external invite for eventID into calendar_event_attendees
// and creates an auth_tokens entry for the token.
func (r *Repo) CreateInvite(ctx context.Context, inv EventInvite) (EventInvite, error) {
	var attendeeID string
	err := r.pool.QueryRow(ctx,
		`INSERT INTO calendar_event_attendees (event_id, email, role, rsvp_status)
		 VALUES ($1, $2, $3, 'pending')
		 RETURNING id`,
		inv.EventID, inv.Email, inv.Role).Scan(&attendeeID)
	if err != nil {
		return EventInvite{}, fmt.Errorf("calendar: create attendee: %w", err)
	}

	// If token_hash is provided, insert into auth_tokens
	if inv.TokenHash != "" {
		payload, _ := json.Marshal(map[string]interface{}{
			"event_id": inv.EventID,
			"email":    inv.Email,
			"role":     inv.Role,
		})
		_, err := r.pool.Exec(ctx,
			`INSERT INTO auth_tokens (purpose, token_hash, payload, expires_at)
			 VALUES ('calendar_invite', $1, $2, $3)`,
			inv.TokenHash, payload, inv.ExpiresAt)
		if err != nil {
			return EventInvite{}, fmt.Errorf("calendar: create invite token: %w", err)
		}
	}

	inv.ID = attendeeID
	inv.AcceptedAt = nil
	inv.CreatedAt = time.Now()
	return inv, nil
}

// ListPendingInvitesByEvent returns eventID's pending external invites.
func (r *Repo) ListPendingInvitesByEvent(ctx context.Context, eventID string) ([]EventInvite, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT cea.id, cea.event_id, cea.email, cea.role, cea.created_at,
		        COALESCE(at.token_hash, ''), COALESCE(at.expires_at, now())
		 FROM calendar_event_attendees cea
		 LEFT JOIN auth_tokens at ON at.purpose = 'calendar_invite'
		   AND (at.payload->>'event_id')::uuid = cea.event_id
		   AND (at.payload->>'email') = cea.email
		 WHERE cea.event_id = $1 AND cea.rsvp_status = 'pending'
		 ORDER BY cea.created_at DESC`,
		eventID)
	if err != nil {
		return nil, fmt.Errorf("calendar: list pending invites: %w", err)
	}
	defer rows.Close()

	invites := make([]EventInvite, 0)
	for rows.Next() {
		var inv EventInvite
		var tokenHash string
		var expiresAt time.Time
		if err := rows.Scan(&inv.ID, &inv.EventID, &inv.Email, &inv.Role, &inv.CreatedAt, &tokenHash, &expiresAt); err != nil {
			return nil, fmt.Errorf("calendar: scan pending invite: %w", err)
		}
		inv.TokenHash = tokenHash
		inv.ExpiresAt = expiresAt
		invites = append(invites, inv)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("calendar: list pending invites: %w", err)
	}
	return invites, nil
}

// SetInviteTokenHash stores the final token hash in auth_tokens for an invite.
func (r *Repo) SetInviteTokenHash(ctx context.Context, inviteID, tokenHash string) (EventInvite, error) {
	// Get attendee details
	var inv EventInvite
	err := r.pool.QueryRow(ctx,
		`SELECT id, event_id, email, role, created_at FROM calendar_event_attendees WHERE id = $1`,
		inviteID).Scan(&inv.ID, &inv.EventID, &inv.Email, &inv.Role, &inv.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return EventInvite{}, ErrNotFound
		}
		return EventInvite{}, fmt.Errorf("calendar: get attendee: %w", err)
	}

	// Insert token into auth_tokens
	payload, _ := json.Marshal(map[string]interface{}{
		"event_id": inv.EventID,
		"email":    inv.Email,
		"role":     inv.Role,
	})
	_, err = r.pool.Exec(ctx,
		`INSERT INTO auth_tokens (purpose, token_hash, payload, expires_at)
		 VALUES ('calendar_invite', $1, $2, now() + interval '7 days')
		 ON CONFLICT (token_hash) DO NOTHING`,
		tokenHash, payload)
	if err != nil {
		return EventInvite{}, fmt.Errorf("calendar: set token hash: %w", err)
	}

	inv.TokenHash = tokenHash
	inv.ExpiresAt = time.Now().AddDate(0, 0, 7)
	return inv, nil
}

// GetInviteByTokenHash returns the invite matching tokenHash via auth_tokens lookup.
func (r *Repo) GetInviteByTokenHash(ctx context.Context, tokenHash string) (EventInvite, error) {
	var inv EventInvite
	var payload json.RawMessage
	var expiresAt time.Time

	err := r.pool.QueryRow(ctx,
		`SELECT payload, expires_at FROM auth_tokens
		 WHERE purpose = 'calendar_invite' AND token_hash = $1`,
		tokenHash).Scan(&payload, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return EventInvite{}, ErrNotFound
		}
		return EventInvite{}, fmt.Errorf("calendar: get invite token: %w", err)
	}

	var payloadData map[string]interface{}
	json.Unmarshal(payload, &payloadData)
	inv.EventID = payloadData["event_id"].(string)
	inv.Email = payloadData["email"].(string)
	inv.Role = payloadData["role"].(string)
	inv.TokenHash = tokenHash
	inv.ExpiresAt = expiresAt

	return inv, nil
}

// AcceptInviteTx marks an invite accepted within tx. Updates both the attendee
// status and the auth_tokens consumed_at timestamp.
func (r *Repo) AcceptInviteTx(ctx context.Context, tx pgx.Tx, inviteID string) error {
	// Get attendee details
	var email string
	var eventID string
	err := tx.QueryRow(ctx,
		`SELECT email, event_id FROM calendar_event_attendees WHERE id = $1`,
		inviteID).Scan(&email, &eventID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return fmt.Errorf("calendar: get attendee: %w", err)
	}

	// Update attendee rsvp_status
	tag, err := tx.Exec(ctx,
		`UPDATE calendar_event_attendees SET rsvp_status = 'accepted' WHERE id = $1`,
		inviteID)
	if err != nil {
		return fmt.Errorf("calendar: accept attendee: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}

	// Mark auth_tokens as consumed
	_, _ = tx.Exec(ctx,
		`UPDATE auth_tokens SET consumed_at = now()
		 WHERE purpose = 'calendar_invite' AND (payload->>'event_id')::uuid = $1
		   AND (payload->>'email') = $2`,
		eventID, email)

	return nil
}

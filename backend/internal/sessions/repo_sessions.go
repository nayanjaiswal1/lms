package sessions

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// sessionColumns is the shared SELECT list + joins every session read uses,
// so the display names attached to a session are identical whether it came
// from a list, a detail fetch, or a mentee rollup.
const sessionColumns = `
	s.id, s.org_id, s.mentor_id, s.student_id, s.batch_id, s.title, s.agenda,
	s.starts_at, s.ends_at, s.status, s.booked_by, s.meeting_url, s.calendar_event_id,
	s.cancelled_by, s.cancelled_at, s.cancel_reason, s.completed_at, s.created_at, s.updated_at,
	mu.name, su.name, b.name`

const sessionJoins = `
	FROM mentor_sessions s
	JOIN users mu ON mu.id = s.mentor_id
	LEFT JOIN users su ON su.id = s.student_id
	LEFT JOIN batches b ON b.id = s.batch_id`

// visibilityPredicate is the one definition of "may this user see this
// session": they are the mentor, the student, or a member of the batch it was
// scheduled for. Every read path interpolates this same string, so a batch
// member can never be visible to a list query but invisible to the detail
// query it links to. $2 is the caller's user id.
const visibilityPredicate = `(
	s.mentor_id = $2
	OR s.student_id = $2
	OR (s.batch_id IS NOT NULL AND EXISTS (
	      SELECT 1 FROM batch_members bm WHERE bm.batch_id = s.batch_id AND bm.user_id = $2))
)`

func scanSession(row pgx.Row) (Session, error) {
	var s Session
	err := row.Scan(&s.ID, &s.OrgID, &s.MentorID, &s.StudentID, &s.BatchID, &s.Title, &s.Agenda,
		&s.StartsAt, &s.EndsAt, &s.Status, &s.BookedBy, &s.MeetingURL, &s.CalendarEventID,
		&s.CancelledBy, &s.CancelledAt, &s.CancelReason, &s.CompletedAt, &s.CreatedAt, &s.UpdatedAt,
		&s.MentorName, &s.StudentName, &s.BatchName)
	return s, err
}

// CreateSessionTx inserts the booking. An exclusion-constraint violation is
// translated to ErrSlotTaken: the caller read a free slot, someone else
// booked it first, and the DB — not this code — is what noticed.
func (r *Repo) CreateSessionTx(ctx context.Context, tx pgx.Tx, s Session) (Session, error) {
	err := tx.QueryRow(ctx,
		`INSERT INTO mentor_sessions
		   (org_id, mentor_id, student_id, batch_id, title, agenda, starts_at, ends_at, booked_by, meeting_url)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 RETURNING id, status, created_at, updated_at`,
		s.OrgID, s.MentorID, s.StudentID, s.BatchID, s.Title, s.Agenda,
		s.StartsAt, s.EndsAt, s.BookedBy, s.MeetingURL,
	).Scan(&s.ID, &s.Status, &s.CreatedAt, &s.UpdatedAt)
	if exclusionViolation(err) {
		return Session{}, ErrSlotTaken
	}
	if err != nil {
		return Session{}, fmt.Errorf("sessions: create session: %w", err)
	}
	return s, nil
}

// SetCalendarEventIDTx links the booking to the calendar_events row it
// projects onto.
func (r *Repo) SetCalendarEventIDTx(ctx context.Context, tx pgx.Tx, sessionID, eventID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE mentor_sessions SET calendar_event_id = $2, updated_at = now() WHERE id = $1`,
		sessionID, eventID,
	); err != nil {
		return fmt.Errorf("sessions: set calendar event id: %w", err)
	}
	return nil
}

// GetSession returns one session if callerID may see it (see
// visibilityPredicate). A session in another org, or one the caller has no
// part in, is reported as ErrNotFound rather than ErrForbidden — its
// existence is not something a stranger gets to learn.
func (r *Repo) GetSession(ctx context.Context, orgID, sessionID, callerID string) (Session, error) {
	s, err := scanSession(r.pool.QueryRow(ctx,
		`SELECT`+sessionColumns+sessionJoins+`
		  WHERE s.org_id = $1 AND s.id = $3 AND `+visibilityPredicate,
		orgID, callerID, sessionID,
	))
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrNotFound
	}
	if err != nil {
		return Session{}, fmt.Errorf("sessions: get session: %w", err)
	}
	return s, nil
}

// getSessionUnscoped reads a session by id within an org with no visibility
// filter. Only for internal checks that then apply their own authorization
// (e.g. Cancel, which must tell "not yours" apart from "doesn't exist").
func (r *Repo) getSessionUnscoped(ctx context.Context, tx pgx.Tx, orgID, sessionID string) (Session, error) {
	s, err := scanSession(tx.QueryRow(ctx,
		`SELECT`+sessionColumns+sessionJoins+`
		  WHERE s.org_id = $1 AND s.id = $2
		  FOR UPDATE OF s`,
		orgID, sessionID,
	))
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrNotFound
	}
	if err != nil {
		return Session{}, fmt.Errorf("sessions: get session: %w", err)
	}
	return s, nil
}

// ListScope values accepted by ListSessions.
const (
	ScopeUpcoming = "upcoming"
	ScopePast     = "past"
	ScopeAll      = "all"
)

// ListSessions returns every session callerID takes part in, newest-first for
// past scopes and soonest-first for upcoming — the order each view actually
// reads in.
func (r *Repo) ListSessions(ctx context.Context, orgID, callerID, scope string, limit int) ([]Session, error) {
	where := ``
	order := `ORDER BY s.starts_at DESC`
	switch scope {
	case ScopeUpcoming:
		where = ` AND s.status = 'scheduled' AND s.ends_at >= now()`
		order = `ORDER BY s.starts_at ASC`
	case ScopePast:
		where = ` AND (s.status <> 'scheduled' OR s.ends_at < now())`
	}

	rows, err := r.pool.Query(ctx,
		`SELECT`+sessionColumns+sessionJoins+`
		  WHERE s.org_id = $1 AND `+visibilityPredicate+where+`
		  `+order+` LIMIT $3`,
		orgID, callerID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list sessions: %w", err)
	}
	defer rows.Close()

	out := []Session{}
	for rows.Next() {
		s, err := scanSession(rows)
		if err != nil {
			return nil, fmt.Errorf("sessions: scan session: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// CountUpcomingForStudent backs the max_upcoming_per_student limit. Counted
// inside the booking transaction (hence the tx parameter) so two concurrent
// bookings cannot both see count = limit-1 and both succeed.
func (r *Repo) CountUpcomingForStudent(ctx context.Context, tx pgx.Tx, orgID, studentID string) (int, error) {
	var n int
	err := tx.QueryRow(ctx,
		`SELECT count(*) FROM mentor_sessions
		  WHERE org_id = $1 AND student_id = $2 AND status = 'scheduled' AND ends_at >= now()`,
		orgID, studentID,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("sessions: count upcoming: %w", err)
	}
	return n, nil
}

// CancelSessionTx flips a scheduled session to cancelled. The status guard in
// the WHERE makes a double-cancel a no-op (transitioned=false) rather than
// an error — and, critically, stops a retried cancel from issuing a second
// refund.
func (r *Repo) CancelSessionTx(ctx context.Context, tx pgx.Tx, sessionID, cancelledBy string, reason *string) (bool, error) {
	tag, err := tx.Exec(ctx,
		`UPDATE mentor_sessions
		    SET status = 'cancelled', cancelled_by = $2, cancelled_at = now(),
		        cancel_reason = $3, updated_at = now()
		  WHERE id = $1 AND status = 'scheduled'`,
		sessionID, cancelledBy, reason,
	)
	if err != nil {
		return false, fmt.Errorf("sessions: cancel session: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// SetOutcome marks a scheduled session completed or no_show. Only a session
// that is still 'scheduled' can transition, so an outcome cannot be flipped
// back and forth after the fact.
func (r *Repo) SetOutcome(ctx context.Context, orgID, sessionID, status string) (Session, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`UPDATE mentor_sessions
		    SET status = $3, completed_at = now(), updated_at = now()
		  WHERE id = $1 AND org_id = $2 AND status = 'scheduled'
		  RETURNING id`,
		sessionID, orgID, status,
	).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrNotFound
	}
	if err != nil {
		return Session{}, fmt.Errorf("sessions: set outcome: %w", err)
	}
	s, err := scanSession(r.pool.QueryRow(ctx,
		`SELECT`+sessionColumns+sessionJoins+` WHERE s.id = $1`, id,
	))
	if err != nil {
		return Session{}, fmt.Errorf("sessions: reload session: %w", err)
	}
	return s, nil
}

// Reschedule moves a scheduled session. The same exclusion constraint that
// guards booking guards this, so moving onto a busy slot is ErrSlotTaken.
func (r *Repo) Reschedule(ctx context.Context, orgID, sessionID string, startsAt, endsAt time.Time) (Session, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`UPDATE mentor_sessions
		    SET starts_at = $3, ends_at = $4, updated_at = now()
		  WHERE id = $1 AND org_id = $2 AND status = 'scheduled'
		  RETURNING id`,
		sessionID, orgID, startsAt, endsAt,
	).Scan(&id)
	if exclusionViolation(err) {
		return Session{}, ErrSlotTaken
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrNotFound
	}
	if err != nil {
		return Session{}, fmt.Errorf("sessions: reschedule: %w", err)
	}
	s, err := scanSession(r.pool.QueryRow(ctx,
		`SELECT`+sessionColumns+sessionJoins+` WHERE s.id = $1`, id,
	))
	if err != nil {
		return Session{}, fmt.Errorf("sessions: reload session: %w", err)
	}
	return s, nil
}

// ─── feedback ──────────────────────────────────────────────────────────────

// UpsertFeedback writes one author's rating for a session, replacing their
// previous one rather than stacking a second (see the unique index).
func (r *Repo) UpsertFeedback(ctx context.Context, f Feedback) (Feedback, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO feedback (subject_type, subject_id, user_id, kind, rating, comment)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (subject_type, subject_id, user_id) DO UPDATE
		   SET rating = EXCLUDED.rating, comment = EXCLUDED.comment, updated_at = now()
		 RETURNING id, created_at, updated_at`,
		"mentor_session", f.SessionID, f.AuthorID, "rating", f.Rating, f.Comment,
	).Scan(&f.ID, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		return Feedback{}, fmt.Errorf("sessions: upsert feedback: %w", err)
	}
	return f, nil
}

// ListFeedback returns both sides' feedback for a session.
func (r *Repo) ListFeedback(ctx context.Context, sessionID string) ([]Feedback, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT f.id, f.subject_id, f.user_id, f.rating, f.comment,
		        u.name, f.created_at, f.updated_at, s.mentor_id, s.student_id
		   FROM feedback f
		   JOIN users u ON u.id = f.user_id
		   JOIN mentor_sessions s ON s.id = f.subject_id
		  WHERE f.subject_type = $1 AND f.subject_id = $2
		  ORDER BY f.created_at`,
		"mentor_session", sessionID,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list feedback: %w", err)
	}
	defer rows.Close()

	out := []Feedback{}
	for rows.Next() {
		var f Feedback
		var mentorID, studentID *string
		if err := rows.Scan(&f.ID, &f.SessionID, &f.AuthorID, &f.Rating,
			&f.Comment, &f.AuthorName, &f.CreatedAt, &f.UpdatedAt, &mentorID, &studentID); err != nil {
			return nil, fmt.Errorf("sessions: scan feedback: %w", err)
		}
		// Derive author_role based on whether they are the mentor or student
		if mentorID != nil && f.AuthorID == *mentorID {
			f.AuthorRole = RoleMentor
		} else if studentID != nil && f.AuthorID == *studentID {
			f.AuthorRole = RoleStudent
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// ─── mentor notes ──────────────────────────────────────────────────────────

// UpsertNotes writes the mentor's write-up for a session.
func (r *Repo) UpsertNotes(ctx context.Context, n Notes) (Notes, error) {
	err := r.pool.QueryRow(ctx,
		`UPDATE mentor_sessions
		 SET notes = $2, notes_visible_to_student = $3, updated_at = now()
		 WHERE id = $1
		 RETURNING updated_at`,
		n.SessionID, n.Body, n.VisibleToStudent,
	).Scan(&n.UpdatedAt)
	if err != nil {
		return Notes{}, fmt.Errorf("sessions: upsert notes: %w", err)
	}
	return n, nil
}

// GetNotes returns a session's notes. includePrivate is false for a student
// reading their own session — the row is filtered in SQL rather than fetched
// and then dropped in Go, so private notes never leave the database.
func (r *Repo) GetNotes(ctx context.Context, sessionID string, includePrivate bool) (*Notes, error) {
	var n Notes
	err := r.pool.QueryRow(ctx,
		`SELECT id, mentor_id, notes, notes_visible_to_student, updated_at
		   FROM mentor_sessions
		  WHERE id = $1 AND ($2 OR notes_visible_to_student OR notes IS NULL)`,
		sessionID, includePrivate,
	).Scan(&n.SessionID, &n.MentorID, &n.Body, &n.VisibleToStudent, &n.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("sessions: get notes: %w", err)
	}
	return &n, nil
}

// ─── mentee progress ───────────────────────────────────────────────────────

// MenteeProgress returns everything one mentor should see about one mentee
// before their next session: the full shared session history plus the
// aggregate over it.
func (r *Repo) MenteeProgress(ctx context.Context, orgID, mentorID, studentID string) (MenteeProgress, error) {
	p := MenteeProgress{StudentID: studentID}

	// The average rating is a scalar subquery rather than a third JOIN: joining
	// feedback here fans out one row per rating, so a session
	// rated by BOTH parties would be counted twice in every count below.
	err := r.pool.QueryRow(ctx,
		`SELECT u.name,
		        count(s.id),
		        count(s.id) FILTER (WHERE s.status = 'completed'),
		        count(s.id) FILTER (WHERE s.status = 'cancelled'),
		        count(s.id) FILTER (WHERE s.status = 'no_show'),
		        min(s.starts_at), max(s.starts_at),
		        (SELECT avg(f.rating)
		           FROM feedback f
		           JOIN mentor_sessions fs ON fs.id = f.subject_id
		          WHERE f.subject_type = 'mentor_session'
		            AND fs.org_id = $1 AND fs.mentor_id = $2 AND fs.student_id = $3
		            AND f.user_id = $3)
		   FROM users u
		   LEFT JOIN mentor_sessions s
		          ON s.student_id = u.id AND s.mentor_id = $2 AND s.org_id = $1
		  WHERE u.id = $3
		  GROUP BY u.name`,
		orgID, mentorID, studentID,
	).Scan(&p.StudentName, &p.TotalSessions, &p.CompletedCount, &p.CancelledCount,
		&p.NoShowCount, &p.FirstSessionAt, &p.LastSessionAt, &p.AvgRatingGiven)
	if errors.Is(err, pgx.ErrNoRows) {
		return MenteeProgress{}, ErrNotFound
	}
	if err != nil {
		return MenteeProgress{}, fmt.Errorf("sessions: mentee progress: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT`+sessionColumns+sessionJoins+`
		  WHERE s.org_id = $1 AND s.mentor_id = $2 AND s.student_id = $3
		  ORDER BY s.starts_at DESC`,
		orgID, mentorID, studentID,
	)
	if err != nil {
		return MenteeProgress{}, fmt.Errorf("sessions: mentee sessions: %w", err)
	}
	defer rows.Close()

	p.Sessions = []Session{}
	for rows.Next() {
		s, err := scanSession(rows)
		if err != nil {
			return MenteeProgress{}, fmt.Errorf("sessions: scan mentee session: %w", err)
		}
		p.Sessions = append(p.Sessions, s)
		if s.Status == StatusScheduled && s.EndsAt.After(time.Now()) {
			// Rows arrive newest-first, so the last scheduled one seen is the
			// soonest — which is the "next session" a mentor is preparing for.
			next := s
			p.UpcomingSession = &next
		}
	}
	return p, rows.Err()
}

// ListBatchMemberIDs returns every member of a batch — the attendee list a
// whole-cohort session is projected onto everyone's calendar with.
func (r *Repo) ListBatchMemberIDs(ctx context.Context, orgID, batchID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT bm.user_id
		   FROM batch_members bm
		   JOIN batches b ON b.id = bm.batch_id
		  WHERE bm.batch_id = $1 AND b.org_id = $2`,
		batchID, orgID,
	)
	if err != nil {
		return nil, fmt.Errorf("sessions: list batch members: %w", err)
	}
	defer rows.Close()

	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("sessions: scan batch member: %w", err)
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// IsMentorInOrg reports whether userID holds the mentor role in orgID —
// checked before a session can be booked against them, so a student cannot
// book "sessions" with an arbitrary classmate.
func (r *Repo) IsMentorInOrg(ctx context.Context, orgID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS (
		   SELECT 1 FROM org_members
		    WHERE org_id = $1 AND user_id = $2 AND role = 'mentor' AND status = 'active'
		 )`,
		orgID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("sessions: is mentor in org: %w", err)
	}
	return exists, nil
}

// IsOrgMember reports whether userID belongs to orgID — the guard that keeps
// a mentor from booking a session against someone outside their tenant.
func (r *Repo) IsOrgMember(ctx context.Context, orgID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS (
		   SELECT 1 FROM org_members
		    WHERE org_id = $1 AND user_id = $2 AND status = 'active'
		 )`,
		orgID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("sessions: is org member: %w", err)
	}
	return exists, nil
}

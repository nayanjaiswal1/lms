package mentoring

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("mentoring: not found")

	// ErrForbidden is returned when a caller acts on a ticket/request that
	// isn't theirs (e.g. requesting a mentor change on someone else's ticket).
	ErrForbidden = errors.New("mentoring: forbidden")

	// ErrTicketAlreadyClaimed is returned by ClaimTicket/AssignTicket when the
	// target ticket no longer exists or is no longer 'open' — the handler
	// maps this to HTTP 409.
	ErrTicketAlreadyClaimed = errors.New("mentoring: ticket already claimed")

	// ErrChangeRequestPending is returned by CreateChangeRequest on a
	// UNIQUE (ticket_id) WHERE status='pending' violation — the handler maps
	// this to HTTP 409.
	ErrChangeRequestPending = &conflictErr{msg: "mentoring: a change request is already pending for this ticket"}

	// ErrAlreadyPurchased is returned by CreatePurchase on a UNIQUE
	// (user_id, course_id) violation. It implements IsConflict() so callers
	// in other packages (e.g. courses) can detect it via a locally-defined
	// interface without importing this package's concrete error value —
	// see courses.Handler.Purchase.
	ErrAlreadyPurchased = &conflictErr{msg: "mentoring: course already purchased"}

	// ErrAlreadyHasMentor is returned by RequestMentor when the student
	// already has an open or assigned ticket in this org — the handler maps
	// this to HTTP 409.
	ErrAlreadyHasMentor = &conflictErr{msg: "mentoring: you already have an active mentor request"}
)

// conflictErr is a sentinel error type that signals "this is a conflict, not
// a server fault" to callers that only know about a narrow local interface
// (IsConflict() bool), not this package's concrete types.
type conflictErr struct{ msg string }

func (e *conflictErr) Error() string    { return e.msg }
func (e *conflictErr) IsConflict() bool { return true }

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, committing on success and rolling back on
// any error fn returns. Mirrors courses.Repo's tx helper.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("mentoring: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("mentoring: commit tx: %w", err)
	}
	return nil
}

// rowScanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query),
// letting scan helpers work with either.
type rowScanner interface {
	Scan(dest ...any) error
}

// CreatePurchase inserts a completed course purchase record within tx.
// Returns ErrAlreadyPurchased if the user already purchased this course
// (UNIQUE (user_id, course_id)).
func (r *Repo) CreatePurchase(ctx context.Context, tx pgx.Tx, p Purchase) (Purchase, error) {
	err := tx.QueryRow(ctx,
		`INSERT INTO course_purchases (org_id, user_id, course_id, amount_cents, currency, provider, provider_ref, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 RETURNING id, purchased_at`,
		p.OrgID, p.UserID, p.CourseID, p.AmountCents, p.Currency, p.Provider, p.ProviderRef, p.Status,
	).Scan(&p.ID, &p.PurchasedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return Purchase{}, ErrAlreadyPurchased
		}
		return Purchase{}, fmt.Errorf("mentoring: create purchase: %w", err)
	}
	return p, nil
}

// HasActiveMentor reports whether studentID already has an open or assigned
// mentor ticket in orgID — used to dedupe ticket creation on repeat purchases.
func (r *Repo) HasActiveMentor(ctx context.Context, tx pgx.Tx, orgID, studentID string) (bool, error) {
	var exists bool
	err := tx.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM mentor_tickets
		   WHERE org_id = $1 AND student_id = $2 AND status IN ('open','assigned')
		 )`, orgID, studentID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has active mentor: %w", err)
	}
	return exists, nil
}

// HasBeenMentoredBy reports whether mentorID has ever actually been assigned
// to studentID — checked against the durable mentor_ticket_assignments
// history (not mentor_tickets.assigned_mentor_id, which only reflects the
// CURRENT mentor and is cleared on reassignment). Used to gate mentor
// ratings — a student can rate any mentor who has mentored them, past or
// present.
func (r *Repo) HasBeenMentoredBy(ctx context.Context, orgID, studentID, mentorID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM mentor_ticket_assignments
		   WHERE org_id = $1 AND student_id = $2 AND mentor_id = $3
		 )`, orgID, studentID, mentorID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has been mentored by: %w", err)
	}
	return exists, nil
}

// HasCompletedPurchase reports whether userID has a completed purchase on
// record for courseID — the "has this learner paid" check certificates'
// threshold-based auto-issue uses for non-free courses.
func (r *Repo) HasCompletedPurchase(ctx context.Context, userID, courseID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM course_purchases
		   WHERE user_id = $1 AND course_id = $2 AND status = $3
		 )`, userID, courseID, PurchaseStatusCompleted,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: has completed purchase: %w", err)
	}
	return exists, nil
}

// CreateTicket opens a new 'open' mentor ticket within tx.
func (r *Repo) CreateTicket(ctx context.Context, tx pgx.Tx, t Ticket) (Ticket, error) {
	t.Status = TicketStatusOpen
	err := tx.QueryRow(ctx,
		`INSERT INTO mentor_tickets (org_id, student_id, course_id, purchase_id, status)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING id, created_at, updated_at`,
		t.OrgID, t.StudentID, t.CourseID, t.PurchaseID, t.Status,
	).Scan(&t.ID, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return Ticket{}, fmt.Errorf("mentoring: create ticket: %w", err)
	}
	return t, nil
}

const ticketColumns = `id, org_id, student_id, course_id, purchase_id, status,
	assigned_mentor_id, assigned_by, assigned_at, closed_at, escalation_level, created_at, updated_at`

func scanTicket(row rowScanner) (Ticket, error) {
	var t Ticket
	err := row.Scan(&t.ID, &t.OrgID, &t.StudentID, &t.CourseID, &t.PurchaseID, &t.Status,
		&t.AssignedMentorID, &t.AssignedBy, &t.AssignedAt, &t.ClosedAt, &t.EscalationLevel, &t.CreatedAt, &t.UpdatedAt)
	return t, err
}

// recordAssignment inserts a durable mentor_ticket_assignments row so
// HasBeenMentoredBy can still recognize a previous mentor after the ticket
// is later reassigned (assigned_mentor_id on mentor_tickets only ever
// reflects the CURRENT mentor).
func recordAssignment(ctx context.Context, tx pgx.Tx, orgID, ticketID, mentorID, studentID string) error {
	_, err := tx.Exec(ctx,
		`INSERT INTO mentor_ticket_assignments (org_id, ticket_id, mentor_id, student_id)
		 VALUES ($1,$2,$3,$4)`,
		orgID, ticketID, mentorID, studentID)
	if err != nil {
		return fmt.Errorf("mentoring: record assignment: %w", err)
	}
	return nil
}

// ListTicketAssignments returns every mentor ever assigned to ticketID, in
// chronological order — the durable history behind mentor_tickets'
// current-only assigned_mentor_id.
func (r *Repo) ListTicketAssignments(ctx context.Context, ticketID string) ([]TicketAssignment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, ticket_id, mentor_id, assigned_at
		 FROM mentor_ticket_assignments
		 WHERE ticket_id = $1
		 ORDER BY assigned_at ASC`, ticketID,
	)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list ticket assignments: %w", err)
	}
	defer rows.Close()

	assignments := []TicketAssignment{}
	for rows.Next() {
		var a TicketAssignment
		if err := rows.Scan(&a.ID, &a.TicketID, &a.MentorID, &a.AssignedAt); err != nil {
			return nil, fmt.Errorf("mentoring: list ticket assignments: scan: %w", err)
		}
		assignments = append(assignments, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("mentoring: list ticket assignments: rows: %w", err)
	}
	return assignments, nil
}

// ClaimTicket lets mentorID self-assign an open ticket within orgID. Returns
// ErrTicketAlreadyClaimed if the ticket doesn't exist in this org or is no
// longer open — the same error for "not found" and "not open" avoids leaking
// whether a ticket exists in another org (mirrors the RBAC "identical 404"
// no-leak convention).
func (r *Repo) ClaimTicket(ctx context.Context, orgID, ticketID, mentorID string) (Ticket, error) {
	var t Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE mentor_tickets
			 SET status = 'assigned', assigned_mentor_id = $1, assigned_by = $1, assigned_at = now(), updated_at = now()
			 WHERE id = $2 AND org_id = $3 AND status = 'open'
			 RETURNING `+ticketColumns,
			mentorID, ticketID, orgID)
		var txErr error
		t, txErr = scanTicket(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrTicketAlreadyClaimed
			}
			return txErr
		}
		return recordAssignment(ctx, tx, orgID, ticketID, mentorID, t.StudentID)
	})
	if err != nil {
		if errors.Is(err, ErrTicketAlreadyClaimed) {
			return Ticket{}, ErrTicketAlreadyClaimed
		}
		return Ticket{}, fmt.Errorf("mentoring: claim ticket: %w", err)
	}
	return t, nil
}

// AssignTicket lets a staff member (assignedBy) hand-assign mentorID to an
// open ticket within orgID. Returns ErrTicketAlreadyClaimed if the ticket
// doesn't exist in this org or is no longer open.
func (r *Repo) AssignTicket(ctx context.Context, orgID, ticketID, mentorID, assignedBy string) (Ticket, error) {
	var t Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE mentor_tickets
			 SET status = 'assigned', assigned_mentor_id = $1, assigned_by = $2, assigned_at = now(), updated_at = now()
			 WHERE id = $3 AND org_id = $4 AND status = 'open'
			 RETURNING `+ticketColumns,
			mentorID, assignedBy, ticketID, orgID)
		var txErr error
		t, txErr = scanTicket(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrTicketAlreadyClaimed
			}
			return txErr
		}
		return recordAssignment(ctx, tx, orgID, ticketID, mentorID, t.StudentID)
	})
	if err != nil {
		if errors.Is(err, ErrTicketAlreadyClaimed) {
			return Ticket{}, ErrTicketAlreadyClaimed
		}
		return Ticket{}, fmt.Errorf("mentoring: assign ticket: %w", err)
	}
	return t, nil
}

// IsMentor reports whether userID holds the 'mentor' org role in orgID —
// used to validate the target of AssignTicket before hand-assigning a
// ticket to them.
func (r *Repo) IsMentor(ctx context.Context, orgID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM org_members WHERE org_id = $1 AND user_id = $2 AND role = 'mentor')`,
		orgID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("mentoring: is mentor: %w", err)
	}
	return exists, nil
}

// CloseTicket closes a ticket within orgID that isn't already closed.
func (r *Repo) CloseTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE mentor_tickets
		 SET status = 'closed', closed_at = now(), updated_at = now()
		 WHERE id = $1 AND org_id = $2 AND status != 'closed'
		 RETURNING `+ticketColumns,
		ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("mentoring: close ticket: %w", err)
	}
	return t, nil
}

// GetTicket returns a single ticket by ID, scoped to orgID.
func (r *Repo) GetTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+ticketColumns+` FROM mentor_tickets WHERE id = $1 AND org_id = $2`, ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("mentoring: get ticket: %w", err)
	}
	return t, nil
}

// ListTickets returns tickets for orgID, optionally filtered by status,
// assigned_mentor_id (a mentor's own queue), and/or student_id (a student's
// own tickets).
func (r *Repo) ListTickets(ctx context.Context, orgID string, status *string, mentorID *string, studentID *string) ([]Ticket, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	n := 2
	if status != nil && *status != "" {
		where += fmt.Sprintf(" AND status = $%d", n)
		args = append(args, *status)
		n++
	}
	if mentorID != nil && *mentorID != "" {
		where += fmt.Sprintf(" AND assigned_mentor_id = $%d", n)
		args = append(args, *mentorID)
		n++
	}
	if studentID != nil && *studentID != "" {
		where += fmt.Sprintf(" AND student_id = $%d", n)
		args = append(args, *studentID)
		n++
	}
	rows, err := r.pool.Query(ctx,
		`SELECT `+ticketColumns+` FROM mentor_tickets `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list tickets: %w", err)
	}
	defer rows.Close()
	out := []Ticket{}
	for rows.Next() {
		t, err := scanTicket(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan ticket: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListMentorDirectory returns every mentor-role org member with their live
// assigned-mentee count (mentor_tickets, status='assigned') and aggregated
// rating (feedback, subject_type='mentor'). Mirrors the aggregation idiom
// used by assessment.Repo.GetBatchProgress: subquery joins, one round-trip.
func (r *Repo) ListMentorDirectory(ctx context.Context, orgID string) ([]MentorDirectoryEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, u.email, u.avatar_url,
		        COALESCE(mt.mentee_count, 0) AS mentee_count,
		        fb.avg_rating, COALESCE(fb.rating_count, 0) AS rating_count
		 FROM org_members om
		 JOIN users u ON u.id = om.user_id
		 LEFT JOIN (
		   SELECT assigned_mentor_id, COUNT(*) AS mentee_count
		   FROM mentor_tickets
		   WHERE status = 'assigned'
		   GROUP BY assigned_mentor_id
		 ) mt ON mt.assigned_mentor_id = u.id
		 LEFT JOIN (
		   SELECT subject_id, AVG(rating) AS avg_rating, COUNT(rating) AS rating_count
		   FROM feedback
		   WHERE subject_type = 'mentor' AND rating IS NOT NULL
		   GROUP BY subject_id
		 ) fb ON fb.subject_id = u.id
		 WHERE om.org_id = $1 AND om.role = 'mentor'
		 ORDER BY u.name`, orgID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list mentor directory: %w", err)
	}
	defer rows.Close()

	out := []MentorDirectoryEntry{}
	for rows.Next() {
		var m MentorDirectoryEntry
		if err := rows.Scan(&m.UserID, &m.Name, &m.Email, &m.AvatarURL, &m.MenteeCount, &m.AvgRating, &m.RatingCount); err != nil {
			return nil, fmt.Errorf("mentoring: scan mentor directory entry: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

const reportColumns = `id, org_id, mentor_id, reporter_id, ticket_id, reason, description, status,
	resolved_by, resolution_note, resolved_at, created_at`

func scanReport(row rowScanner) (Report, error) {
	var rep Report
	err := row.Scan(&rep.ID, &rep.OrgID, &rep.MentorID, &rep.ReporterID, &rep.TicketID, &rep.Reason,
		&rep.Description, &rep.Status, &rep.ResolvedBy, &rep.ResolutionNote, &rep.ResolvedAt, &rep.CreatedAt)
	return rep, err
}

// CreateReport files a new mentor complaint report with status 'open'.
func (r *Repo) CreateReport(ctx context.Context, rep Report) (Report, error) {
	rep.Status = ReportStatusOpen
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_reports (org_id, mentor_id, reporter_id, ticket_id, reason, description, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)
		 RETURNING `+reportColumns,
		rep.OrgID, rep.MentorID, rep.ReporterID, rep.TicketID, rep.Reason, rep.Description, rep.Status)
	created, err := scanReport(row)
	if err != nil {
		return Report{}, fmt.Errorf("mentoring: create report: %w", err)
	}
	return created, nil
}

// ListReports returns reports for orgID, optionally filtered by status.
func (r *Repo) ListReports(ctx context.Context, orgID string, status *string) ([]Report, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	if status != nil && *status != "" {
		where += " AND status = $2"
		args = append(args, *status)
	}
	rows, err := r.pool.Query(ctx, `SELECT `+reportColumns+` FROM mentor_reports `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list reports: %w", err)
	}
	defer rows.Close()
	out := []Report{}
	for rows.Next() {
		rep, err := scanReport(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan report: %w", err)
		}
		out = append(out, rep)
	}
	return out, rows.Err()
}

// ResolveReport marks a report within orgID resolved or dismissed. status
// must be ReportStatusResolved or ReportStatusDismissed (validated by the
// service).
func (r *Repo) ResolveReport(ctx context.Context, orgID, reportID, resolvedBy, status, note string) (Report, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE mentor_reports
		 SET status = $1, resolved_by = $2, resolution_note = $3, resolved_at = now()
		 WHERE id = $4 AND org_id = $5
		 RETURNING `+reportColumns,
		status, resolvedBy, note, reportID, orgID)
	rep, err := scanReport(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, ErrNotFound
		}
		return Report{}, fmt.Errorf("mentoring: resolve report: %w", err)
	}
	return rep, nil
}

// ListReportsByTicket returns every complaint report filed against
// ticketID, most recent first — used by GetTicketDetail. Callers must check
// mentoring.manage_reports before calling this; it is not checked here.
func (r *Repo) ListReportsByTicket(ctx context.Context, ticketID string) ([]Report, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+reportColumns+` FROM mentor_reports WHERE ticket_id = $1 ORDER BY created_at DESC`, ticketID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list reports by ticket: %w", err)
	}
	defer rows.Close()
	out := []Report{}
	for rows.Next() {
		rep, err := scanReport(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan report: %w", err)
		}
		out = append(out, rep)
	}
	return out, rows.Err()
}

const chatMessageColumns = `id, org_id, ticket_id, sender_id, body, created_at`

func scanChatMessage(row rowScanner) (ChatMessage, error) {
	var m ChatMessage
	err := row.Scan(&m.ID, &m.OrgID, &m.TicketID, &m.SenderID, &m.Body, &m.CreatedAt)
	return m, err
}

// CreateChatMessage posts a new message on ticketID's chat thread.
func (r *Repo) CreateChatMessage(ctx context.Context, orgID, ticketID, senderID, body string) (ChatMessage, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_chat_messages (org_id, ticket_id, sender_id, body)
		 VALUES ($1,$2,$3,$4)
		 RETURNING `+chatMessageColumns,
		orgID, ticketID, senderID, body)
	m, err := scanChatMessage(row)
	if err != nil {
		return ChatMessage{}, fmt.Errorf("mentoring: create chat message: %w", err)
	}
	return m, nil
}

// ListChatMessages returns every message on ticketID's chat thread, oldest first.
func (r *Repo) ListChatMessages(ctx context.Context, orgID, ticketID string) ([]ChatMessage, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+chatMessageColumns+` FROM mentor_chat_messages
		 WHERE org_id = $1 AND ticket_id = $2
		 ORDER BY created_at ASC`,
		orgID, ticketID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list chat messages: %w", err)
	}
	defer rows.Close()
	out := []ChatMessage{}
	for rows.Next() {
		m, err := scanChatMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan chat message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

const changeRequestColumns = `id, org_id, ticket_id, student_id, reason, status,
	reviewed_by, review_note, reviewed_at, created_at`

func scanChangeRequest(row rowScanner) (ChangeRequest, error) {
	var cr ChangeRequest
	err := row.Scan(&cr.ID, &cr.OrgID, &cr.TicketID, &cr.StudentID, &cr.Reason, &cr.Status,
		&cr.ReviewedBy, &cr.ReviewNote, &cr.ReviewedAt, &cr.CreatedAt)
	return cr, err
}

// CreateChangeRequest files a new pending mentor-change request for a ticket.
// Returns ErrChangeRequestPending if one is already pending for this ticket
// (UNIQUE (ticket_id) WHERE status='pending').
func (r *Repo) CreateChangeRequest(ctx context.Context, cr ChangeRequest) (ChangeRequest, error) {
	cr.Status = ChangeRequestStatusPending
	row := r.pool.QueryRow(ctx,
		`INSERT INTO mentor_change_requests (org_id, ticket_id, student_id, reason, status)
		 VALUES ($1,$2,$3,$4,$5)
		 RETURNING `+changeRequestColumns,
		cr.OrgID, cr.TicketID, cr.StudentID, cr.Reason, cr.Status)
	created, err := scanChangeRequest(row)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ChangeRequest{}, ErrChangeRequestPending
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: create change request: %w", err)
	}
	return created, nil
}

// ListChangeRequests returns change requests for orgID, optionally filtered
// by status.
func (r *Repo) ListChangeRequests(ctx context.Context, orgID string, status *string) ([]ChangeRequest, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	if status != nil && *status != "" {
		where += " AND status = $2"
		args = append(args, *status)
	}
	rows, err := r.pool.Query(ctx, `SELECT `+changeRequestColumns+` FROM mentor_change_requests `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list change requests: %w", err)
	}
	defer rows.Close()
	out := []ChangeRequest{}
	for rows.Next() {
		cr, err := scanChangeRequest(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan change request: %w", err)
		}
		out = append(out, cr)
	}
	return out, rows.Err()
}

// ListChangeRequestsByTicket returns every change request ever filed for
// ticketID, most recent first — used by GetTicketDetail to assemble a
// ticket's full lifecycle alongside its assignments and reports.
func (r *Repo) ListChangeRequestsByTicket(ctx context.Context, ticketID string) ([]ChangeRequest, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+changeRequestColumns+` FROM mentor_change_requests WHERE ticket_id = $1 ORDER BY created_at DESC`, ticketID)
	if err != nil {
		return nil, fmt.Errorf("mentoring: list change requests by ticket: %w", err)
	}
	defer rows.Close()
	out := []ChangeRequest{}
	for rows.Next() {
		cr, err := scanChangeRequest(rows)
		if err != nil {
			return nil, fmt.Errorf("mentoring: scan change request: %w", err)
		}
		out = append(out, cr)
	}
	return out, rows.Err()
}

// GetChangeRequest returns a single change request scoped to orgID.
func (r *Repo) GetChangeRequest(ctx context.Context, orgID, requestID string) (ChangeRequest, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+changeRequestColumns+` FROM mentor_change_requests WHERE id = $1 AND org_id = $2`, requestID, orgID)
	cr, err := scanChangeRequest(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ChangeRequest{}, ErrNotFound
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: get change request: %w", err)
	}
	return cr, nil
}

// DenyChangeRequest marks a pending request denied within orgID. Returns
// ErrNotFound if the request doesn't exist in this org or is no longer pending.
func (r *Repo) DenyChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE mentor_change_requests
		 SET status = $1, reviewed_by = $2, review_note = $3, reviewed_at = now()
		 WHERE id = $4 AND org_id = $5 AND status = $6
		 RETURNING `+changeRequestColumns,
		ChangeRequestStatusDenied, reviewedBy, note, requestID, orgID, ChangeRequestStatusPending)
	cr, err := scanChangeRequest(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ChangeRequest{}, ErrNotFound
		}
		return ChangeRequest{}, fmt.Errorf("mentoring: deny change request: %w", err)
	}
	return cr, nil
}

// ApproveChangeRequest marks a pending request approved and reopens its
// ticket (status back to 'open', mentor cleared, escalation_level reset to 0
// so the fresh assignment cycle re-escalates from scratch) atomically within
// orgID. Returns ErrNotFound if the request doesn't exist in this org or is
// no longer pending.
func (r *Repo) ApproveChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, Ticket, error) {
	var cr ChangeRequest
	var t Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`UPDATE mentor_change_requests
			 SET status = $1, reviewed_by = $2, review_note = $3, reviewed_at = now()
			 WHERE id = $4 AND org_id = $5 AND status = $6
			 RETURNING `+changeRequestColumns,
			ChangeRequestStatusApproved, reviewedBy, note, requestID, orgID, ChangeRequestStatusPending)
		var txErr error
		cr, txErr = scanChangeRequest(row)
		if txErr != nil {
			if errors.Is(txErr, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("update change request: %w", txErr)
		}

		ticketRow := tx.QueryRow(ctx,
			`UPDATE mentor_tickets
			 SET status = 'open', assigned_mentor_id = NULL, assigned_by = NULL,
			     assigned_at = NULL, escalation_level = 0, updated_at = now()
			 WHERE id = $1 AND org_id = $2
			 RETURNING `+ticketColumns,
			cr.TicketID, orgID)
		t, txErr = scanTicket(ticketRow)
		if txErr != nil {
			return fmt.Errorf("reopen ticket %s: %w", cr.TicketID, txErr)
		}
		return nil
	})
	if err != nil {
		return ChangeRequest{}, Ticket{}, err
	}
	return cr, t, nil
}

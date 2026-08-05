package tickets

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("tickets: not found")
	// ErrForbidden is returned when a caller tries to view/reply to a ticket
	// that isn't theirs (not the requester, not the assignee) and they don't
	// hold its kind's manage permission.
	ErrForbidden = errors.New("tickets: forbidden")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

// tx runs fn inside a transaction, committing on success and rolling back on
// any error fn returns.
func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("tickets: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("tickets: commit tx: %w", err)
	}
	return nil
}

// RowScanner is satisfied by both pgx.Row (QueryRow) and pgx.Rows (Query).
type RowScanner interface {
	Scan(dest ...any) error
}

// TicketColumns is the column list (in scan order) for a conversations row —
// exported so internal/mentoring can reuse it in the bespoke UPDATE ...
// RETURNING queries backing claim/hand-assign/close, which have precondition
// semantics (must currently be 'open', etc.) too specific to live here.
const TicketColumns = `id, org_id, kind, requester_id, course_id, purchase_id, subject, category, priority, status,
	assigned_to, escalation_level, resolved_at, closed_at, created_at`

// ScanTicket scans a single conversations row (in TicketColumns order) into
// a Ticket.
func ScanTicket(row RowScanner) (Ticket, error) {
	var t Ticket
	err := row.Scan(&t.ID, &t.OrgID, &t.Kind, &t.RequesterID, &t.CourseID, &t.PurchaseID,
		&t.Subject, &t.Category, &t.Priority, &t.Status,
		&t.AssignedTo, &t.EscalationLevel, &t.ResolvedAt, &t.ClosedAt, &t.CreatedAt)
	return t, err
}

const messageColumns = `id, org_id, thread_id, sender_id, body, created_at`

func scanMessage(row RowScanner) (Message, error) {
	var m Message
	err := row.Scan(&m.ID, &m.OrgID, &m.TicketID, &m.SenderID, &m.Body, &m.CreatedAt)
	return m, err
}

// CreateWithMessage opens a new 'open' ticket and posts its first message
// (the reporter's own description) atomically. Used by the support-ticket
// creation path, where the reporter always supplies a first message.
func (r *Repo) CreateWithMessage(ctx context.Context, t Ticket, body string) (Ticket, error) {
	t.Status = StatusOpen
	var created Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`INSERT INTO conversations (org_id, kind, requester_id, subject, category, priority, status)
			 VALUES ($1,$2,$3,$4,$5,$6,$7)
			 RETURNING `+TicketColumns,
			t.OrgID, t.Kind, t.RequesterID, t.Subject, t.Category, t.Priority, t.Status,
		)
		var err error
		created, err = ScanTicket(row)
		if err != nil {
			return fmt.Errorf("create ticket: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO messages (org_id, thread_type, thread_id, sender_id, body) VALUES ($1,$2,$3,$4,$5)`,
			t.OrgID, threadType[t.Kind], created.ID, t.RequesterID, body,
		); err != nil {
			return fmt.Errorf("create first message: %w", err)
		}
		return nil
	})
	if err != nil {
		return Ticket{}, fmt.Errorf("tickets: create ticket with message: %w", err)
	}
	return created, nil
}

// CreateTx opens a new 'open' ticket within an externally-managed
// transaction and posts no first message — used by mentorship ticket
// creation, which is either auto-triggered inside the purchase-confirmation
// tx (no reporter-authored message exists yet) or student-initiated via
// RequestMentor (same shape, no message either).
func (r *Repo) CreateTx(ctx context.Context, tx pgx.Tx, t Ticket) (Ticket, error) {
	t.Status = StatusOpen
	row := tx.QueryRow(ctx,
		`INSERT INTO conversations (org_id, kind, requester_id, course_id, purchase_id, status)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 RETURNING `+TicketColumns,
		t.OrgID, t.Kind, t.RequesterID, t.CourseID, t.PurchaseID, t.Status,
	)
	created, err := ScanTicket(row)
	if err != nil {
		return Ticket{}, fmt.Errorf("tickets: create ticket: %w", err)
	}
	return created, nil
}

// Get returns a single ticket by ID, scoped to orgID. Excludes kind='direct'
// (ticket-independent mentor DMs) even though that kind lives in the same
// table — this package's ticket CRUD must never reach those rows.
func (r *Repo) Get(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT `+TicketColumns+` FROM conversations WHERE id = $1 AND org_id = $2 AND kind IN ('support','mentorship')`,
		ticketID, orgID)
	t, err := ScanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("tickets: get: %w", err)
	}
	return t, nil
}

// List returns tickets for orgID matching f — the staff queue. f.Kind is
// required.
func (r *Repo) List(ctx context.Context, orgID string, f Filter) ([]Ticket, error) {
	args := []any{orgID, f.Kind}
	where := "WHERE org_id = $1 AND kind = $2"
	n := 3
	if f.Status != nil && *f.Status != "" {
		where += fmt.Sprintf(" AND status = $%d", n)
		args = append(args, *f.Status)
		n++
	}
	if f.RequesterID != nil && *f.RequesterID != "" {
		where += fmt.Sprintf(" AND requester_id = $%d", n)
		args = append(args, *f.RequesterID)
		n++
	}
	if f.AssignedTo != nil && *f.AssignedTo != "" {
		where += fmt.Sprintf(" AND assigned_to = $%d", n)
		args = append(args, *f.AssignedTo)
		n++
	}
	rows, err := r.pool.Query(ctx, `SELECT `+TicketColumns+` FROM conversations `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("tickets: list: %w", err)
	}
	defer rows.Close()
	out := []Ticket{}
	for rows.Next() {
		t, err := ScanTicket(rows)
		if err != nil {
			return nil, fmt.Errorf("tickets: scan: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListMine returns every ticket userID has raised in orgID, most recent
// first. kind nil returns both support and mentorship tickets together (the
// merged "my tickets" view) — 'direct' is always excluded either way.
func (r *Repo) ListMine(ctx context.Context, orgID, userID string, kind *string) ([]Ticket, error) {
	args := []any{orgID, userID}
	where := "WHERE org_id = $1 AND requester_id = $2"
	if kind != nil && *kind != "" {
		where += " AND kind = $3"
		args = append(args, *kind)
	} else {
		where += " AND kind IN ('support','mentorship')"
	}
	rows, err := r.pool.Query(ctx, `SELECT `+TicketColumns+` FROM conversations `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("tickets: list mine: %w", err)
	}
	defer rows.Close()
	out := []Ticket{}
	for rows.Next() {
		t, err := ScanTicket(rows)
		if err != nil {
			return nil, fmt.Errorf("tickets: scan: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// UpdateStatus transitions a support ticket's status within orgID.
// assignedTo is self-assigned to the acting staff member the first time
// anyone touches an unclaimed ticket's status. resolved_at/closed_at are
// stamped when the new status is resolved/closed respectively, and cleared
// on any other status. Support-only — see Service.SetStatus.
func (r *Repo) UpdateStatus(ctx context.Context, orgID, ticketID, status, actorID string) (Ticket, error) {
	resolved := status == StatusResolved || status == StatusClosed
	closed := status == StatusClosed
	row := r.pool.QueryRow(ctx,
		`UPDATE conversations
		 SET status = $1,
		     assigned_to = COALESCE(assigned_to, $2),
		     resolved_at = CASE WHEN $3 THEN now() ELSE NULL END,
		     closed_at = CASE WHEN $4 THEN now() ELSE NULL END
		 WHERE id = $5 AND org_id = $6 AND kind = 'support'
		 RETURNING `+TicketColumns,
		status, actorID, resolved, closed, ticketID, orgID)
	t, err := ScanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("tickets: update status: %w", err)
	}
	return t, nil
}

// UpdateProperties sets a support ticket's category and priority within
// orgID — the triage step a staff member performs after reading a ticket.
func (r *Repo) UpdateProperties(ctx context.Context, orgID, ticketID, category, priority string) (Ticket, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE conversations
		 SET category = $1, priority = $2
		 WHERE id = $3 AND org_id = $4 AND kind = 'support'
		 RETURNING `+TicketColumns,
		category, priority, ticketID, orgID)
	t, err := ScanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("tickets: update properties: %w", err)
	}
	return t, nil
}

// CreateMessage posts a new message on ticketID's reply thread.
func (r *Repo) CreateMessage(ctx context.Context, orgID, ticketID, kind, senderID, body string) (Message, error) {
	var m Message
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`INSERT INTO messages (org_id, thread_type, thread_id, sender_id, body)
			 VALUES ($1,$2,$3,$4,$5)
			 RETURNING `+messageColumns,
			orgID, threadType[kind], ticketID, senderID, body)
		var err error
		m, err = scanMessage(row)
		if err != nil {
			return fmt.Errorf("create message: %w", err)
		}
		return nil
	})
	if err != nil {
		return Message{}, fmt.Errorf("tickets: create message: %w", err)
	}
	return m, nil
}

// ListMessages returns every message on ticketID's thread, oldest first.
func (r *Repo) ListMessages(ctx context.Context, orgID, ticketID, kind string) ([]Message, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+messageColumns+` FROM messages
		 WHERE org_id = $1 AND thread_type = $2 AND thread_id = $3
		 ORDER BY created_at ASC`,
		orgID, threadType[kind], ticketID)
	if err != nil {
		return nil, fmt.Errorf("tickets: list messages: %w", err)
	}
	defer rows.Close()
	out := []Message{}
	for rows.Next() {
		m, err := scanMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("tickets: scan message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

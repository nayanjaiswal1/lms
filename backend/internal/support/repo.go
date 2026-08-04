package support

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("support: not found")
	// ErrForbidden is returned when a caller tries to view/reply to a ticket
	// that isn't theirs and they don't hold support.manage.
	ErrForbidden = errors.New("support: forbidden")
)

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
		return fmt.Errorf("support: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("support: commit tx: %w", err)
	}
	return nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

const ticketColumns = `id, org_id, user_id, subject, category, priority, status,
	assigned_to, resolved_at, created_at, updated_at`

func scanTicket(row rowScanner) (Ticket, error) {
	var t Ticket
	err := row.Scan(&t.ID, &t.OrgID, &t.UserID, &t.Subject, &t.Category, &t.Priority, &t.Status,
		&t.AssignedTo, &t.ResolvedAt, &t.CreatedAt, &t.UpdatedAt)
	return t, err
}

const messageColumns = `id, org_id, ticket_id, sender_id, body, created_at`

func scanMessage(row rowScanner) (Message, error) {
	var m Message
	err := row.Scan(&m.ID, &m.OrgID, &m.TicketID, &m.SenderID, &m.Body, &m.CreatedAt)
	return m, err
}

// CreateTicketWithMessage opens a new 'open' ticket and posts its first
// message (the reporter's own description) atomically — a ticket with no
// description would leave staff nothing to act on, so the two inserts must
// either both land or neither does.
func (r *Repo) CreateTicketWithMessage(ctx context.Context, t Ticket, body string) (Ticket, error) {
	t.Status = StatusOpen
	var created Ticket
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`INSERT INTO support_tickets (org_id, user_id, subject, category, priority, status)
			 VALUES ($1,$2,$3,$4,$5,$6)
			 RETURNING `+ticketColumns,
			t.OrgID, t.UserID, t.Subject, t.Category, t.Priority, t.Status,
		)
		var err error
		created, err = scanTicket(row)
		if err != nil {
			return fmt.Errorf("create ticket: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO support_ticket_messages (org_id, ticket_id, sender_id, body) VALUES ($1,$2,$3,$4)`,
			t.OrgID, created.ID, t.UserID, body,
		); err != nil {
			return fmt.Errorf("create first message: %w", err)
		}
		return nil
	})
	if err != nil {
		return Ticket{}, fmt.Errorf("support: create ticket with message: %w", err)
	}
	return created, nil
}

// GetTicket returns a single ticket by ID, scoped to orgID.
func (r *Repo) GetTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+ticketColumns+` FROM support_tickets WHERE id = $1 AND org_id = $2`, ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("support: get ticket: %w", err)
	}
	return t, nil
}

// ListTickets returns tickets for orgID, optionally filtered by status
// and/or the reporting user (a user's own tickets).
func (r *Repo) ListTickets(ctx context.Context, orgID string, status *string, userID *string) ([]Ticket, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	n := 2
	if status != nil && *status != "" {
		where += fmt.Sprintf(" AND status = $%d", n)
		args = append(args, *status)
		n++
	}
	if userID != nil && *userID != "" {
		where += fmt.Sprintf(" AND user_id = $%d", n)
		args = append(args, *userID)
		n++
	}
	rows, err := r.pool.Query(ctx, `SELECT `+ticketColumns+` FROM support_tickets `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("support: list tickets: %w", err)
	}
	defer rows.Close()
	out := []Ticket{}
	for rows.Next() {
		t, err := scanTicket(rows)
		if err != nil {
			return nil, fmt.Errorf("support: scan ticket: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// UpdateStatus transitions a ticket's status within orgID. assignedTo is
// self-assigned to the acting staff member the first time anyone touches an
// unclaimed ticket's status (COALESCE keeps whoever claimed it first, rather
// than reassigning on every subsequent status change). resolved_at is
// stamped when the new status is 'resolved' or 'closed', and cleared on any
// other status (reopening a resolved ticket should not keep a stale
// resolved_at around).
func (r *Repo) UpdateStatus(ctx context.Context, orgID, ticketID, status, actorID string) (Ticket, error) {
	resolved := status == StatusResolved || status == StatusClosed
	row := r.pool.QueryRow(ctx,
		`UPDATE support_tickets
		 SET status = $1,
		     assigned_to = COALESCE(assigned_to, $2),
		     resolved_at = CASE WHEN $3 THEN now() ELSE NULL END,
		     updated_at = now()
		 WHERE id = $4 AND org_id = $5
		 RETURNING `+ticketColumns,
		status, actorID, resolved, ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("support: update status: %w", err)
	}
	return t, nil
}

// UpdateProperties sets a ticket's category and priority within orgID — the
// triage step a staff member performs after reading a ticket, since the
// reporter never chooses these (see Service.CreateTicket).
func (r *Repo) UpdateProperties(ctx context.Context, orgID, ticketID, category, priority string) (Ticket, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE support_tickets
		 SET category = $1, priority = $2, updated_at = now()
		 WHERE id = $3 AND org_id = $4
		 RETURNING `+ticketColumns,
		category, priority, ticketID, orgID)
	t, err := scanTicket(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Ticket{}, ErrNotFound
		}
		return Ticket{}, fmt.Errorf("support: update properties: %w", err)
	}
	return t, nil
}

// CreateMessage posts a new message on ticketID's reply thread and bumps the
// ticket's updated_at so a staff queue sorted by "most recently active"
// surfaces it.
func (r *Repo) CreateMessage(ctx context.Context, orgID, ticketID, senderID, body string) (Message, error) {
	var m Message
	err := r.tx(ctx, func(tx pgx.Tx) error {
		row := tx.QueryRow(ctx,
			`INSERT INTO support_ticket_messages (org_id, ticket_id, sender_id, body)
			 VALUES ($1,$2,$3,$4)
			 RETURNING `+messageColumns,
			orgID, ticketID, senderID, body)
		var err error
		m, err = scanMessage(row)
		if err != nil {
			return fmt.Errorf("create message: %w", err)
		}
		if _, err := tx.Exec(ctx, `UPDATE support_tickets SET updated_at = now() WHERE id = $1`, ticketID); err != nil {
			return fmt.Errorf("touch ticket: %w", err)
		}
		return nil
	})
	if err != nil {
		return Message{}, fmt.Errorf("support: create message: %w", err)
	}
	return m, nil
}

// ListMessages returns every message on ticketID's thread, oldest first.
func (r *Repo) ListMessages(ctx context.Context, orgID, ticketID string) ([]Message, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+messageColumns+` FROM support_ticket_messages
		 WHERE org_id = $1 AND ticket_id = $2
		 ORDER BY created_at ASC`,
		orgID, ticketID)
	if err != nil {
		return nil, fmt.Errorf("support: list messages: %w", err)
	}
	defer rows.Close()
	out := []Message{}
	for rows.Next() {
		m, err := scanMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("support: scan message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

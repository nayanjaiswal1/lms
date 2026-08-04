package support

import (
	"context"
	"errors"
	"fmt"
)

// ErrInvalid signals a request that failed validation before reaching the database.
var ErrInvalid = errors.New("support: invalid input")

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// CreateTicket validates and opens a new ticket on behalf of userID, with
// body as its first message — any org member may do this, no permission
// required. category/priority are deliberately not caller-supplied: triage
// is a staff judgment call made after reading the ticket (see
// UpdateProperties), not something the reporter picks from a dropdown, so a
// new ticket always starts 'other'/'normal'.
func (s *Service) CreateTicket(ctx context.Context, orgID, userID, subject, body string) (Ticket, error) {
	if len(subject) < 3 || len(subject) > 200 {
		return Ticket{}, fmt.Errorf("%w: subject must be between 3 and 200 characters", ErrInvalid)
	}
	if len(body) < 1 || len(body) > 4000 {
		return Ticket{}, fmt.Errorf("%w: message must be between 1 and 4000 characters", ErrInvalid)
	}
	return s.repo.CreateTicketWithMessage(ctx, Ticket{
		OrgID:    orgID,
		UserID:   userID,
		Subject:  subject,
		Category: CategoryOther,
		Priority: PriorityNormal,
	}, body)
}

// UpdateProperties sets ticketID's category and priority within orgID.
// Callers must already hold support.manage (checked by route middleware) —
// this is the staff triage step, never the reporter's own choice.
func (s *Service) UpdateProperties(ctx context.Context, orgID, ticketID, category, priority string) (Ticket, error) {
	if !IsValidCategory(category) {
		return Ticket{}, fmt.Errorf("%w: category must be one of technical, billing, account, course_content, other", ErrInvalid)
	}
	if !IsValidPriority(priority) {
		return Ticket{}, fmt.Errorf("%w: priority must be one of low, normal, high", ErrInvalid)
	}
	return s.repo.UpdateProperties(ctx, orgID, ticketID, category, priority)
}

// ListMyTickets returns every ticket userID has raised in orgID, most recent first.
func (s *Service) ListMyTickets(ctx context.Context, orgID, userID string) ([]Ticket, error) {
	return s.repo.ListTickets(ctx, orgID, nil, &userID)
}

// ListTickets returns every ticket in orgID, optionally filtered by status —
// the staff queue. Callers must already hold support.manage (checked by
// route middleware).
func (s *Service) ListTickets(ctx context.Context, orgID string, status *string) ([]Ticket, error) {
	return s.repo.ListTickets(ctx, orgID, status, nil)
}

// GetTicket returns ticketID within orgID, if callerID is allowed to see it —
// its own reporter, or a caller who holds support.manage. Returns
// ErrForbidden otherwise, ErrNotFound if the ticket doesn't exist in orgID.
func (s *Service) GetTicket(ctx context.Context, orgID, ticketID, callerID string, canManage bool) (Ticket, error) {
	t, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return Ticket{}, err
	}
	if t.UserID != callerID && !canManage {
		return Ticket{}, ErrForbidden
	}
	return t, nil
}

// UpdateStatus transitions ticketID's status within orgID. Callers must
// already hold support.manage (checked by route middleware) — a reporter
// cannot self-close their own ticket through this path, since "resolved" is
// a staff determination, not a self-report.
func (s *Service) UpdateStatus(ctx context.Context, orgID, ticketID, status, actorID string) (Ticket, error) {
	if !IsValidStatus(status) {
		return Ticket{}, fmt.Errorf("%w: status must be one of open, in_progress, resolved, closed", ErrInvalid)
	}
	return s.repo.UpdateStatus(ctx, orgID, ticketID, status, actorID)
}

// SendMessage posts a reply on ticketID's thread. Only the ticket's own
// reporter or a caller holding support.manage may post, and only while the
// ticket isn't closed — there's nothing to discuss on a closed ticket until
// staff reopens it via UpdateStatus.
func (s *Service) SendMessage(ctx context.Context, orgID, ticketID, senderID, body string, canManage bool) (Message, error) {
	if len(body) < 1 || len(body) > 4000 {
		return Message{}, fmt.Errorf("%w: message must be between 1 and 4000 characters", ErrInvalid)
	}
	t, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return Message{}, err
	}
	if t.UserID != senderID && !canManage {
		return Message{}, ErrForbidden
	}
	if t.Status == StatusClosed {
		return Message{}, fmt.Errorf("%w: this ticket is closed", ErrInvalid)
	}
	return s.repo.CreateMessage(ctx, orgID, ticketID, senderID, body)
}

// ListMessages returns the full reply thread for ticketID. Only the
// ticket's own reporter or a caller holding support.manage may read it.
func (s *Service) ListMessages(ctx context.Context, orgID, ticketID, callerID string, canManage bool) ([]Message, error) {
	t, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return nil, err
	}
	if t.UserID != callerID && !canManage {
		return nil, ErrForbidden
	}
	return s.repo.ListMessages(ctx, orgID, ticketID)
}

package tickets

import (
	"context"
	"errors"
	"fmt"
)

// ErrInvalid signals a request that failed validation before reaching the
// database.
var ErrInvalid = errors.New("tickets: invalid input")

type Service struct {
	repo *Repo
}

func NewService(repo *Repo) *Service {
	return &Service{repo: repo}
}

// canAccess reports whether callerID may view/reply to t: its own
// requester, its current assignee, or a caller holding t.Kind's manage
// permission (canManage, resolved by the handler before calling in — Service
// has no access to the authz package's permission check).
func canAccess(t Ticket, callerID string, canManage bool) bool {
	if callerID == t.RequesterID || canManage {
		return true
	}
	return t.AssignedTo != nil && *t.AssignedTo == callerID
}

// Kind returns ticketID's kind, scoped to orgID — used by the handler to
// resolve which permission (support.manage vs mentoring.assign_tickets) an
// id-scoped endpoint should check, before the endpoint's own call re-loads
// and re-validates the ticket.
func (s *Service) Kind(ctx context.Context, orgID, ticketID string) (string, error) {
	t, err := s.repo.Get(ctx, orgID, ticketID)
	if err != nil {
		return "", err
	}
	return t.Kind, nil
}

// CreateSupportTicket validates and opens a new support ticket on behalf of
// userID, with body as its first message — any org member may do this, no
// permission required. category/priority are deliberately not
// caller-supplied: triage is a staff judgment call made after reading the
// ticket (see SetProperties), not something the reporter picks from a
// dropdown, so a new ticket always starts other/normal.
func (s *Service) CreateSupportTicket(ctx context.Context, orgID, userID, subject, body string) (Ticket, error) {
	if len(subject) < 3 || len(subject) > 200 {
		return Ticket{}, fmt.Errorf("%w: subject must be between 3 and 200 characters", ErrInvalid)
	}
	if len(body) < 1 || len(body) > 4000 {
		return Ticket{}, fmt.Errorf("%w: message must be between 1 and 4000 characters", ErrInvalid)
	}
	category, priority := CategoryOther, PriorityNormal
	return s.repo.CreateWithMessage(ctx, Ticket{
		OrgID: orgID, Kind: KindSupport, RequesterID: userID,
		Subject: &subject, Category: &category, Priority: &priority,
	}, body)
}

// Get returns ticketID within orgID, plus its full reply thread, if callerID
// is allowed to see it — its own requester, its current assignee, or a
// caller who holds canManage. Returns ErrForbidden otherwise, ErrNotFound if
// the ticket doesn't exist in orgID.
func (s *Service) Get(ctx context.Context, orgID, ticketID, callerID string, canManage bool) (TicketDetail, error) {
	t, err := s.repo.Get(ctx, orgID, ticketID)
	if err != nil {
		return TicketDetail{}, err
	}
	if !canAccess(t, callerID, canManage) {
		return TicketDetail{}, ErrForbidden
	}
	msgs, err := s.repo.ListMessages(ctx, orgID, ticketID, t.Kind)
	if err != nil {
		return TicketDetail{}, fmt.Errorf("tickets: get detail: %w", err)
	}
	return TicketDetail{Ticket: t, Messages: msgs}, nil
}

// ListQueue returns every ticket of kind in orgID, optionally filtered by
// status and/or assignedTo — the staff queue. Callers must already hold
// kind's QueuePermission (checked by the handler).
func (s *Service) ListQueue(ctx context.Context, orgID, kind string, status, assignedTo *string) ([]Ticket, error) {
	return s.repo.List(ctx, orgID, Filter{Kind: kind, Status: status, AssignedTo: assignedTo})
}

// ListMine returns every ticket userID has raised in orgID, most recent
// first. kind nil returns both support and mentorship tickets — the merged
// student-facing "my tickets" view.
func (s *Service) ListMine(ctx context.Context, orgID, userID string, kind *string) ([]Ticket, error) {
	return s.repo.ListMine(ctx, orgID, userID, kind)
}

// SendMessage posts a reply on ticketID's thread. Only the ticket's own
// requester, its current assignee, or a caller holding canManage may post,
// and only while the ticket isn't closed — there's nothing to discuss on a
// closed ticket until staff/the assignee reopens it.
func (s *Service) SendMessage(ctx context.Context, orgID, ticketID, senderID, body string, canManage bool) (Message, error) {
	if len(body) < 1 || len(body) > 4000 {
		return Message{}, fmt.Errorf("%w: message must be between 1 and 4000 characters", ErrInvalid)
	}
	t, err := s.repo.Get(ctx, orgID, ticketID)
	if err != nil {
		return Message{}, err
	}
	if !canAccess(t, senderID, canManage) {
		return Message{}, ErrForbidden
	}
	if t.Status == StatusClosed {
		return Message{}, fmt.Errorf("%w: this ticket is closed", ErrInvalid)
	}
	return s.repo.CreateMessage(ctx, orgID, ticketID, t.Kind, senderID, body)
}

// ListMessages returns the full reply thread for ticketID. Only the
// ticket's own requester, its current assignee, or a caller holding
// canManage may read it.
func (s *Service) ListMessages(ctx context.Context, orgID, ticketID, callerID string, canManage bool) ([]Message, error) {
	t, err := s.repo.Get(ctx, orgID, ticketID)
	if err != nil {
		return nil, err
	}
	if !canAccess(t, callerID, canManage) {
		return nil, ErrForbidden
	}
	return s.repo.ListMessages(ctx, orgID, ticketID, t.Kind)
}

// SetStatus transitions ticketID's status within orgID. Support-only —
// mentorship tickets change status exclusively through claim/assign/close/
// change-request-approval (internal/mentoring), which also maintain
// invariants (e.g. status=assigned always has assigned_to set) this generic
// setter doesn't enforce. Callers must already hold support.manage (checked
// by the handler) — a reporter cannot self-close their own ticket through
// this path, since "resolved" is a staff determination.
func (s *Service) SetStatus(ctx context.Context, orgID, ticketID, status, actorID string) (Ticket, error) {
	t, err := s.repo.Get(ctx, orgID, ticketID)
	if err != nil {
		return Ticket{}, err
	}
	if t.Kind != KindSupport {
		return Ticket{}, fmt.Errorf("%w: status can only be set directly on support tickets", ErrInvalid)
	}
	if !IsValidStatus(t.Kind, status) {
		return Ticket{}, fmt.Errorf("%w: status must be one of open, in_progress, resolved, closed", ErrInvalid)
	}
	return s.repo.UpdateStatus(ctx, orgID, ticketID, status, actorID)
}

// SetProperties sets a support ticket's category and priority within
// orgID — the staff triage step. Support-only, same reasoning as SetStatus.
func (s *Service) SetProperties(ctx context.Context, orgID, ticketID, category, priority string) (Ticket, error) {
	t, err := s.repo.Get(ctx, orgID, ticketID)
	if err != nil {
		return Ticket{}, err
	}
	if t.Kind != KindSupport {
		return Ticket{}, fmt.Errorf("%w: category and priority only apply to support tickets", ErrInvalid)
	}
	if !IsValidCategory(category) {
		return Ticket{}, fmt.Errorf("%w: category must be one of technical, billing, account, course_content, other", ErrInvalid)
	}
	if !IsValidPriority(priority) {
		return Ticket{}, fmt.Errorf("%w: priority must be one of low, normal, high", ErrInvalid)
	}
	return s.repo.UpdateProperties(ctx, orgID, ticketID, category, priority)
}

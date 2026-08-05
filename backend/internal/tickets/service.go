package tickets

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/mindforge/backend/internal/config"
)

// ErrInvalid signals a request that failed validation before reaching the
// database.
var ErrInvalid = errors.New("tickets: invalid input")

type Service struct {
	repo *Repo
	cfg  *config.Config
}

func NewService(repo *Repo, cfg *config.Config) *Service {
	return &Service{repo: repo, cfg: cfg}
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
	ticket, err := s.repo.CreateWithMessage(ctx, Ticket{
		OrgID: orgID, Kind: KindSupport, RequesterID: userID,
		Subject: &subject, Category: &category, Priority: &priority,
	}, body)
	if err != nil {
		return Ticket{}, err
	}
	s.notifyCreated(ctx, ticket)
	return ticket, nil
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
	msg, err := s.repo.CreateMessage(ctx, orgID, ticketID, t.Kind, senderID, body)
	if err != nil {
		return Message{}, err
	}
	s.notifyReply(ctx, t, msg, senderID)
	return msg, nil
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

// ─── email notifications ────────────────────────────────────────────────────
//
// Every email below goes out through the same email.send job path
// jobs/handlers/mentor_escalation.go already uses (type "notification"), and
// every one carries In-Reply-To/References back to rootMessageID(ticket) —
// a synthetic id, never itself the Message-Id of a sent email — so a mail
// client threads the confirmation, every staff alert, and every reply
// notification for one ticket into a single conversation. Enqueue failures
// are logged, never returned: a notification problem must never fail the
// ticket write that triggered it.

// threadDomain returns the domain portion of emailFrom ("mindforge.com" from
// "noreply@mindforge.com"), used to build Message-Id values.
func threadDomain(emailFrom string) string {
	if i := strings.LastIndex(emailFrom, "@"); i >= 0 {
		return emailFrom[i+1:]
	}
	return "mindforge.local"
}

func rootMessageID(domain, ticketID string) string {
	return fmt.Sprintf("<ticket-%s@%s>", ticketID, domain)
}

// childMessageID is a real, unique Message-Id for one email about ticketID —
// suffix distinguishes concurrent recipients of the same event (e.g. two
// staff alerts sent for the same new ticket).
func childMessageID(domain, ticketID, suffix string) string {
	return fmt.Sprintf("<ticket-%s-%s@%s>", ticketID, suffix, domain)
}

// notifyCreated emails the reporter a confirmation and every support.manage
// holder an alert, for a just-created support ticket.
func (s *Service) notifyCreated(ctx context.Context, t Ticket) {
	domain := threadDomain(s.cfg.EmailFrom)
	root := rootMessageID(domain, t.ID)
	link := s.cfg.FrontendURL + "/support?ticket=" + t.ID
	subject := *t.Subject

	if requester, err := s.repo.userContact(ctx, t.RequesterID); err != nil {
		slog.ErrorContext(ctx, "tickets: resolve requester contact", "ticket_id", t.ID, "error", err)
	} else if requester.Email != "" {
		greeting := "Hi"
		if requester.Name != "" {
			greeting = "Hi " + requester.Name
		}
		body := fmt.Sprintf("%s,\n\nWe've received your support ticket \"%s\" and will get back to you soon.\n\nView it here:\n%s\n\nThe MindForge Team",
			greeting, subject, link)
		if err := s.repo.enqueueEmail(ctx, "ticket-created-requester:"+t.ID, requester.Email, requester.Name,
			"We've received your ticket: "+subject, body,
			childMessageID(domain, t.ID, "created-requester"), root,
		); err != nil {
			slog.ErrorContext(ctx, "tickets: enqueue requester confirmation", "ticket_id", t.ID, "error", err)
		}
	}

	staff, err := s.repo.manageContacts(ctx, t.OrgID, ManagePermission[KindSupport])
	if err != nil {
		slog.ErrorContext(ctx, "tickets: resolve support staff contacts", "ticket_id", t.ID, "error", err)
		return
	}
	body := fmt.Sprintf("A new support ticket was raised.\n\nSubject: %s\n\nView it here:\n%s", subject, link)
	for _, staffer := range staff {
		if err := s.repo.enqueueEmail(ctx, fmt.Sprintf("ticket-created-staff:%s:%s", t.ID, staffer.ID), staffer.Email, staffer.Name,
			"New support ticket: "+subject, body,
			childMessageID(domain, t.ID, "created-staff-"+staffer.ID), root,
		); err != nil {
			slog.ErrorContext(ctx, "tickets: enqueue staff alert", "ticket_id", t.ID, "staff_id", staffer.ID, "error", err)
		}
	}
}

// notifyReply emails the "other side" of a support ticket's conversation
// after senderID posts msg: the requester if staff/the assignee replied, or
// the assignee — falling back to every support.manage holder if the ticket
// is still unclaimed — if the requester replied. Mentorship tickets are
// deliberately excluded: their notifications are already owned end-to-end by
// jobs/handlers/mentor_escalation.go, and having two systems separately
// decide who to email about the same ticket would drift out of sync.
func (s *Service) notifyReply(ctx context.Context, t Ticket, msg Message, senderID string) {
	if t.Kind != KindSupport {
		return
	}
	domain := threadDomain(s.cfg.EmailFrom)
	root := rootMessageID(domain, t.ID)
	link := s.cfg.FrontendURL + "/support?ticket=" + t.ID
	subject := *t.Subject
	body := fmt.Sprintf("There's a new reply on ticket \"%s\":\n\n%s\n\nView the full conversation:\n%s", subject, msg.Body, link)

	var recipients []contact
	var err error
	switch {
	case senderID == t.RequesterID && t.AssignedTo != nil:
		var c contact
		if c, err = s.repo.userContact(ctx, *t.AssignedTo); err == nil {
			recipients = []contact{c}
		}
	case senderID == t.RequesterID:
		recipients, err = s.repo.manageContacts(ctx, t.OrgID, ManagePermission[KindSupport])
	default:
		var c contact
		if c, err = s.repo.userContact(ctx, t.RequesterID); err == nil {
			recipients = []contact{c}
		}
	}
	if err != nil {
		slog.ErrorContext(ctx, "tickets: resolve reply-notification recipients", "ticket_id", t.ID, "error", err)
		return
	}

	for _, r := range recipients {
		if r.Email == "" {
			continue
		}
		if err := s.repo.enqueueEmail(ctx, fmt.Sprintf("ticket-reply:%s:%s", msg.ID, r.ID), r.Email, r.Name,
			"New reply on your ticket: "+subject, body,
			childMessageID(domain, t.ID, "reply-"+msg.ID+"-"+r.ID), root,
		); err != nil {
			slog.ErrorContext(ctx, "tickets: enqueue reply notification", "ticket_id", t.ID, "recipient_id", r.ID, "error", err)
		}
	}
}

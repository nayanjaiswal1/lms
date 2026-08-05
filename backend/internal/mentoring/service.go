package mentoring

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/payments"
	"github.com/mindforge/backend/internal/tickets"
)

// ErrInvalid signals a request that failed validation before reaching the
// database.
var ErrInvalid = errors.New("mentoring: invalid input")

// Service orchestrates the paid-course purchase flow (checkout -> webhook
// confirm -> purchase record -> coupon redemption -> enrollment ->
// mentor-ticket dedup, see service_purchase.go) plus the mentor
// ticket/report/directory workflows.
type Service struct {
	repo        *Repo
	tickets     *tickets.Repo
	providers   *payments.Registry
	coupons     *coupons.Service
	coursesRepo *courses.Repo
	packs       PackConfirmer
	frontendURL string
	currency    string
}

// PackConfirmer is the seam for products that check out through the same
// payment gateway as a course but are not a course — currently only
// sessions.Service and its mentor-session credit packs.
//
// There is exactly one webhook URL per gateway (see RegisterPublicRoutes), so
// something has to fan a delivery out to whichever product it belongs to.
// This package owns that endpoint for historical reasons, so it does the
// fan-out; matched=false means "not mine either", which is what turns an
// unmatched delivery into a logged no-op instead of a 72-hour gateway retry
// storm. A bool rather than a sentinel error so neither package has to
// import the other's error values to interpret the answer.
type PackConfirmer interface {
	ConfirmPackPurchase(ctx context.Context, providerName, providerRef, paymentRef string, amountCents int, currency string, succeeded bool) (matched bool, err error)
}

// NewService wires a Service. coursesRepo is used only for its
// CreateEnrollmentTx capability, so the paid-course enrollment insert stays
// byte-identical to courses.Repo.CreateEnrollment's free-course path instead
// of being duplicated here. packs may be nil — a deployment with no session
// booking simply has no second product to fan webhooks out to. ticketsRepo
// backs mentorship ticket creation (RequestMentor, confirmPurchase) — the
// shared internal/tickets package owns the conversations/messages CRUD both
// this package and internal/tickets' own support-ticket flow build on.
func NewService(repo *Repo, ticketsRepo *tickets.Repo, providers *payments.Registry, couponsSvc *coupons.Service, coursesRepo *courses.Repo, packs PackConfirmer, cfg *config.Config) *Service {
	return &Service{
		repo: repo, tickets: ticketsRepo, providers: providers, coupons: couponsSvc, coursesRepo: coursesRepo,
		packs: packs, frontendURL: cfg.FrontendURL, currency: cfg.PaymentsCurrency,
	}
}

// RequestMentor lets a student who does not currently have an active mentor
// ticket open one for a course they are enrolled in. This is the
// student-initiated counterpart to the auto-opened ticket in confirmPurchase
// (service_purchase.go) — it covers free courses and any other case where no
// ticket was opened automatically. Returns ErrInvalid if the student isn't
// enrolled in courseID, ErrAlreadyHasMentor if they already have an open or
// assigned ticket anywhere in the org (mirrors confirmPurchase's
// HasActiveMentor dedup).
func (s *Service) RequestMentor(ctx context.Context, orgID, userID, courseID string) (tickets.Ticket, error) {
	enrolled, err := s.coursesRepo.IsEnrolled(ctx, userID, courseID)
	if err != nil {
		return tickets.Ticket{}, fmt.Errorf("mentoring: request mentor: check enrollment: %w", err)
	}
	if !enrolled {
		return tickets.Ticket{}, fmt.Errorf("%w: you must be enrolled in this course to request a mentor", ErrInvalid)
	}

	var ticket tickets.Ticket
	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		hasMentor, txErr := s.repo.HasActiveMentor(ctx, tx, orgID, userID)
		if txErr != nil {
			return txErr
		}
		if hasMentor {
			return ErrAlreadyHasMentor
		}
		created, txErr := s.tickets.CreateTx(ctx, tx, tickets.Ticket{
			OrgID:       orgID,
			Kind:        tickets.KindMentorship,
			RequesterID: userID,
			CourseID:    &courseID,
		})
		if txErr != nil {
			return txErr
		}
		ticket = created
		return nil
	})
	if err != nil {
		return tickets.Ticket{}, err
	}
	return ticket, nil
}

// ClaimTicket lets a mentor self-assign an open ticket within orgID.
func (s *Service) ClaimTicket(ctx context.Context, orgID, ticketID, mentorID string) (tickets.Ticket, error) {
	return s.repo.ClaimTicket(ctx, orgID, ticketID, mentorID)
}

// AssignTicket lets a staff member hand-assign a mentor to an open ticket
// within orgID. Validates that mentorID actually holds the mentor role in
// this org before assigning — otherwise a staff member could hand a ticket
// to an arbitrary user ID.
func (s *Service) AssignTicket(ctx context.Context, orgID, ticketID, mentorID, assignedBy string) (tickets.Ticket, error) {
	isMentor, err := s.repo.IsMentor(ctx, orgID, mentorID)
	if err != nil {
		return tickets.Ticket{}, err
	}
	if !isMentor {
		return tickets.Ticket{}, fmt.Errorf("%w: mentor_id must be a mentor in this organization", ErrInvalid)
	}
	return s.repo.AssignTicket(ctx, orgID, ticketID, mentorID, assignedBy)
}

// CloseTicket closes a ticket within orgID. Callers must already have
// verified the caller is either the assigned mentor or holds
// mentoring.assign_tickets.
func (s *Service) CloseTicket(ctx context.Context, orgID, ticketID string) (tickets.Ticket, error) {
	return s.repo.CloseTicket(ctx, orgID, ticketID)
}

// GetTicket returns a single ticket by ID, scoped to orgID — a thin
// pass-through to the shared tickets.Repo, kept here since CloseTicket's
// handler needs it for its either/or ownership check (own student, assigned
// mentor, or mentoring.assign_tickets) before calling CloseTicket.
func (s *Service) GetTicket(ctx context.Context, orgID, ticketID string) (tickets.Ticket, error) {
	return s.tickets.Get(ctx, orgID, ticketID)
}

// ListMentorDirectory returns every mentor in orgID with a live mentee count
// and aggregated rating.
func (s *Service) ListMentorDirectory(ctx context.Context, orgID string) ([]MentorDirectoryEntry, error) {
	return s.repo.ListMentorDirectory(ctx, orgID)
}

// GetMentorProfile returns the single-mentor profile view (directory fields
// plus verified/response-time/hours/percentile) for mentorID within orgID.
func (s *Service) GetMentorProfile(ctx context.Context, orgID, mentorID string) (MentorProfile, error) {
	return s.repo.GetMentorProfile(ctx, orgID, mentorID)
}

// SetMentorVerified toggles mentorID's verified-expert badge. The caller's
// permission to do this (mentoring.verify_mentors) is already checked by
// route middleware; this only validates that mentorID is actually a mentor
// in this org before writing.
func (s *Service) SetMentorVerified(ctx context.Context, orgID, mentorID string, verified bool, callerID string) error {
	isMentor, err := s.repo.IsMentor(ctx, orgID, mentorID)
	if err != nil {
		return err
	}
	if !isMentor {
		return fmt.Errorf("%w: mentor_id must be a mentor in this organization", ErrInvalid)
	}
	return s.repo.SetMentorVerified(ctx, mentorID, verified, callerID)
}

// GetOrCreateConversation returns (creating if needed) the ticket-independent
// DM thread between studentID and mentorID. mentorID must actually hold the
// mentor role in orgID — this is a student-initiates-contact-with-a-mentor
// flow, not a general "message anyone" feature.
func (s *Service) GetOrCreateConversation(ctx context.Context, orgID, studentID, mentorID string) (MentorConversation, error) {
	if studentID == mentorID {
		return MentorConversation{}, fmt.Errorf("%w: cannot start a conversation with yourself", ErrInvalid)
	}
	isMentor, err := s.repo.IsMentor(ctx, orgID, mentorID)
	if err != nil {
		return MentorConversation{}, err
	}
	if !isMentor {
		return MentorConversation{}, fmt.Errorf("%w: mentor_id must be a mentor in this organization", ErrInvalid)
	}
	return s.repo.GetOrCreateConversation(ctx, orgID, studentID, mentorID)
}

// ListMyConversations returns every DM conversation callerID is a party to,
// most recently active first.
func (s *Service) ListMyConversations(ctx context.Context, orgID, callerID string) ([]MentorConversation, error) {
	return s.repo.ListMyConversations(ctx, orgID, callerID)
}

// SendConversationMessage posts a message on conversationID's DM thread.
// Only the conversation's student or mentor may post — same access shape as
// SendChatMessage, against mentor_conversations instead of mentor_tickets.
func (s *Service) SendConversationMessage(ctx context.Context, orgID, conversationID, senderID, body string) (DirectMessage, error) {
	if len(body) < 1 || len(body) > 4000 {
		return DirectMessage{}, fmt.Errorf("%w: message must be between 1 and 4000 characters", ErrInvalid)
	}
	conv, err := s.repo.GetConversation(ctx, orgID, conversationID)
	if err != nil {
		return DirectMessage{}, err
	}
	if senderID != conv.StudentID && senderID != conv.MentorID {
		return DirectMessage{}, ErrForbidden
	}
	return s.repo.CreateDirectMessage(ctx, orgID, conversationID, senderID, body)
}

// ListConversationMessages returns the full DM thread for conversationID.
// Only the conversation's student or mentor may read it.
func (s *Service) ListConversationMessages(ctx context.Context, orgID, conversationID, callerID string) ([]DirectMessage, error) {
	conv, err := s.repo.GetConversation(ctx, orgID, conversationID)
	if err != nil {
		return nil, err
	}
	if callerID != conv.StudentID && callerID != conv.MentorID {
		return nil, ErrForbidden
	}
	return s.repo.ListDirectMessages(ctx, orgID, conversationID)
}

// GetTicketDetail returns the full staff-facing lifecycle for ticketID: the
// ticket and every change request filed against it. Reports are included
// only when canViewReports is true — the handler decides that via
// authzSvc.HasPermission before calling in, since Service has no access to
// the authz package's permission check.
func (s *Service) GetTicketDetail(ctx context.Context, orgID, ticketID string, canViewReports bool) (TicketLifecycle, error) {
	ticket, err := s.tickets.Get(ctx, orgID, ticketID)
	if err != nil {
		return TicketLifecycle{}, err
	}
	changeRequests, err := s.repo.ListChangeRequestsByTicket(ctx, ticketID)
	if err != nil {
		return TicketLifecycle{}, err
	}
	detail := TicketLifecycle{Ticket: ticket, ChangeRequests: changeRequests}
	if canViewReports {
		reports, err := s.repo.ListReportsByTicket(ctx, ticketID)
		if err != nil {
			return TicketLifecycle{}, err
		}
		detail.Reports = reports
	}
	return detail, nil
}

// HasBeenMentoredBy implements feedback.MentorshipVerifier — it lets the
// feedback package gate mentor ratings without importing this package
// directly (mentoring already imports courses, and feedback stays a
// leaf dependency of both).
func (s *Service) HasBeenMentoredBy(ctx context.Context, orgID, studentID, mentorID string) (bool, error) {
	return s.repo.HasBeenMentoredBy(ctx, orgID, studentID, mentorID)
}

// HasCompletedPurchase implements certificates.PurchaseChecker — lets the
// certificates package gate threshold-based auto-issue on payment for paid
// courses without importing this package directly.
func (s *Service) HasCompletedPurchase(ctx context.Context, userID, courseID string) (bool, error) {
	return s.repo.HasCompletedPurchase(ctx, userID, courseID)
}

// ReportMentor validates and files a new complaint against a mentor.
func (s *Service) ReportMentor(ctx context.Context, orgID, mentorID, reporterID, reason, description string, ticketID *string) (Report, error) {
	if !IsValidReportReason(reason) {
		return Report{}, fmt.Errorf("%w: reason must be one of unresponsive, inappropriate_behavior, unqualified, other", ErrInvalid)
	}
	if len(description) < 10 || len(description) > 2000 {
		return Report{}, fmt.Errorf("%w: description must be between 10 and 2000 characters", ErrInvalid)
	}
	return s.repo.CreateReport(ctx, Report{
		OrgID:       orgID,
		MentorID:    mentorID,
		ReporterID:  reporterID,
		TicketID:    ticketID,
		Reason:      reason,
		Description: description,
	})
}

// ListReports returns mentor complaint reports for orgID, optionally
// filtered by status.
func (s *Service) ListReports(ctx context.Context, orgID string, status *string) ([]Report, error) {
	return s.repo.ListReports(ctx, orgID, status)
}

// ResolveReport marks a report within orgID resolved or dismissed.
func (s *Service) ResolveReport(ctx context.Context, orgID, reportID, resolvedBy, status, note string) (Report, error) {
	if !IsValidReportResolution(status) {
		return Report{}, fmt.Errorf("%w: status must be resolved or dismissed", ErrInvalid)
	}
	return s.repo.ResolveReport(ctx, orgID, reportID, resolvedBy, status, note)
}

// RequestMentorChange lets the ticket's own student ask for a different
// mentor. Only allowed on a ticket that is currently 'assigned' (nothing to
// change on an open or already-closed ticket) and only by that ticket's
// student — returns ErrForbidden otherwise. ErrChangeRequestPending surfaces
// if one is already pending for this ticket.
func (s *Service) RequestMentorChange(ctx context.Context, orgID, ticketID, studentID, reason string) (ChangeRequest, error) {
	if len(reason) < 10 || len(reason) > 1000 {
		return ChangeRequest{}, fmt.Errorf("%w: reason must be between 10 and 1000 characters", ErrInvalid)
	}
	ticket, err := s.tickets.Get(ctx, orgID, ticketID)
	if err != nil {
		return ChangeRequest{}, err
	}
	if ticket.RequesterID != studentID {
		return ChangeRequest{}, ErrForbidden
	}
	if ticket.Status != TicketStatusAssigned {
		return ChangeRequest{}, fmt.Errorf("%w: only an assigned ticket can request a mentor change", ErrInvalid)
	}
	return s.repo.CreateChangeRequest(ctx, ChangeRequest{
		OrgID:     orgID,
		TicketID:  ticketID,
		StudentID: studentID,
		Reason:    reason,
	})
}

// ListChangeRequests returns mentor change requests for orgID, optionally
// filtered by status.
func (s *Service) ListChangeRequests(ctx context.Context, orgID string, status *string) ([]ChangeRequest, error) {
	return s.repo.ListChangeRequests(ctx, orgID, status)
}

// ApproveChangeRequest approves a pending change request and reopens its
// ticket for reclaim/reassignment.
func (s *Service) ApproveChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, tickets.Ticket, error) {
	return s.repo.ApproveChangeRequest(ctx, orgID, requestID, reviewedBy, note)
}

// DenyChangeRequest denies a pending change request; the ticket is untouched.
func (s *Service) DenyChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, error) {
	return s.repo.DenyChangeRequest(ctx, orgID, requestID, reviewedBy, note)
}

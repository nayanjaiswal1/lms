package mentoring

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/payments"
)

// ErrInvalid signals a request that failed validation before reaching the
// database.
var ErrInvalid = errors.New("mentoring: invalid input")

// Service orchestrates the paid-course purchase flow (charge -> purchase
// record -> enrollment -> mentor-ticket dedup) plus the mentor
// ticket/report/directory workflows.
type Service struct {
	repo        *Repo
	provider    payments.Provider
	coursesRepo *courses.Repo
}

// NewService wires a Service. coursesRepo is used only for its
// CreateEnrollmentTx capability, so the paid-course enrollment insert stays
// byte-identical to courses.Repo.CreateEnrollment's free-course path instead
// of being duplicated here.
func NewService(repo *Repo, provider payments.Provider, coursesRepo *courses.Repo) *Service {
	return &Service{repo: repo, provider: provider, coursesRepo: coursesRepo}
}

// purchaseCourse charges the student for a paid course, records the
// purchase, enrolls them, and opens a mentor ticket unless they already have
// an active mentor in this org. The charge itself happens before the
// transaction opens (it is an external call, not a DB write, and there is no
// reason to hold a DB connection while waiting on it); the purchase record,
// enrollment, dedup check, and ticket creation all commit atomically.
func (s *Service) purchaseCourse(ctx context.Context, orgID, userID, courseID string, amountCents int) (Purchase, courses.Enrollment, *Ticket, error) {
	if amountCents <= 0 {
		return Purchase{}, courses.Enrollment{}, nil, fmt.Errorf("%w: amount_cents must be positive", ErrInvalid)
	}

	chargeResult, err := s.provider.Charge(ctx, payments.ChargeParams{
		OrgID:       orgID,
		UserID:      userID,
		CourseID:    courseID,
		AmountCents: amountCents,
		Currency:    "USD",
	})
	if err != nil {
		return Purchase{}, courses.Enrollment{}, nil, fmt.Errorf("mentoring: charge: %w", err)
	}

	var purchase Purchase
	var enrollment courses.Enrollment
	var ticket *Ticket
	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		var txErr error
		purchase, txErr = s.repo.CreatePurchase(ctx, tx, Purchase{
			OrgID:       orgID,
			UserID:      userID,
			CourseID:    courseID,
			AmountCents: amountCents,
			Currency:    "USD",
			Provider:    ProviderStub,
			ProviderRef: chargeResult.ProviderRef,
			Status:      PurchaseStatusCompleted,
		})
		if txErr != nil {
			return txErr
		}

		enrolledBy := userID
		enrollment, txErr = s.coursesRepo.CreateEnrollmentTx(ctx, tx, courses.Enrollment{
			UserID:     userID,
			CourseID:   courseID,
			EnrolledBy: &enrolledBy,
		})
		if txErr != nil {
			return txErr
		}

		hasMentor, txErr := s.repo.HasActiveMentor(ctx, tx, orgID, userID)
		if txErr != nil {
			return txErr
		}
		if !hasMentor {
			purchaseID := purchase.ID
			created, txErr := s.repo.CreateTicket(ctx, tx, Ticket{
				OrgID:      orgID,
				StudentID:  userID,
				CourseID:   courseID,
				PurchaseID: &purchaseID,
			})
			if txErr != nil {
				return txErr
			}
			ticket = &created
		}
		return nil
	})
	if err != nil {
		return Purchase{}, courses.Enrollment{}, nil, err
	}
	return purchase, enrollment, ticket, nil
}

// PurchaseCourse implements courses.MentorTicketOpener. It returns the
// concrete Purchase/Enrollment/*Ticket boxed as `any` because the courses
// package cannot import mentoring's concrete types without creating an
// import cycle (mentoring already imports courses for
// Enrollment/CreateEnrollmentTx) — see the MentorTicketOpener interface
// defined in courses/handler.go.
func (s *Service) PurchaseCourse(ctx context.Context, orgID, userID, courseID string, amountCents int) (any, any, any, error) {
	purchase, enrollment, ticket, err := s.purchaseCourse(ctx, orgID, userID, courseID, amountCents)
	if err != nil {
		return nil, nil, nil, err
	}
	return purchase, enrollment, ticket, nil
}

// RequestMentor lets a student who does not currently have an active mentor
// ticket open one for a course they are enrolled in. This is the
// student-initiated counterpart to the auto-opened ticket in purchaseCourse
// — it covers free courses and any other case where no ticket was opened
// automatically. Returns ErrInvalid if the student isn't enrolled in
// courseID, ErrAlreadyHasMentor if they already have an open or assigned
// ticket anywhere in the org (mirrors purchaseCourse's HasActiveMentor dedup).
func (s *Service) RequestMentor(ctx context.Context, orgID, userID, courseID string) (Ticket, error) {
	enrolled, err := s.coursesRepo.IsEnrolled(ctx, userID, courseID)
	if err != nil {
		return Ticket{}, fmt.Errorf("mentoring: request mentor: check enrollment: %w", err)
	}
	if !enrolled {
		return Ticket{}, fmt.Errorf("%w: you must be enrolled in this course to request a mentor", ErrInvalid)
	}

	var ticket Ticket
	err = s.repo.tx(ctx, func(tx pgx.Tx) error {
		hasMentor, txErr := s.repo.HasActiveMentor(ctx, tx, orgID, userID)
		if txErr != nil {
			return txErr
		}
		if hasMentor {
			return ErrAlreadyHasMentor
		}
		created, txErr := s.repo.CreateTicket(ctx, tx, Ticket{
			OrgID:     orgID,
			StudentID: userID,
			CourseID:  courseID,
		})
		if txErr != nil {
			return txErr
		}
		ticket = created
		return nil
	})
	if err != nil {
		return Ticket{}, err
	}
	return ticket, nil
}

// ClaimTicket lets a mentor self-assign an open ticket within orgID.
func (s *Service) ClaimTicket(ctx context.Context, orgID, ticketID, mentorID string) (Ticket, error) {
	return s.repo.ClaimTicket(ctx, orgID, ticketID, mentorID)
}

// AssignTicket lets a staff member hand-assign a mentor to an open ticket
// within orgID. Validates that mentorID actually holds the mentor role in
// this org before assigning — otherwise a staff member could hand a ticket
// to an arbitrary user ID.
func (s *Service) AssignTicket(ctx context.Context, orgID, ticketID, mentorID, assignedBy string) (Ticket, error) {
	isMentor, err := s.repo.IsMentor(ctx, orgID, mentorID)
	if err != nil {
		return Ticket{}, err
	}
	if !isMentor {
		return Ticket{}, fmt.Errorf("%w: mentor_id must be a mentor in this organization", ErrInvalid)
	}
	return s.repo.AssignTicket(ctx, orgID, ticketID, mentorID, assignedBy)
}

// CloseTicket closes a ticket within orgID. Callers must already have
// verified the caller is either the assigned mentor or holds
// mentoring.assign_tickets.
func (s *Service) CloseTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	return s.repo.CloseTicket(ctx, orgID, ticketID)
}

// GetTicket returns a single ticket by ID, scoped to orgID.
func (s *Service) GetTicket(ctx context.Context, orgID, ticketID string) (Ticket, error) {
	return s.repo.GetTicket(ctx, orgID, ticketID)
}

// ListTickets returns tickets for orgID, optionally filtered by status
// and/or assigned mentor (a mentor's own queue).
func (s *Service) ListTickets(ctx context.Context, orgID string, status, mentorID *string) ([]Ticket, error) {
	return s.repo.ListTickets(ctx, orgID, status, mentorID, nil)
}

// ListMyTickets returns every ticket belonging to studentID within orgID,
// most recent first — the student-facing counterpart to ListTickets.
func (s *Service) ListMyTickets(ctx context.Context, orgID, studentID string) ([]Ticket, error) {
	return s.repo.ListTickets(ctx, orgID, nil, nil, &studentID)
}

// ListMentorDirectory returns every mentor in orgID with a live mentee count
// and aggregated rating.
func (s *Service) ListMentorDirectory(ctx context.Context, orgID string) ([]MentorDirectoryEntry, error) {
	return s.repo.ListMentorDirectory(ctx, orgID)
}

// SendChatMessage posts a message on ticketID's 1:1 chat thread. Only the
// ticket's student or its currently assigned mentor may post, and only
// while the ticket is 'assigned' (there's no one to talk to on an open or
// closed ticket).
func (s *Service) SendChatMessage(ctx context.Context, orgID, ticketID, senderID, body string) (ChatMessage, error) {
	if len(body) < 1 || len(body) > 4000 {
		return ChatMessage{}, fmt.Errorf("%w: message must be between 1 and 4000 characters", ErrInvalid)
	}
	ticket, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return ChatMessage{}, err
	}
	if ticket.Status != TicketStatusAssigned || ticket.AssignedMentorID == nil {
		return ChatMessage{}, fmt.Errorf("%w: this ticket has no active mentor to chat with", ErrInvalid)
	}
	if senderID != ticket.StudentID && senderID != *ticket.AssignedMentorID {
		return ChatMessage{}, ErrForbidden
	}
	return s.repo.CreateChatMessage(ctx, orgID, ticketID, senderID, body)
}

// ListChatMessages returns the full chat thread for ticketID. Only the
// ticket's student or its currently assigned mentor may read it.
func (s *Service) ListChatMessages(ctx context.Context, orgID, ticketID, callerID string) ([]ChatMessage, error) {
	ticket, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return nil, err
	}
	isMentor := ticket.AssignedMentorID != nil && *ticket.AssignedMentorID == callerID
	if callerID != ticket.StudentID && !isMentor {
		return nil, ErrForbidden
	}
	return s.repo.ListChatMessages(ctx, orgID, ticketID)
}

// GetTicketHistory returns a ticket plus its full mentor-assignment history.
// Only the ticket's student or its currently assigned mentor may view it —
// same access rule as ListChatMessages.
func (s *Service) GetTicketHistory(ctx context.Context, orgID, ticketID, callerID string) (Ticket, []TicketAssignment, error) {
	ticket, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return Ticket{}, nil, err
	}
	isMentor := ticket.AssignedMentorID != nil && *ticket.AssignedMentorID == callerID
	if callerID != ticket.StudentID && !isMentor {
		return Ticket{}, nil, ErrForbidden
	}
	assignments, err := s.repo.ListTicketAssignments(ctx, ticketID)
	if err != nil {
		return Ticket{}, nil, err
	}
	return ticket, assignments, nil
}

// GetTicketDetail returns the full staff-facing lifecycle for ticketID:
// the ticket, its assignment history, and every change request filed
// against it. Reports are included only when canViewReports is true — the
// handler decides that via authzSvc.HasPermission before calling in, since
// Service has no access to the authz package's permission check.
func (s *Service) GetTicketDetail(ctx context.Context, orgID, ticketID string, canViewReports bool) (TicketDetail, error) {
	ticket, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return TicketDetail{}, err
	}
	assignments, err := s.repo.ListTicketAssignments(ctx, ticketID)
	if err != nil {
		return TicketDetail{}, err
	}
	changeRequests, err := s.repo.ListChangeRequestsByTicket(ctx, ticketID)
	if err != nil {
		return TicketDetail{}, err
	}
	detail := TicketDetail{Ticket: ticket, Assignments: assignments, ChangeRequests: changeRequests}
	if canViewReports {
		reports, err := s.repo.ListReportsByTicket(ctx, ticketID)
		if err != nil {
			return TicketDetail{}, err
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
	ticket, err := s.repo.GetTicket(ctx, orgID, ticketID)
	if err != nil {
		return ChangeRequest{}, err
	}
	if ticket.StudentID != studentID {
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
func (s *Service) ApproveChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, Ticket, error) {
	return s.repo.ApproveChangeRequest(ctx, orgID, requestID, reviewedBy, note)
}

// DenyChangeRequest denies a pending change request; the ticket is untouched.
func (s *Service) DenyChangeRequest(ctx context.Context, orgID, requestID, reviewedBy, note string) (ChangeRequest, error) {
	return s.repo.DenyChangeRequest(ctx, orgID, requestID, reviewedBy, note)
}

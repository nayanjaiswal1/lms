// Package mentoring owns the per-student mentor-assignment workflow:
// mentor_tickets (opened automatically on a paid course purchase, claimed by
// mentors or hand-assigned by staff) and mentor_reports (a moderation
// complaint workflow, distinct from the star-rating stored generically in
// the feedback package). It deliberately does not touch batches
// (backend/internal/assessment) — batches are cohort containers, tickets are
// individual 1:1 assignment records.
package mentoring

import "time"

// Purchase provider identifiers — mirrors the course_purchases.provider CHECK
// constraint in backend/db/migrations/018_payments_stub.sql.
const (
	ProviderStub     = "stub"
	ProviderStripe   = "stripe"
	ProviderRazorpay = "razorpay"
)

// Purchase status values — mirrors course_purchases.status.
const (
	PurchaseStatusPending   = "pending"
	PurchaseStatusCompleted = "completed"
	PurchaseStatusFailed    = "failed"
	PurchaseStatusRefunded  = "refunded"
)

// Ticket status values — mirrors mentor_tickets.status
// (backend/db/migrations/019_mentor_tickets.sql).
const (
	TicketStatusOpen     = "open"
	TicketStatusAssigned = "assigned"
	TicketStatusClosed   = "closed"
)

// Report reason values — mirrors mentor_reports.reason
// (backend/db/migrations/020_mentor_reports.sql).
const (
	ReportReasonUnresponsive          = "unresponsive"
	ReportReasonInappropriateBehavior = "inappropriate_behavior"
	ReportReasonUnqualified           = "unqualified"
	ReportReasonOther                 = "other"
)

// Report status values — mirrors mentor_reports.status.
const (
	ReportStatusOpen      = "open"
	ReportStatusReviewing = "reviewing"
	ReportStatusResolved  = "resolved"
	ReportStatusDismissed = "dismissed"
)

var validReportReasons = map[string]struct{}{
	ReportReasonUnresponsive:          {},
	ReportReasonInappropriateBehavior: {},
	ReportReasonUnqualified:           {},
	ReportReasonOther:                 {},
}

// IsValidReportReason reports whether reason is one of the whitelisted
// mentor_reports.reason CHECK values.
func IsValidReportReason(reason string) bool {
	_, ok := validReportReasons[reason]
	return ok
}

var validReportResolutions = map[string]struct{}{
	ReportStatusResolved:  {},
	ReportStatusDismissed: {},
}

// IsValidReportResolution reports whether status is a valid terminal value a
// staff member may resolve a report to.
func IsValidReportResolution(status string) bool {
	_, ok := validReportResolutions[status]
	return ok
}

// Purchase is a single course purchase attempt, recorded via a
// payments.Provider. Matches course_purchases (018_payments_stub.sql,
// coupon/webhook columns added in 004_payments_coupons.sql). A row is
// created 'pending' at checkout-start and only ever transitions to
// 'completed' or 'failed' via a confirmed webhook (see
// service_purchase.go) — it is never marked complete synchronously.
type Purchase struct {
	ID            string    `json:"id"`
	OrgID         string    `json:"org_id"`
	UserID        string    `json:"user_id"`
	CourseID      string    `json:"course_id"`
	AmountCents   int       `json:"amount_cents"`
	DiscountCents int       `json:"discount_cents"`
	Currency      string    `json:"currency"`
	Provider      string    `json:"provider"`
	ProviderRef   string    `json:"provider_ref"`
	PaymentRef    *string   `json:"payment_ref"`
	CouponID      *string   `json:"coupon_id"`
	Status        string    `json:"status"`
	PurchasedAt   time.Time `json:"purchased_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// Ticket is a per-student "needs a mentor" record. Matches mentor_tickets
// (019_mentor_tickets.sql, escalation_level added in 023_mentor_ticket_escalation.sql).
type Ticket struct {
	ID               string     `json:"id"`
	OrgID            string     `json:"org_id"`
	StudentID        string     `json:"student_id"`
	CourseID         string     `json:"course_id"`
	PurchaseID       *string    `json:"purchase_id"`
	Status           string     `json:"status"`
	AssignedMentorID *string    `json:"assigned_mentor_id"`
	AssignedBy       *string    `json:"assigned_by"`
	AssignedAt       *time.Time `json:"assigned_at"`
	ClosedAt         *time.Time `json:"closed_at"`
	EscalationLevel  int        `json:"escalation_level"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

// TicketAssignment is a durable row from mentor_ticket_assignments — one per
// mentor ever assigned to a ticket, so reassignment history survives even
// after mentor_tickets.assigned_mentor_id moves on to someone else.
type TicketAssignment struct {
	ID         string    `json:"id"`
	TicketID   string    `json:"ticket_id"`
	MentorID   string    `json:"mentor_id"`
	AssignedAt time.Time `json:"assigned_at"`
}

// Report is a student's complaint about a mentor. Matches mentor_reports
// (020_mentor_reports.sql).
type Report struct {
	ID             string     `json:"id"`
	OrgID          string     `json:"org_id"`
	MentorID       string     `json:"mentor_id"`
	ReporterID     string     `json:"reporter_id"`
	TicketID       *string    `json:"ticket_id"`
	Reason         string     `json:"reason"`
	Description    string     `json:"description"`
	Status         string     `json:"status"`
	ResolvedBy     *string    `json:"resolved_by"`
	ResolutionNote *string    `json:"resolution_note"`
	ResolvedAt     *time.Time `json:"resolved_at"`
	CreatedAt      time.Time  `json:"created_at"`
}

// Change-request status values — mirrors mentor_change_requests.status
// (024_mentor_change_requests.sql).
const (
	ChangeRequestStatusPending  = "pending"
	ChangeRequestStatusApproved = "approved"
	ChangeRequestStatusDenied   = "denied"
)

var validChangeRequestResolutions = map[string]struct{}{
	ChangeRequestStatusApproved: {},
	ChangeRequestStatusDenied:   {},
}

// IsValidChangeRequestResolution reports whether status is a valid terminal
// value staff may resolve a change request to.
func IsValidChangeRequestResolution(status string) bool {
	_, ok := validChangeRequestResolutions[status]
	return ok
}

// ChangeRequest is a student's request to be reassigned a different mentor.
// Matches mentor_change_requests (024_mentor_change_requests.sql).
type ChangeRequest struct {
	ID         string     `json:"id"`
	OrgID      string     `json:"org_id"`
	TicketID   string     `json:"ticket_id"`
	StudentID  string     `json:"student_id"`
	Reason     string     `json:"reason"`
	Status     string     `json:"status"`
	ReviewedBy *string    `json:"reviewed_by"`
	ReviewNote *string    `json:"review_note"`
	ReviewedAt *time.Time `json:"reviewed_at"`
	CreatedAt  time.Time  `json:"created_at"`
}

// ChatMessage is a single 1:1 message on a mentor ticket's chat thread.
// Matches mentor_chat_messages (026_mentor_chat_messages.sql).
type ChatMessage struct {
	ID        string    `json:"id"`
	OrgID     string    `json:"org_id"`
	TicketID  string    `json:"ticket_id"`
	SenderID  string    `json:"sender_id"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"created_at"`
}

// TicketDetail is the full staff-facing lifecycle view of a ticket —
// assignments, change requests, and (for callers holding
// mentoring.manage_reports) complaint reports — the single aggregate the
// ticket detail page renders instead of piecing history together from
// separate list endpoints. Reports is nil (omitted from the JSON response)
// for callers who lack that permission; the frontend independently gates
// its Reports section on the same permission, so the omission and the UI
// gate agree without the caller needing an explicit "can view reports" flag.
type TicketDetail struct {
	Ticket         Ticket             `json:"ticket"`
	Assignments    []TicketAssignment `json:"assignments"`
	ChangeRequests []ChangeRequest    `json:"change_requests"`
	Reports        []Report           `json:"reports,omitempty"`
}

// MentorDirectoryEntry is one row of the org-wide mentor directory: a
// mentor's live assigned-mentee count and aggregated rating pulled from the
// generic feedback table (subject_type = 'mentor'), plus the bio/title a
// mentor set on their own user_profiles row (org members viewing a mentor's
// profile are trusted context, so this is shown regardless of that row's
// public_enabled flag — public_enabled only gates the external /u/{slug} page).
type MentorDirectoryEntry struct {
	UserID            string    `json:"user_id"`
	Name              string    `json:"name"`
	Email             string    `json:"email"`
	AvatarURL         *string   `json:"avatar_url"`
	MenteeCount       int       `json:"mentee_count"`
	AvgRating         *float64  `json:"avg_rating"`
	RatingCount       int       `json:"rating_count"`
	Bio               *string   `json:"bio"`
	CurrentRole       *string   `json:"current_role"`
	YearsOfExperience *int16    `json:"years_of_experience"`
	Skills            []string  `json:"skills"`
	JoinedAt          time.Time `json:"joined_at"`
}

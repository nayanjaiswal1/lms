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

// MentorProfile is the single-mentor superset of MentorDirectoryEntry shown
// on a mentor's profile page: the same live directory fields plus the
// verified-expert flag (a stored admin attestation, see 006_mentor_verification.sql)
// and three additional live-computed stats. These are deliberately not added
// to MentorDirectoryEntry/ListMentorDirectory — that query backs the mentor
// list page and is called once per mentor shown there, so it stays cheap;
// the extra aggregates here only run for the one mentor a profile page loads.
//
// AvgResponseMinutes is the mean, across this mentor's tickets, of (first
// mentor message timestamp - first student message timestamp) for tickets
// where both exist — a "time to first reply" proxy, not full per-message
// response analytics. Nil if the mentor has no ticket with both a student
// and a mentor message yet.
//
// TotalMentorshipHours sums ends_at-starts_at over this mentor's past,
// non-cancelled calendar_events of type 'mentor_session'. There is no
// "session actually happened" signal in the calendar domain (status only
// distinguishes scheduled/cancelled), so "in the past and not cancelled" is
// the completion proxy.
//
// PercentileRank is this mentor's PERCENT_RANK() among the org's mentors
// with at least one rating or session in the current calendar month, or nil
// if the mentor isn't part of that active set — the UI omits the ranking
// line entirely rather than showing a meaningless 0.
type MentorProfile struct {
	UserID               string     `json:"user_id"`
	Name                 string     `json:"name"`
	Email                string     `json:"email"`
	AvatarURL            *string    `json:"avatar_url"`
	MenteeCount          int        `json:"mentee_count"`
	AvgRating            *float64   `json:"avg_rating"`
	RatingCount          int        `json:"rating_count"`
	Bio                  *string    `json:"bio"`
	CurrentRole          *string    `json:"current_role"`
	YearsOfExperience    *int16     `json:"years_of_experience"`
	Skills               []string   `json:"skills"`
	JoinedAt             time.Time  `json:"joined_at"`
	Verified             bool       `json:"verified"`
	VerifiedAt           *time.Time `json:"verified_at"`
	AvgResponseMinutes   *float64   `json:"avg_response_minutes"`
	TotalMentorshipHours *float64   `json:"total_mentorship_hours"`
	PercentileRank       *float64   `json:"percentile_rank"`
	LastActiveAt         *time.Time `json:"last_active_at"`
	LinkedIn             *string    `json:"linkedin"`
	GitHub               *string    `json:"github"`
	Portfolio            *string    `json:"portfolio"`
}

// MentorConversation is a ticket-independent 1:1 DM thread between a student
// and a mentor. Matches mentor_conversations (007_mentor_conversations.sql).
type MentorConversation struct {
	ID        string    `json:"id"`
	OrgID     string    `json:"org_id"`
	StudentID string    `json:"student_id"`
	MentorID  string    `json:"mentor_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// DirectMessage is a single message on a MentorConversation's thread.
// Matches mentor_direct_messages (007_mentor_conversations.sql). Kept
// distinct from ChatMessage rather than shared — the two tables differ
// structurally (conversation_id vs ticket_id) and have independent access
// rules, so a shared type would just be a coincidence of shape, not a real
// abstraction.
type DirectMessage struct {
	ID             string    `json:"id"`
	OrgID          string    `json:"org_id"`
	ConversationID string    `json:"conversation_id"`
	SenderID       string    `json:"sender_id"`
	Body           string    `json:"body"`
	CreatedAt      time.Time `json:"created_at"`
}

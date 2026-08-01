// Package sessions owns mentor session booking: a mentor's published
// availability, the bookable slots that expand from it, the credit balance a
// student spends to book one, and the session record itself through
// completion, cancellation, feedback, and the mentor's private notes.
//
// A booked session is projected onto the org calendar as a real
// calendar_events row (event_type='mentor_session') created through
// calendar.Service, which is what puts it on both parties' calendars and in
// the personal ICS feed for free. mentor_sessions.calendar_event_id is that
// link; this package owns the booking, calendar owns the projection.
package sessions

import "time"

// Session status values — mirrors mentor_sessions.status
// (013_mentor_session_booking.sql).
const (
	StatusScheduled = "scheduled"
	StatusCompleted = "completed"
	StatusCancelled = "cancelled"
	StatusNoShow    = "no_show"
)

// Ledger reason values — mirrors session_credit_ledger.reason.
const (
	ReasonPurchase           = "purchase"
	ReasonAdminGrant         = "admin_grant"
	ReasonAdminRevoke        = "admin_revoke"
	ReasonBooking            = "booking"
	ReasonCancellationRefund = "cancellation_refund"
)

// Feedback author roles — mirrors mentor_session_feedback.author_role.
const (
	RoleStudent = "student"
	RoleMentor  = "mentor"
)

// Purchase status values — mirrors session_pack_purchases.status. Same set
// course_purchases uses, since both ride the same payments.Provider seam.
const (
	PurchaseStatusPending   = "pending"
	PurchaseStatusCompleted = "completed"
	PurchaseStatusFailed    = "failed"
)

// PermissionManageBooking gates the org-admin surface of this package:
// editing the booking policy, creating credit packs, granting credits, and
// scheduling a whole-batch session. Seeded in 013_mentor_session_booking.sql
// via the same authz catalogue every other permission code lives in.
const PermissionManageBooking = "mentoring.manage_session_booking"

// FeatureKey is the features-package key this domain is gated by. Its org
// toggle is backed by org_session_booking_config.enabled.
const FeatureKey = "session_booking"

// Config is one org_session_booking_config row — the org's booking policy.
// A missing row resolves to DefaultConfig(), matching the column defaults.
type Config struct {
	OrgID                 string    `json:"org_id"`
	Enabled               bool      `json:"enabled"`
	RequireCredits        bool      `json:"require_credits"`
	CancelCutoffHours     int       `json:"cancel_cutoff_hours"`
	MinNoticeHours        int       `json:"min_notice_hours"`
	BookingHorizonDays    int       `json:"booking_horizon_days"`
	MaxUpcomingPerStudent int       `json:"max_upcoming_per_student"`
	DefaultDuration       int       `json:"default_duration_minutes"`
	UpdatedAt             time.Time `json:"updated_at"`
}

// DefaultConfig mirrors the column defaults in org_session_booking_config.
// Kept in sync by hand deliberately: the alternative (a SELECT against a
// seeded row) would make every org's first booking request depend on a row
// nobody has created yet.
func DefaultConfig(orgID string) Config {
	return Config{
		OrgID:                 orgID,
		Enabled:               true,
		RequireCredits:        false,
		CancelCutoffHours:     12,
		MinNoticeHours:        2,
		BookingHorizonDays:    60,
		MaxUpcomingPerStudent: 3,
		DefaultDuration:       30,
	}
}

// AvailabilityRule is one mentor_availability_rules row: a weekly recurring
// window in the mentor's own timezone. See the migration for why the zone is
// stored rather than normalizing to UTC.
type AvailabilityRule struct {
	ID          string    `json:"id"`
	OrgID       string    `json:"org_id"`
	MentorID    string    `json:"mentor_id"`
	Weekday     int       `json:"weekday"`
	StartMinute int       `json:"start_minute"`
	EndMinute   int       `json:"end_minute"`
	SlotMinutes int       `json:"slot_minutes"`
	Timezone    string    `json:"timezone"`
	Active      bool      `json:"active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// AvailabilityException is one mentor_availability_exceptions row: a one-off
// block (a holiday) or an extra window opened outside the weekly pattern.
// StartMinute/EndMinute nil means the whole day, which only a block may be.
type AvailabilityException struct {
	ID          string    `json:"id"`
	OrgID       string    `json:"org_id"`
	MentorID    string    `json:"mentor_id"`
	OnDate      string    `json:"on_date"` // YYYY-MM-DD, in Timezone
	StartMinute *int      `json:"start_minute"`
	EndMinute   *int      `json:"end_minute"`
	IsBlocked   bool      `json:"is_blocked"`
	SlotMinutes int       `json:"slot_minutes"`
	Timezone    string    `json:"timezone"`
	Note        *string   `json:"note"`
	CreatedAt   time.Time `json:"created_at"`
}

// Slot is one bookable (or already-taken) window on a mentor's calendar,
// computed on read from the rules + exceptions + existing sessions. Never
// persisted — a slot only becomes a row when someone books it.
//
// Taken slots are returned rather than filtered out on purpose: the booking
// UI shows a mentor's day as a grid of free and busy times, and a grid with
// the busy ones silently missing reads as "the mentor doesn't work then".
type Slot struct {
	StartsAt time.Time `json:"starts_at"`
	EndsAt   time.Time `json:"ends_at"`
	Taken    bool      `json:"taken"`
}

// Session is one mentor_sessions row. Exactly one of StudentID (a 1:1
// booking) or BatchID (a whole-cohort session) is set.
type Session struct {
	ID              string     `json:"id"`
	OrgID           string     `json:"org_id"`
	MentorID        string     `json:"mentor_id"`
	StudentID       *string    `json:"student_id"`
	BatchID         *string    `json:"batch_id"`
	Title           string     `json:"title"`
	Agenda          *string    `json:"agenda"`
	StartsAt        time.Time  `json:"starts_at"`
	EndsAt          time.Time  `json:"ends_at"`
	Status          string     `json:"status"`
	BookedBy        string     `json:"booked_by"`
	MeetingURL      *string    `json:"meeting_url"`
	CalendarEventID *string    `json:"calendar_event_id"`
	CancelledBy     *string    `json:"cancelled_by"`
	CancelledAt     *time.Time `json:"cancelled_at"`
	CancelReason    *string    `json:"cancel_reason"`
	CompletedAt     *time.Time `json:"completed_at"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`

	// Display fields joined on read — never columns on mentor_sessions.
	MentorName  *string `json:"mentor_name,omitempty"`
	StudentName *string `json:"student_name,omitempty"`
	BatchName   *string `json:"batch_name,omitempty"`
}

// Feedback is one mentor_session_feedback row.
type Feedback struct {
	ID         string    `json:"id"`
	SessionID  string    `json:"session_id"`
	AuthorID   string    `json:"author_id"`
	AuthorRole string    `json:"author_role"`
	Rating     int       `json:"rating"`
	Comment    *string   `json:"comment"`
	AuthorName *string   `json:"author_name,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// Notes is one mentor_session_notes row — the mentor's write-up of what
// happened. Private unless VisibleToStudent is explicitly set.
type Notes struct {
	SessionID        string    `json:"session_id"`
	MentorID         string    `json:"mentor_id"`
	Body             string    `json:"body"`
	VisibleToStudent bool      `json:"visible_to_student"`
	UpdatedAt        time.Time `json:"updated_at"`
}

// CreditPack is one session_credit_packs row — what an org sells.
type CreditPack struct {
	ID          string    `json:"id"`
	OrgID       string    `json:"org_id"`
	Name        string    `json:"name"`
	Description *string   `json:"description"`
	Sessions    int       `json:"sessions"`
	PriceCents  int       `json:"price_cents"`
	Currency    string    `json:"currency"`
	Active      bool      `json:"active"`
	CreatedAt   time.Time `json:"created_at"`
}

// LedgerEntry is one session_credit_ledger row.
type LedgerEntry struct {
	ID        string    `json:"id"`
	Delta     int       `json:"delta"`
	Reason    string    `json:"reason"`
	SessionID *string   `json:"session_id"`
	Note      *string   `json:"note"`
	CreatedAt time.Time `json:"created_at"`
}

// PackPurchase is one session_pack_purchases row.
type PackPurchase struct {
	ID          string `json:"id"`
	OrgID       string `json:"org_id"`
	UserID      string `json:"user_id"`
	PackID      string `json:"pack_id"`
	Sessions    int    `json:"sessions"`
	AmountCents int    `json:"amount_cents"`
	Currency    string `json:"currency"`
	Provider    string `json:"provider"`
	ProviderRef string `json:"provider_ref"`
	Status      string `json:"status"`
}

// MenteeProgress is the mentor-facing rollup for one mentee: every session
// they have had with this mentor plus the aggregate the mentor needs before
// walking into the next one.
type MenteeProgress struct {
	StudentID       string     `json:"student_id"`
	StudentName     *string    `json:"student_name"`
	TotalSessions   int        `json:"total_sessions"`
	CompletedCount  int        `json:"completed_count"`
	CancelledCount  int        `json:"cancelled_count"`
	NoShowCount     int        `json:"no_show_count"`
	FirstSessionAt  *time.Time `json:"first_session_at"`
	LastSessionAt   *time.Time `json:"last_session_at"`
	AvgRatingGiven  *float64   `json:"avg_rating_given"`
	UpcomingSession *Session   `json:"upcoming_session"`
	Sessions        []Session  `json:"sessions"`
}

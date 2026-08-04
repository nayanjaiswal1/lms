// Package support owns the general-purpose helpdesk: any org member (student,
// mentor, instructor, admin) can raise a support ticket about anything —
// billing, a technical bug, their account, course content — with a durable
// reply thread, independent of the mentoring package's mentor_tickets (a
// per-student "needs a mentor for this course" match record with no
// subject/category, scoped to a course enrollment). See
// backend/db/migrations/021_support_tickets.sql.
package support

import "time"

// Category values — mirrors support_tickets.category
// (021_support_tickets.sql).
const (
	CategoryTechnical     = "technical"
	CategoryBilling       = "billing"
	CategoryAccount       = "account"
	CategoryCourseContent = "course_content"
	CategoryOther         = "other"
)

var validCategories = map[string]struct{}{
	CategoryTechnical:     {},
	CategoryBilling:       {},
	CategoryAccount:       {},
	CategoryCourseContent: {},
	CategoryOther:         {},
}

// IsValidCategory reports whether category is one of the whitelisted
// support_tickets.category CHECK values.
func IsValidCategory(category string) bool {
	_, ok := validCategories[category]
	return ok
}

// Priority values — mirrors support_tickets.priority.
const (
	PriorityLow    = "low"
	PriorityNormal = "normal"
	PriorityHigh   = "high"
)

var validPriorities = map[string]struct{}{
	PriorityLow:    {},
	PriorityNormal: {},
	PriorityHigh:   {},
}

// IsValidPriority reports whether priority is one of the whitelisted
// support_tickets.priority CHECK values.
func IsValidPriority(priority string) bool {
	_, ok := validPriorities[priority]
	return ok
}

// Status values — mirrors support_tickets.status.
const (
	StatusOpen       = "open"
	StatusInProgress = "in_progress"
	StatusResolved   = "resolved"
	StatusClosed     = "closed"
)

var validStatuses = map[string]struct{}{
	StatusOpen:       {},
	StatusInProgress: {},
	StatusResolved:   {},
	StatusClosed:     {},
}

// IsValidStatus reports whether status is one of the whitelisted
// support_tickets.status CHECK values.
func IsValidStatus(status string) bool {
	_, ok := validStatuses[status]
	return ok
}

// Ticket is a single support request. Matches support_tickets
// (021_support_tickets.sql).
type Ticket struct {
	ID         string     `json:"id"`
	OrgID      string     `json:"org_id"`
	UserID     string     `json:"user_id"`
	Subject    string     `json:"subject"`
	Category   string     `json:"category"`
	Priority   string     `json:"priority"`
	Status     string     `json:"status"`
	AssignedTo *string    `json:"assigned_to"`
	ResolvedAt *time.Time `json:"resolved_at"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

// Message is a single reply on a ticket's thread. Matches
// support_ticket_messages (021_support_tickets.sql).
type Message struct {
	ID        string    `json:"id"`
	OrgID     string    `json:"org_id"`
	TicketID  string    `json:"ticket_id"`
	SenderID  string    `json:"sender_id"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"created_at"`
}

// TicketDetail is a ticket plus its full reply thread — the shape returned by
// GetTicket, so a caller opening a ticket gets both in one round trip instead
// of a second request to ListMessages.
type TicketDetail struct {
	Ticket
	Messages []Message `json:"messages"`
}

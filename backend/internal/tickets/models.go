// Package tickets owns the shared "someone raises a request, staff or the
// assigned party replies until it's resolved" core used by two different
// audiences: general support tickets (kind=support, any org member, staff
// triage via category/priority) and mentor-assignment tickets (kind=
// mentorship, opened on course purchase or by request, claimed/hand-assigned
// to a mentor). Both live in the shared conversations/messages tables
// (backend/db/migrations/001_baseline.sql) via the kind/thread_type
// discriminator — this package is the only place that talks to those tables
// for ticket purposes. Kind-specific lifecycle (claim, hand-assign,
// escalation, change-requests, mentor reports, certificates) stays in
// internal/mentoring, built on top of this package's CRUD.
package tickets

import "time"

// Kind values — the conversations.kind discriminator this package accepts.
// 'direct' (ticket-independent mentor DMs) is intentionally excluded: it's
// owned entirely by internal/mentoring and must never be reachable through
// this package's ticket CRUD.
const (
	KindSupport    = "support"
	KindMentorship = "mentorship"
)

// Status values. InProgress/Resolved are support-only; Assigned is
// mentorship-only; Open/Closed are shared.
const (
	StatusOpen       = "open"
	StatusInProgress = "in_progress"
	StatusAssigned   = "assigned"
	StatusResolved   = "resolved"
	StatusClosed     = "closed"
)

var validStatus = map[string]map[string]bool{
	KindSupport: {
		StatusOpen: true, StatusInProgress: true, StatusResolved: true, StatusClosed: true,
	},
	KindMentorship: {
		StatusOpen: true, StatusAssigned: true, StatusClosed: true,
	},
}

// IsValidStatus reports whether status is a whitelisted value for kind.
// conversations has no CHECK constraint on status, so this is the only guard.
func IsValidStatus(kind, status string) bool {
	return validStatus[kind][status]
}

// Category values — support tickets only, mirrors the category CHECK a prior
// dedicated support_tickets table used to enforce.
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

// IsValidCategory reports whether category is one of the whitelisted values.
func IsValidCategory(category string) bool {
	_, ok := validCategories[category]
	return ok
}

// Priority values — support tickets only.
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

// IsValidPriority reports whether priority is one of the whitelisted values.
func IsValidPriority(priority string) bool {
	_, ok := validPriorities[priority]
	return ok
}

// threadType maps a ticket kind to its messages.thread_type value
// (CHECK-constrained to mentor_ticket|mentor_conversation|support_ticket —
// mentor_conversation is the ticket-independent DM thread type, owned by
// internal/mentoring, never used here).
var threadType = map[string]string{
	KindSupport:    "support_ticket",
	KindMentorship: "mentor_ticket",
}

// ManagePermission is the staff permission gating a kind's status/category/
// priority writes and closing another party's ticket.
var ManagePermission = map[string]string{
	KindSupport:    "support.manage",
	KindMentorship: "mentoring.assign_tickets",
}

// QueuePermission is the (broader) permission to see a kind's full queue —
// for support this is the same permission as ManagePermission; mentorship
// splits the two so mentor/instructor/admin can see the queue without also
// being able to hand-assign.
var QueuePermission = map[string]string{
	KindSupport:    "support.manage",
	KindMentorship: "mentoring.view_tickets",
}

// Ticket is a single request, either kind. Fields meaningful to only one
// kind are pointers: Subject/Category/Priority are support-only, CourseID/
// PurchaseID/EscalationLevel are mentorship-only.
type Ticket struct {
	ID              string     `json:"id"`
	OrgID           string     `json:"org_id"`
	Kind            string     `json:"kind"`
	RequesterID     string     `json:"requester_id"`
	CourseID        *string    `json:"course_id"`
	PurchaseID      *string    `json:"purchase_id"`
	Subject         *string    `json:"subject"`
	Category        *string    `json:"category"`
	Priority        *string    `json:"priority"`
	Status          string     `json:"status"`
	AssignedTo      *string    `json:"assigned_to"`
	EscalationLevel int        `json:"escalation_level"`
	ResolvedAt      *time.Time `json:"resolved_at"`
	ClosedAt        *time.Time `json:"closed_at"`
	CreatedAt       time.Time  `json:"created_at"`
}

// Message is a single reply on a ticket's thread.
type Message struct {
	ID        string    `json:"id"`
	OrgID     string    `json:"org_id"`
	TicketID  string    `json:"ticket_id"`
	SenderID  string    `json:"sender_id"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"created_at"`
}

// TicketDetail is a ticket plus its full reply thread — the shape Get
// returns, so a caller opening a ticket gets both in one round trip instead
// of a second request to ListMessages.
type TicketDetail struct {
	Ticket
	Messages []Message `json:"messages"`
}

// Filter scopes List (the staff queue). Kind is required — never empty —
// the one thing that keeps 'direct' DM threads out of every ticket query.
type Filter struct {
	Kind        string
	Status      *string
	RequesterID *string
	AssignedTo  *string
}

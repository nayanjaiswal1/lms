// Package calendar owns the org calendar: real calendar_events rows (mentor
// sessions, live classes, deadlines, custom entries) plus a read-only,
// non-persisted view of assessments, batches, courses, and course_modules
// (lessons) that have a starts_at/ends_at window — merged into one feed by
// Repo.ListRange. See Event.IsVirtual.
package calendar

import "time"

// Event type values — mirrors calendar_events.event_type CHECK constraint
// (backend/db/migrations/031_calendar.sql). EventTypeAssessment, EventTypeBatch,
// EventTypeCourse, and EventTypeLesson are pseudo types used only on virtual
// (IsVirtual=true) Event values synthesized by Repo.ListRange from the
// assessments/batches/courses/course_modules tables — never written to
// calendar_events and absent from that column's CHECK constraint.
const (
	EventTypeMentorSession = "mentor_session"
	EventTypeLiveClass     = "live_class"
	EventTypeDeadline      = "deadline"
	EventTypeCustom        = "custom"
	EventTypeTask          = "task"
	EventTypeAssessment    = "assessment"
	EventTypeBatch         = "batch"
	EventTypeCourse        = "course"
	EventTypeLesson        = "lesson"
)

var validEventTypes = map[string]struct{}{
	EventTypeMentorSession: {},
	EventTypeLiveClass:     {},
	EventTypeDeadline:      {},
	EventTypeCustom:        {},
	EventTypeTask:          {},
}

// IsValidEventType reports whether t is one of the whitelisted
// calendar_events.event_type CHECK values a caller may create.
func IsValidEventType(t string) bool {
	_, ok := validEventTypes[t]
	return ok
}

// Attendee role values — mirrors calendar_event_attendees.role.
const (
	AttendeeRoleOwner  = "owner"
	AttendeeRoleEditor = "editor"
	AttendeeRoleViewer = "viewer"
)

var validAttendeeRoles = map[string]struct{}{
	AttendeeRoleOwner:  {},
	AttendeeRoleEditor: {},
	AttendeeRoleViewer: {},
}

// IsValidAttendeeRole reports whether role is a valid calendar_event_attendees.role.
func IsValidAttendeeRole(role string) bool {
	_, ok := validAttendeeRoles[role]
	return ok
}

// External-invite role values — mirrors calendar_event_invites.role, a
// subset of the attendee roles (an external invite can never grant 'owner').
var validInviteRoles = map[string]struct{}{
	AttendeeRoleEditor: {},
	AttendeeRoleViewer: {},
}

// IsValidInviteRole reports whether role is a valid calendar_event_invites.role.
func IsValidInviteRole(role string) bool {
	_, ok := validInviteRoles[role]
	return ok
}

// RSVP status values — mirrors calendar_event_attendees.rsvp_status.
const (
	RSVPPending  = "pending"
	RSVPAccepted = "accepted"
	RSVPDeclined = "declined"
)

var validRSVPStatuses = map[string]struct{}{
	RSVPPending:  {},
	RSVPAccepted: {},
	RSVPDeclined: {},
}

// IsValidRSVPStatus reports whether status is a valid rsvp_status value.
func IsValidRSVPStatus(status string) bool {
	_, ok := validRSVPStatuses[status]
	return ok
}

// Visibility values — mirrors calendar_events.visibility.
const (
	VisibilityPrivate = "private"
	VisibilityShared  = "shared"
	VisibilityPublic  = "public"
)

var validVisibilities = map[string]struct{}{
	VisibilityPrivate: {},
	VisibilityShared:  {},
	VisibilityPublic:  {},
}

// IsValidVisibility reports whether v is a valid calendar_events.visibility value.
func IsValidVisibility(v string) bool {
	_, ok := validVisibilities[v]
	return ok
}

// Priority values — mirrors calendar_events.priority. Meaningful only on
// EventTypeTask rows (mirrors CompletedAt's doc comment), left unenforced
// at the DB layer and validated in normalizeAndValidateEvent instead.
const (
	PriorityLow    = "low"
	PriorityMedium = "medium"
	PriorityHigh   = "high"
	PriorityUrgent = "urgent"
)

var validPriorities = map[string]struct{}{
	PriorityLow:    {},
	PriorityMedium: {},
	PriorityHigh:   {},
	PriorityUrgent: {},
}

// IsValidPriority reports whether p is a valid calendar_events.priority value.
func IsValidPriority(p string) bool {
	_, ok := validPriorities[p]
	return ok
}

// Event status values — mirrors calendar_events.status.
const (
	EventStatusScheduled = "scheduled"
	EventStatusCancelled = "cancelled"
)

var validEventStatuses = map[string]struct{}{
	EventStatusScheduled: {},
	EventStatusCancelled: {},
}

// IsValidEventStatus reports whether status is a valid calendar_events.status value.
func IsValidEventStatus(status string) bool {
	_, ok := validEventStatuses[status]
	return ok
}

// Edit/delete scope values accepted by the ?scope= query param on
// PATCH/DELETE /events/{id}.
const (
	ScopeSingle = "single"
	ScopeSeries = "series"
)

// IsValidScope reports whether scope is "single" or "series".
func IsValidScope(scope string) bool {
	return scope == ScopeSingle || scope == ScopeSeries
}

// Event is a single calendar_events row, or (when IsVirtual is true) a
// read-only assessment window synthesized by Repo.ListRange and never
// persisted to calendar_events. Matches calendar_events (031_calendar.sql).
type Event struct {
	ID                  string      `json:"id"`
	OrgID               string      `json:"org_id"`
	CreatedBy           string      `json:"created_by"`
	EventType           string      `json:"event_type"`
	Title               string      `json:"title"`
	Notes               *string     `json:"notes"`
	MeetingURL          *string     `json:"meeting_url"`
	StartsAt            time.Time   `json:"starts_at"`
	EndsAt              *time.Time  `json:"ends_at"`
	AllDay              bool        `json:"all_day"`
	Visibility          string      `json:"visibility"`
	BatchID             *string     `json:"batch_id"`
	CourseID            *string     `json:"course_id"`
	EntityType          *string     `json:"entity_type"`
	EntityID            *string     `json:"entity_id"`
	RecurrenceRule      *string     `json:"recurrence_rule"`
	RecurrenceParentID  *string     `json:"recurrence_parent_id"`
	ExcludedOccurrences []time.Time `json:"-"`
	Status              string      `json:"status"`
	// CompletedAt is set only on EventTypeTask rows — when non-nil, the task
	// is checked off. Meaningless on every other event type.
	CompletedAt *time.Time `json:"completed_at"`
	// Priority is set only on EventTypeTask rows — drives sort order in the
	// task list view. Meaningless on every other event type.
	Priority  *string   `json:"priority"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// IsVirtual marks a synthesized, read-only entry that has no
	// calendar_events row backing it (currently: an org assessment window).
	// Virtual events cannot be mutated, RSVPed to, or invited to.
	IsVirtual bool `json:"is_virtual"`
}

// Attendee is a single calendar_event_attendees row, optionally enriched
// with the user's name/email for detail views (GetByID).
type Attendee struct {
	EventID    string  `json:"event_id"`
	UserID     string  `json:"user_id"`
	Role       string  `json:"role"`
	RSVPStatus string  `json:"rsvp_status"`
	Name       *string `json:"name,omitempty"`
	Email      *string `json:"email,omitempty"`
}

// EventInvite is a single calendar_event_invites row. TokenHash is never
// serialized — the raw token is only ever returned once, at creation time,
// by Service.InviteExternal.
type EventInvite struct {
	ID         string     `json:"id"`
	EventID    string     `json:"event_id"`
	Email      string     `json:"email"`
	Role       string     `json:"role"`
	TokenHash  string     `json:"-"`
	ExpiresAt  time.Time  `json:"expires_at"`
	AcceptedAt *time.Time `json:"accepted_at"`
	CreatedAt  time.Time  `json:"created_at"`
}

// Package notifications is a generic, dependency-free in-app notification
// domain — any other package can call Service.Notify/NotifyMany to write a
// notification, optionally also emailing it, without notifications knowing
// anything about the caller's own domain. Built for the GitLab integration
// feature's peer-review/CI-alert flows (see internal/gitlab/service_webhook.go
// and service_checkpoint.go) but deliberately has zero GitLab-specific code —
// mirrors internal/gitlab's own handler.go/repo.go/service.go/routes.go split.
package notifications

import "time"

// Priorities for Notification.Priority / New.Priority.
const (
	PriorityLow    = "low"
	PriorityNormal = "normal"
	PriorityHigh   = "high"
)

// Notification mirrors one notifications row (migration 023 §1.6).
type Notification struct {
	ID          string     `json:"id"`
	OrgID       string     `json:"org_id"`
	UserID      string     `json:"user_id"`
	Type        string     `json:"type"`
	Title       string     `json:"title"`
	Body        *string    `json:"body,omitempty"`
	LinkURL     *string    `json:"link_url,omitempty"`
	EntityType  *string    `json:"entity_type,omitempty"`
	EntityID    *string    `json:"entity_id,omitempty"`
	ActorUserID *string    `json:"actor_user_id,omitempty"`
	Priority    string     `json:"priority"`
	DedupeKey   string     `json:"dedupe_key"`
	ReadAt      *time.Time `json:"read_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

// New is the input to Service.Notify/NotifyMany — one notification to
// dedupe-insert keyed UNIQUE(user_id, dedupe_key). DedupeKey is the caller's
// responsibility to make stable across redeliveries of the same logical
// event (e.g. a webhook redelivery, or a repeated cron pass) — this package
// only enforces the uniqueness, callers choose the key.
//
// AlsoEmail, when true, additionally enqueues the existing email.send job
// (Type:"notification", see internal/jobs/handlers/email.go's own case for
// that type) so the user is emailed as well as notified in-app. Default
// false; by convention (not enforced here — callers decide) set it true only
// when Priority is "high", so routine activity doesn't spam inboxes while
// something like a CI failure still reaches the user outside the app.
type New struct {
	OrgID       string
	UserID      string
	Type        string
	Title       string
	Body        *string
	LinkURL     *string
	EntityType  *string
	EntityID    *string
	ActorUserID *string
	// Priority defaults to PriorityNormal when left empty — see Service.Notify.
	Priority  string
	DedupeKey string
	AlsoEmail bool
}

// ListView is GET /api/notifications' response body.
type ListView struct {
	Notifications []Notification `json:"notifications"`
}

// UnreadCountView is GET /api/notifications/unread-count's response body.
type UnreadCountView struct {
	UnreadCount int `json:"unread_count"`
}

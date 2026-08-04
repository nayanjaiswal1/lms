// Package moderation lets any org member flag a specific piece of
// user-generated content (a wiki page, a course module) as illegal,
// infringing, or abusive, and gives staff holding content.moderate a queue
// to review and resolve those flags. See
// backend/db/migrations/023_content_reports.sql.
package moderation

import "time"

// ContentType values — mirrors content_reports.content_type.
const (
	ContentWikiPage     = "wiki_page"
	ContentCourseModule = "course_module"
)

var validContentTypes = map[string]struct{}{
	ContentWikiPage:     {},
	ContentCourseModule: {},
}

// IsValidContentType reports whether contentType is one of the whitelisted
// content_reports.content_type CHECK values.
func IsValidContentType(contentType string) bool {
	_, ok := validContentTypes[contentType]
	return ok
}

// Reason values — mirrors content_reports.reason.
const (
	ReasonIllegal    = "illegal"
	ReasonCopyright  = "copyright"
	ReasonSpam       = "spam"
	ReasonHarassment = "harassment"
	ReasonOther      = "other"
)

var validReasons = map[string]struct{}{
	ReasonIllegal:    {},
	ReasonCopyright:  {},
	ReasonSpam:       {},
	ReasonHarassment: {},
	ReasonOther:      {},
}

// IsValidReason reports whether reason is one of the whitelisted
// content_reports.reason CHECK values.
func IsValidReason(reason string) bool {
	_, ok := validReasons[reason]
	return ok
}

// Status values — mirrors content_reports.status.
const (
	StatusPending   = "pending"
	StatusReviewing = "reviewing"
	StatusRemoved   = "removed"
	StatusDismissed = "dismissed"
)

var validStatuses = map[string]struct{}{
	StatusPending:   {},
	StatusReviewing: {},
	StatusRemoved:   {},
	StatusDismissed: {},
}

// IsValidStatus reports whether status is one of the whitelisted
// content_reports.status CHECK values.
func IsValidStatus(status string) bool {
	_, ok := validStatuses[status]
	return ok
}

// Report is a single content flag. Matches content_reports.
type Report struct {
	ID             string    `json:"id"`
	OrgID          string    `json:"org_id"`
	ReporterID     string    `json:"reporter_id"`
	ContentType    string    `json:"content_type"`
	ContentID      string    `json:"content_id"`
	Reason         string    `json:"reason"`
	Description    *string   `json:"description"`
	Status         string    `json:"status"`
	ResolvedBy     *string   `json:"resolved_by"`
	ResolutionNote *string   `json:"resolution_note"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

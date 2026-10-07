// Package useroverview aggregates one tenant member's org-scoped progress
// data for the admin user detail page: courses and recent activity. Personal
// domains with no org_id (journal, mistakes, habits, sheets) are deliberately
// NOT included: an org admin must not read a member's private content, which
// predates and outlives the membership. It lives in its own package, not internal/authz (which
// already gates /users/{userID} on admin.view_members and would be the
// obvious home), because internal/courses and internal/journal both import
// authz for its permission middleware — authz importing them back for their
// repos would be an import cycle. Depending on authz's exported, stateless
// AdminRepo without authz depending back mirrors internal/privacy's own
// precedent (privacy.New(pool, authz.NewAdminRepo(pool)), see router.go).
package useroverview

import (
	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/courses"
)

// recentActivityLimit caps the admin overview's activity feed — a recap, not
// a full paginated history (the self-service activity feed owns cursor
// pagination for that).
const recentActivityLimit = 30

// Overview is the full response for GET .../users/{userID}/overview.
type Overview struct {
	Enrollments    []courses.Enrollment `json:"enrollments"`
	RecentActivity []activity.Entry     `json:"recent_activity"`
}

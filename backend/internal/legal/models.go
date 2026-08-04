// Package legal tracks user consent to the Terms of Service and Privacy
// Policy: which version a user accepted, and when. The policy text itself is
// static frontend content — this package only proves consent happened. See
// backend/db/migrations/022_legal_acceptances.sql.
package legal

import "time"

// DocType values — mirrors legal_acceptances.doc_type.
const (
	DocTerms   = "terms"
	DocPrivacy = "privacy"
)

var validDocTypes = map[string]struct{}{
	DocTerms:   {},
	DocPrivacy: {},
}

// IsValidDocType reports whether docType is one of the whitelisted
// legal_acceptances.doc_type CHECK values.
func IsValidDocType(docType string) bool {
	_, ok := validDocTypes[docType]
	return ok
}

// CurrentVersion is the version string a user must have accepted for
// docType. Bumping one of these forces every user to re-accept that document
// on their next sign-in — there is deliberately no admin UI to edit this; a
// policy change is a deploy, not a runtime toggle.
func CurrentVersion(docType string) string {
	switch docType {
	case DocTerms:
		return "2026-08-04"
	case DocPrivacy:
		return "2026-08-04"
	default:
		return ""
	}
}

// AllDocTypes lists every document a user must accept, in a stable order.
var AllDocTypes = []string{DocTerms, DocPrivacy}

// Acceptance is a single consent record. Matches legal_acceptances.
type Acceptance struct {
	ID         string    `json:"id"`
	UserID     string    `json:"user_id"`
	DocType    string    `json:"doc_type"`
	Version    string    `json:"version"`
	IP         *string   `json:"ip,omitempty"`
	AcceptedAt time.Time `json:"accepted_at"`
}

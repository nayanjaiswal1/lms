package experience

import "time"

// SubjectType enumerates the kinds of activities a learner can report a
// post-completion experience against. It must stay in sync with the
// experience_reports.subject_type CHECK constraint in
// backend/db/migrations/027_experience_reports.sql.
type SubjectType string

const (
	SubjectTypeAssessment SubjectType = "assessment"
)

var validSubjectTypes = map[SubjectType]struct{}{
	SubjectTypeAssessment: {},
}

// IsValidSubjectType reports whether st is one of the whitelisted subject
// types the experience_reports table accepts.
func IsValidSubjectType(st SubjectType) bool {
	_, ok := validSubjectTypes[st]
	return ok
}

// Experience is the learner's self-reported outcome of the activity itself —
// distinct from feedback.Feedback's star rating, this captures whether
// anything went wrong so issues/complaints can be triaged separately from
// satisfaction scores.
type Experience string

const (
	ExperienceSmooth    Experience = "smooth"
	ExperienceIssue     Experience = "issue"
	ExperienceComplaint Experience = "complaint"
)

var validExperiences = map[Experience]struct{}{
	ExperienceSmooth:    {},
	ExperienceIssue:     {},
	ExperienceComplaint: {},
}

// IsValidExperience reports whether e is one of the whitelisted experience
// values the experience_reports table accepts.
func IsValidExperience(e Experience) bool {
	_, ok := validExperiences[e]
	return ok
}

// Report is a single learner's post-activity experience report (or explicit
// skip) for a subject. For SubjectTypeAssessment, SubjectID is the attempt ID
// the learner just completed, not the assessment definition ID.
type Report struct {
	ID          string      `json:"id"`
	OrgID       string      `json:"org_id"`
	SubjectType SubjectType `json:"subject_type"`
	SubjectID   string      `json:"subject_id"`
	UserID      string      `json:"user_id"`
	Experience  *Experience `json:"experience"`
	Description *string     `json:"description"`
	SkippedAt   *time.Time  `json:"skipped_at"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}

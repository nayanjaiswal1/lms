package feedback

import "time"

// Kind enumerates the kind of feedback. Must stay in sync with the
// feedback.kind CHECK constraint in backend/db/migrations/025_full_schema_consolidation.sql.
type Kind string

const (
	KindRating     Kind = "rating"
	KindExperience Kind = "experience"
)

var validKinds = map[Kind]struct{}{
	KindRating:     {},
	KindExperience: {},
}

// IsValidKind reports whether k is a whitelisted feedback kind.
func IsValidKind(k Kind) bool {
	_, ok := validKinds[k]
	return ok
}

// SubjectType enumerates the kinds of entities a learner can leave feedback
// on. Must stay in sync with the feedback.subject_type CHECK constraint
// in backend/db/migrations/025_full_schema_consolidation.sql.
type SubjectType string

const (
	SubjectTypeCourse         SubjectType = "course"
	SubjectTypeAssessment     SubjectType = "assessment"
	SubjectTypeLab            SubjectType = "lab"
	SubjectTypeMentor         SubjectType = "mentor"
	SubjectTypeMentorSession  SubjectType = "mentor_session"
	SubjectTypeExperienceSubj SubjectType = "experience_subject"
)

var validSubjectTypes = map[SubjectType]struct{}{
	SubjectTypeCourse:         {},
	SubjectTypeAssessment:     {},
	SubjectTypeLab:            {},
	SubjectTypeMentor:         {},
	SubjectTypeMentorSession:  {},
	SubjectTypeExperienceSubj: {},
}

// IsValidSubjectType reports whether st is one of the whitelisted subject
// types the feedback table accepts.
func IsValidSubjectType(st SubjectType) bool {
	_, ok := validSubjectTypes[st]
	return ok
}

// Feedback is a single learner's rating/comment (or explicit skip) for a
// course, assessment, lab, mentor, mentor session, or experience subject.
type Feedback struct {
	ID          string      `json:"id"`
	OrgID       *string     `json:"org_id"`
	SubjectType SubjectType `json:"subject_type"`
	SubjectID   string      `json:"subject_id"`
	UserID      string      `json:"user_id"`
	Kind        Kind        `json:"kind"`
	Rating      *int        `json:"rating"`
	Comment     *string     `json:"comment"`
	SkippedAt   *time.Time  `json:"skipped_at"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}

// PublicReview is one written review of a subject, shown to any org member
// browsing that subject (e.g. the "Recent feedback" list on a mentor
// profile) — reviewer identity included, since feedback here is always
// within-org (an org member's own colleagues/mentors), never a public
// stranger-facing listing. Only feedback with both a rating and a comment
// qualifies; a bare star rating with no text isn't a "review".
type PublicReview struct {
	ID           string    `json:"id"`
	ReviewerName string    `json:"reviewer_name"`
	ReviewerRole *string   `json:"reviewer_role"`
	Rating       int       `json:"rating"`
	Comment      string    `json:"comment"`
	CreatedAt    time.Time `json:"created_at"`
}

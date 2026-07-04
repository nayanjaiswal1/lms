package feedback

import "time"

// SubjectType enumerates the kinds of entities a learner can leave feedback
// on. It must stay in sync with the feedback.subject_type CHECK constraint
// in backend/db/migrations/016_feedback.sql.
type SubjectType string

const (
	SubjectTypeCourse     SubjectType = "course"
	SubjectTypeAssessment SubjectType = "assessment"
	SubjectTypeLab        SubjectType = "lab"
	SubjectTypeMentor     SubjectType = "mentor"
)

var validSubjectTypes = map[SubjectType]struct{}{
	SubjectTypeCourse:     {},
	SubjectTypeAssessment: {},
	SubjectTypeLab:        {},
	SubjectTypeMentor:     {},
}

// IsValidSubjectType reports whether st is one of the whitelisted subject
// types the feedback table accepts.
func IsValidSubjectType(st SubjectType) bool {
	_, ok := validSubjectTypes[st]
	return ok
}

// Feedback is a single learner's rating/comment (or explicit skip) for a
// course, assessment, or lab.
type Feedback struct {
	ID          string      `json:"id"`
	OrgID       string      `json:"org_id"`
	SubjectType SubjectType `json:"subject_type"`
	SubjectID   string      `json:"subject_id"`
	UserID      string      `json:"user_id"`
	Rating      *int        `json:"rating"`
	Comment     *string     `json:"comment"`
	SkippedAt   *time.Time  `json:"skipped_at"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}

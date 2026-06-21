package profile

import (
	"errors"
	"time"
)

// ─── Enumeration constants (mirror DB CHECK constraints) ─────────────────────

const (
	ExperienceBeginner     = "beginner"
	ExperienceIntermediate = "intermediate"
	ExperienceAdvanced     = "advanced"

	SkillBeginner     = "beginner"
	SkillIntermediate = "intermediate"
	SkillAdvanced     = "advanced"

	StyleVideo   = "video"
	StyleReading = "reading"
	StyleHandsOn = "hands_on"
	StyleMixed   = "mixed"
)

var (
	ValidExperienceLevels = []string{ExperienceBeginner, ExperienceIntermediate, ExperienceAdvanced}
	ValidSkillLevels      = []string{SkillBeginner, SkillIntermediate, SkillAdvanced}
	ValidLearningStyles   = []string{StyleVideo, StyleReading, StyleHandsOn, StyleMixed}
	ValidLearningGoals    = []string{
		"get_first_job", "switch_company", "become_senior",
		"learn_technology", "crack_interviews", "upskill_team",
	}
	ValidLearningDomains = []string{
		"backend", "frontend", "devops", "cloud", "ai_ml",
		"data_engineering", "mobile", "cybersecurity", "system_design",
	}
)

// ─── Domain errors ─────────────────────────────────────────────────────────────

var (
	ErrNotFound  = errors.New("profile: not found")
	ErrConflict  = errors.New("profile: display name or slug already taken")
	ErrForbidden = errors.New("profile: access denied")
)

// ─── Domain types ──────────────────────────────────────────────────────────────

// Profile is the full, private representation of a user's profile.
// Returned to the profile owner and privileged viewers (admin, super_admin).
type Profile struct {
	UserID    string  `json:"user_id"`
	Name      string  `json:"name"`
	AvatarURL *string `json:"avatar_url"`
	Email     string  `json:"email"`

	DisplayName      *string `json:"display_name"`
	Bio              *string `json:"bio"`
	ProfileSlug      *string `json:"profile_slug"`
	PublicEnabled    bool    `json:"public_enabled"`
	ShowSkills       bool    `json:"show_skills"`
	ShowAchievements bool    `json:"show_achievements"`
	ShowCertificates bool    `json:"show_certificates"`
	ShowActivity     bool    `json:"show_activity"`

	ExperienceLevel        *string  `json:"experience_level"`
	LearningGoal           *string  `json:"learning_goal"`
	TopicsInterest         []string `json:"topics_interest"`
	WeeklyTimeCommitment   *string  `json:"weekly_time_commitment"`
	PreferredLearningStyle *string  `json:"preferred_learning_style"`

	CurrentRole       *string `json:"current_role"`
	YearsOfExperience *int16  `json:"years_of_experience"`

	Language      *string                `json:"language"`
	Timezone      *string                `json:"timezone"`
	WeeklyGoalHrs *int16                 `json:"weekly_goal_hrs"`
	Notifications map[string]interface{} `json:"notifications"`

	CompletionScore int `json:"completion_score"`

	Skills      []Skill      `json:"skills"`
	SocialLinks *SocialLinks `json:"social_links"`
	Stats       *Stats       `json:"stats"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Skill is a single user skill entry.
type Skill struct {
	ID         string    `json:"id"`
	SkillName  string    `json:"skill_name"`
	SkillLevel string    `json:"skill_level"`
	CreatedAt  time.Time `json:"created_at"`
}

// SocialLinks holds a user's optional public contact links.
type SocialLinks struct {
	LinkedIn  *string   `json:"linkedin"`
	GitHub    *string   `json:"github"`
	Portfolio *string   `json:"portfolio"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Stats aggregates a user's platform activity counters.
type Stats struct {
	CoursesEnrolled    int     `json:"courses_enrolled"`
	CoursesCompleted   int     `json:"courses_completed"`
	TestsAttempted     int     `json:"tests_attempted"`
	TestsPassed        int     `json:"tests_passed"`
	ProblemsSolved     int     `json:"problems_solved"`
	CertificatesEarned int     `json:"certificates_earned"`
	CurrentStreakDays  int     `json:"current_streak_days"`
	LearningHours      float64 `json:"learning_hours"`
	RoadmapsCompleted  int     `json:"roadmaps_completed"`
}

// PublicProfile is the limited view of a profile visible to anonymous visitors
// when public_enabled is true. Privacy flags gate optional sections.
type PublicProfile struct {
	Name            string       `json:"name"`
	DisplayName     *string      `json:"display_name"`
	AvatarURL       *string      `json:"avatar_url"`
	Bio             *string      `json:"bio"`
	ExperienceLevel *string      `json:"experience_level"`
	CurrentRole     *string      `json:"current_role"`
	Skills          []Skill      `json:"skills,omitempty"`
	SocialLinks     *SocialLinks `json:"social_links,omitempty"`
	Stats           *Stats       `json:"stats,omitempty"`
}

// ─── Input types ───────────────────────────────────────────────────────────────

// UpdateProfileInput carries the caller-supplied fields for a profile update.
// Only non-nil pointer fields are applied; omitted fields are left unchanged.
type UpdateProfileInput struct {
	Name                   *string                `json:"name"`
	DisplayName            *string                `json:"display_name"`
	Bio                    *string                `json:"bio"`
	ExperienceLevel        *string                `json:"experience_level"`
	LearningGoal           *string                `json:"learning_goal"`
	TopicsInterest         *[]string              `json:"topics_interest"`
	WeeklyTimeCommitment   *string                `json:"weekly_time_commitment"`
	PreferredLearningStyle *string                `json:"preferred_learning_style"`
	CurrentRole            *string                `json:"current_role"`
	YearsOfExperience      *int16                 `json:"years_of_experience"`
	Language               *string                `json:"language"`
	Timezone               *string                `json:"timezone"`
	WeeklyGoalHrs          *int16                 `json:"weekly_goal_hrs"`
	Notifications          map[string]interface{} `json:"notifications"`
	PublicEnabled          *bool                  `json:"public_enabled"`
	ShowSkills             *bool                  `json:"show_skills"`
	ShowAchievements       *bool                  `json:"show_achievements"`
	ShowCertificates       *bool                  `json:"show_certificates"`
	ShowActivity           *bool                  `json:"show_activity"`
	LinkedIn               *string                `json:"linkedin"`
	GitHub                 *string                `json:"github"`
	Portfolio              *string                `json:"portfolio"`
}

// AddSkillInput is the payload for adding a new skill to a user's profile.
type AddSkillInput struct {
	SkillName  string `json:"skill_name"`
	SkillLevel string `json:"skill_level"`
}

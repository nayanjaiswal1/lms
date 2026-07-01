package rewards

import "time"

// ─── XP level definitions (hardcoded — not in DB) ────────────────────────────

type xpLevelDef struct {
	Level int
	Name  string
	MinXP int
	MaxXP int // -1 for the final level
}

var xpLevels = []xpLevelDef{
	{1, "Apprentice", 0, 500},
	{2, "Learner", 500, 1500},
	{3, "Explorer", 1500, 3500},
	{4, "Practitioner", 3500, 7000},
	{5, "Proficient", 7000, 13000},
	{6, "Advanced", 13000, 23000},
	{7, "Expert", 23000, 40000},
	{8, "Master", 40000, 65000},
	{9, "Grandmaster", 65000, 100000},
	{10, "Legend", 100000, -1},
}

// ─── XP award constants ───────────────────────────────────────────────────────

const (
	XPProblemSolved     = 50
	XPQuizPassedFirst   = 30
	XPQuizPassedRepeat  = 10
	XPQuizPerfectBonus  = 50
	XPModuleCompleted   = 100
	XPCourseCompleted   = 500
	XPCertificateEarned = 1000
	XPStreak7Days       = 200
	XPStreak30Days      = 1000
	XPStreak100Days     = 5000
)

// StreakMilestones maps streak day threshold → XP bonus. Used by CheckStreakMilestones.
var StreakMilestones = map[int]int{
	7:   XPStreak7Days,
	30:  XPStreak30Days,
	100: XPStreak100Days,
}

// ─── Public types ─────────────────────────────────────────────────────────────

type RewardDefinition struct {
	ID               string    `json:"id"`
	Slug             string    `json:"slug"`
	Name             string    `json:"name"`
	Description      string    `json:"description"`
	Icon             string    `json:"icon"`
	BadgeTier        string    `json:"badge_tier"`
	XPValue          int       `json:"xp_value"`
	TriggerEvent     string    `json:"trigger_event"`
	TriggerThreshold int       `json:"trigger_threshold"`
	CreatedAt        time.Time `json:"created_at"`
}

type UserAchievement struct {
	ID         string           `json:"id"`
	UserID     string           `json:"user_id"`
	Definition RewardDefinition `json:"definition"`
	OrgID      *string          `json:"org_id,omitempty"`
	EarnedAt   time.Time        `json:"earned_at"`
}

type UserLevel struct {
	Level       int     `json:"level"`
	Name        string  `json:"name"`
	MinXP       int     `json:"min_xp"`
	MaxXP       int     `json:"max_xp"`
	ProgressPct float64 `json:"progress_pct"`
}

type XPEvent struct {
	ID            string    `json:"id"`
	XPAmount      int       `json:"xp_amount"`
	Reason        string    `json:"reason"`
	ReferenceID   *string   `json:"reference_id,omitempty"`
	ReferenceType *string   `json:"reference_type,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

type UserRewardProfile struct {
	TotalXP      int               `json:"total_xp"`
	Level        UserLevel         `json:"level"`
	Achievements []UserAchievement `json:"achievements"`
	RecentXP     []XPEvent         `json:"recent_xp"`
}

type LeaderboardEntry struct {
	Rank      int     `json:"rank"`
	UserID    string  `json:"user_id"`
	Name      string  `json:"name"`
	AvatarURL *string `json:"avatar_url,omitempty"`
	TotalXP   int     `json:"total_xp"`
	Level     int     `json:"level"`
	LevelName string  `json:"level_name"`
}

// AwardResult is returned by AwardXP and piggybacked on API responses.
type AwardResult struct {
	XPGained        int               `json:"xp_gained"`
	NewLevel        *UserLevel        `json:"new_level,omitempty"`
	NewAchievements []UserAchievement `json:"new_achievements"`
}

// AwardXPRequest bundles all context for a single XP award event.
type AwardXPRequest struct {
	UserID   string
	OrgID    string
	BatchID  *string // non-nil when the event happens inside a batch
	CourseID *string // non-nil when the event happens inside a course
	Reason   string
	RefID    *string
	RefType  *string
	XP       int
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// ComputeLevel returns level info for the given XP total.
func ComputeLevel(totalXP int) UserLevel {
	cur := xpLevels[0]
	for _, l := range xpLevels {
		if totalXP >= l.MinXP {
			cur = l
		}
	}
	var pct float64
	if cur.MaxXP == -1 {
		pct = 100
	} else if span := cur.MaxXP - cur.MinXP; span > 0 {
		pct = float64(totalXP-cur.MinXP) / float64(span) * 100
	}
	return UserLevel{Level: cur.Level, Name: cur.Name, MinXP: cur.MinXP, MaxXP: cur.MaxXP, ProgressPct: pct}
}

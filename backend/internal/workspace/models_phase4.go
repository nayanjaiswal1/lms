package workspace

import (
	"errors"
	"regexp"
	"time"
)

// Phase 4 — GitLab ticket linking, time logs, member leave, dashboard,
// health, digest. Lead-owned.

// TicketKeyPattern finds ticket keys ({PREFIX}-{n}) in commit messages,
// branch names and MR text (D7). The prefix must also belong to the
// workspace that owns the pushing team before anything is linked.
var TicketKeyPattern = regexp.MustCompile(`\b([A-Z]{2,6})-(\d{1,9})\b`)

const (
	TimeLogMaxMinutes      = 720
	TimeLogDailyCap        = 1440
	TimeLogEditWindow      = 7 * 24 * time.Hour
	TimeLogNoteMaxLen      = 1000
	InactivityAlertAfter   = 7 * 24 * time.Hour
	InactivitySuggestAfter = 14 * 24 * time.Hour
	MRSizeFlagLines        = 400
	DashboardDefaultRange  = 14 * 24 * time.Hour
	HealthGreen            = "green"
	HealthYellow           = "yellow"
	HealthRed              = "red"
)

const (
	GitlabRefBranch = "branch"
	GitlabRefMR     = "mr"
	GitlabRefCommit = "commit"
)

var (
	ErrTimeLogCap    = errors.New("that would log more than 24 hours on one day")
	ErrTimeLogLocked = errors.New("time logs can only be edited for 7 days")
)

// GitlabLink is one work_item_gitlab row joined to its MR mirror.
type GitlabLink struct {
	ID             string     `json:"id"`
	Kind           string     `json:"kind"`
	Ref            string     `json:"ref"`
	SyncStatus     string     `json:"sync_status"`
	MRTitle        *string    `json:"mr_title"`
	MRState        *string    `json:"mr_state"`
	MRWebURL       *string    `json:"mr_web_url"`
	PipelineStatus *string    `json:"pipeline_status"`
	Additions      *int       `json:"additions"`
	Deletions      *int       `json:"deletions"`
	FirstSeenAt    time.Time  `json:"first_seen_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
	MergedAt       *time.Time `json:"merged_at"`
}

// TimeLog is one work_item_time_logs row.
type TimeLog struct {
	ID        string    `json:"id"`
	ItemID    string    `json:"item_id"`
	ItemKey   string    `json:"item_key"`
	UserID    *string   `json:"user_id"`
	UserName  string    `json:"user_name"`
	Minutes   int       `json:"minutes"`
	Note      *string   `json:"note"`
	LoggedOn  string    `json:"logged_on"` // YYYY-MM-DD
	CreatedAt time.Time `json:"created_at"`
	Editable  bool      `json:"editable"`
}

type TimeLogRequest struct {
	Minutes  int     `json:"minutes"`
	Note     *string `json:"note"`
	LoggedOn string  `json:"logged_on"`
}

// ─── Dashboard (05 Part A.4) ──────────────────────────────────────────────────

// DashboardFilter is the GET …/dashboard query; zero values = defaults
// (current sprint, else last 14 days; whole project).
type DashboardFilter struct {
	From      time.Time
	To        time.Time
	TrackID   string
	UserID    string
	ReleaseID string
}

type PercentileStat struct {
	Count     int      `json:"count"`
	MedianHrs *float64 `json:"median_hours"`
	P85Hrs    *float64 `json:"p85_hours"`
}

type PersonRef struct {
	UserID string `json:"user_id"`
	Name   string `json:"name"`
}

type AttentionItem struct {
	Item   ItemRef    `json:"item"`
	Detail string     `json:"detail"`
	Since  *time.Time `json:"since"`
}

type AttentionPerson struct {
	Person PersonRef `json:"person"`
	Detail string    `json:"detail"`
}

type AttentionTrack struct {
	TrackID string `json:"track_id"`
	Name    string `json:"name"`
}

type NeedsAttention struct {
	BlockedItems     []AttentionItem   `json:"blocked_items"`
	OverdueItems     []AttentionItem   `json:"overdue_items"`
	StaleReviews     []AttentionItem   `json:"stale_reviews"`
	OpenS1S2Bugs     []AttentionItem   `json:"open_s1_s2_bugs"`
	StuckOnboarding  []AttentionPerson `json:"stuck_onboarding"`
	InactiveMembers  []AttentionPerson `json:"inactive_members"`
	LeaderlessTracks []AttentionTrack  `json:"leaderless_tracks"`
	StandupBlockers  []ItemRef         `json:"standup_blockers"`
}

type DayPoint struct {
	Day   string `json:"day"`
	Open  int    `json:"open"`
	Done  int    `json:"done"`
	Added int    `json:"added"`
}

type WeekPoint struct {
	Week  string `json:"week"`
	Count int    `json:"count"`
	Fixed int    `json:"fixed,omitempty"`
}

type ScopeChurn struct {
	AddedAfterStart    int `json:"added_after_start"`
	RemovedAfterStart  int `json:"removed_after_start"`
	ChangeRequests     int `json:"change_requests"`
	BriefVersionsAfter int `json:"brief_versions_after_agreed"`
}

type RequirementClarity struct {
	Asked              int      `json:"asked"`
	Answered           int      `json:"answered"`
	Assumptions        int      `json:"assumptions"`
	MedianAnswerHrs    *float64 `json:"median_answer_hours"`
	DaysActiveToAgreed *float64 `json:"days_active_to_agreed"`
}

type Forecast struct {
	Remaining        int        `json:"remaining"`
	WeeklyThroughput float64    `json:"weekly_throughput"`
	ProjectedFinish  *time.Time `json:"projected_finish"`
	Target           *time.Time `json:"target"`
	OverTargetPct    *float64   `json:"over_target_pct"`
}

type Delivery struct {
	ProgressPct        float64                   `json:"progress_pct"`
	Burndown           []DayPoint                `json:"burndown"`
	Throughput         []WeekPoint               `json:"throughput"`
	LeadTime           PercentileStat            `json:"lead_time"`
	CycleTime          PercentileStat            `json:"cycle_time"`
	StageTime          map[string]PercentileStat `json:"stage_time"`
	BlockedHours       float64                   `json:"blocked_hours"`
	TopBlockers        []AttentionItem           `json:"top_blockers"`
	ScopeChurn         ScopeChurn                `json:"scope_churn"`
	RequirementClarity RequirementClarity        `json:"requirement_clarity"`
	SprintCommitment   *float64                  `json:"sprint_commitment_pct"`
	Forecast           Forecast                  `json:"forecast"`
	DocTurnaround      PercentileStat            `json:"doc_turnaround"`
	DocReviewRounds    float64                   `json:"doc_review_rounds"`
}

type SeverityCount struct {
	Severity     string  `json:"severity"`
	Open         int     `json:"open"`
	OldestAgeHrs float64 `json:"oldest_age_hours"`
}

type Quality struct {
	BugsBySeverity  []SeverityCount  `json:"bugs_by_severity"`
	BugInflowVsFix  []WeekPoint      `json:"bug_inflow_vs_fix"`
	ReopenRatePct   float64          `json:"reopen_rate_pct"`
	EscapedBugs     int              `json:"escaped_bugs"`
	BugDensity      []FeatureDensity `json:"bug_density"`
	CIPassRatePct   *float64         `json:"ci_pass_rate_pct"`
	MRReviewRounds  PercentileStat   `json:"mr_review_rounds"`
	MRSizeMedian    *float64         `json:"mr_size_median"`
	LargeMRs        int              `json:"large_mrs"`
	TestCoveragePct float64          `json:"test_coverage_pct"`
}

type FeatureDensity struct {
	Feature ItemRef `json:"feature"`
	Bugs    int     `json:"bugs"`
	Tasks   int     `json:"tasks"`
}

// PersonMetrics is one People-table row (§16.4). Coaching, not ranking —
// never sorted by a score.
type PersonMetrics struct {
	Person            PersonRef      `json:"person"`
	Role              string         `json:"role"`
	LoadByRole        map[string]int `json:"load_by_role"`
	WIP               int            `json:"wip"`
	WipLimit          int            `json:"wip_limit"`
	CompletedOwned    int            `json:"completed_owned"`
	ReviewsDone       int            `json:"reviews_done"`
	TestsDone         int            `json:"tests_done"`
	ReviewResponseHrs *float64       `json:"review_response_hours"`
	MinutesLogged     int            `json:"minutes_logged"`
	Commits           int            `json:"commits"`
	MRsOpened         int            `json:"mrs_opened"`
	MRsMerged         int            `json:"mrs_merged"`
	EstimateAccuracy  *float64       `json:"estimate_accuracy"`
	ReopensCaused     int            `json:"reopens_caused"`
	AttendancePct     *float64       `json:"attendance_pct"`
	StandupsPosted    int            `json:"standups_posted"`
	OnboardingPct     int            `json:"onboarding_pct"`
	LastActive        *time.Time     `json:"last_active"`
}

type PlanTreeNode struct {
	Item        ItemRef        `json:"item"`
	ProgressPct float64        `json:"progress_pct"`
	DocStatus   *string        `json:"doc_status"`
	ReleaseID   *string        `json:"release_id"`
	Owner       *PersonRef     `json:"owner"`
	AtRisk      bool           `json:"at_risk"`
	Children    []PlanTreeNode `json:"children"`
}

type TrackMetrics struct {
	TrackID             string         `json:"track_id"`
	Name                string         `json:"name"`
	Lead                *PersonRef     `json:"lead"`
	Members             int            `json:"members"`
	Open                int            `json:"open"`
	Done                int            `json:"done"`
	Throughput          int            `json:"throughput"`
	CycleTime           PercentileStat `json:"cycle_time"`
	Bugs                int            `json:"bugs"`
	WIP                 int            `json:"wip"`
	Capacity            int            `json:"capacity"`
	FeaturesAwaitingDoc int            `json:"features_awaiting_doc"`
	CrossTrackBlockers  int            `json:"cross_track_blockers"`
}

type HealthReport struct {
	Color   string   `json:"color"`
	Reasons []string `json:"reasons"`
}

type DashboardHeader struct {
	Status        string       `json:"status"`
	DaysLeft      *int         `json:"days_left"`
	ReleaseTarget *time.Time   `json:"release_target"`
	Health        HealthReport `json:"health"`
	From          time.Time    `json:"from"`
	To            time.Time    `json:"to"`
}

// Dashboard is GET …/dashboard. Sections the caller may not see (02 §7.2)
// are nil/empty: viewers get totals only, members their own person row.
type Dashboard struct {
	Header         DashboardHeader `json:"header"`
	NeedsAttention NeedsAttention  `json:"needs_attention"`
	Delivery       Delivery        `json:"delivery"`
	Quality        Quality         `json:"quality"`
	People         []PersonMetrics `json:"people"`
	PlanTree       []PlanTreeNode  `json:"plan_tree"`
	Tracks         []TrackMetrics  `json:"tracks"`
	Release        *ReleaseMetrics `json:"release"`
	AISummary      *WeeklySummary  `json:"ai_summary"`
}

// ReleaseMetrics is filled in Phase 5 (releases); nil before.
type ReleaseMetrics struct {
	ReleaseID             string          `json:"release_id"`
	Version               string          `json:"version"`
	Status                string          `json:"status"`
	FeaturesDone          int             `json:"features_done"`
	FeaturesTotal         int             `json:"features_total"`
	OpenBugsBySeverity    map[string]int  `json:"open_bugs_by_severity"`
	DaysToTarget          *int            `json:"days_to_target"`
	ForecastFinish        *time.Time      `json:"forecast_finish"`
	ScopeAddedAfterFreeze int             `json:"scope_added_after_freeze"`
	DocsNotApproved       int             `json:"docs_not_approved"`
	Readiness             map[string]bool `json:"readiness"`
}

// WeeklySummary is the cached AI weekly summary (Phase 5; manager+ only).
type WeeklySummary struct {
	Week      string    `json:"week"`
	Shipped   []string  `json:"shipped"`
	Risks     []string  `json:"risks"`
	NeedsHelp []string  `json:"needs_help"`
	CreatedAt time.Time `json:"created_at"`
}

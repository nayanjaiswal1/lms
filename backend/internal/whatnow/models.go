package whatnow

import "time"

// Energy is the user's current self-reported energy level.
type Energy string

const (
	EnergySharp Energy = "sharp"
	EnergyTired Energy = "tired"
)

// ChipKind categorizes a Chip shown alongside a captured task.
type ChipKind string

const (
	ChipDeadline ChipKind = "deadline"
	ChipCategory ChipKind = "category"
	ChipDuration ChipKind = "duration"
	ChipVague    ChipKind = "vague"
)

// Chip is a small parsed-attribute badge rendered on a task card.
type Chip struct {
	ID    string   `json:"id"`
	Kind  ChipKind `json:"kind"`
	Label string   `json:"label"`
	Value string   `json:"value,omitempty"`
}

// TaskStatus is the lifecycle state of a Task.
type TaskStatus string

const (
	StatusInbox   TaskStatus = "inbox"
	StatusPlanned TaskStatus = "planned"
	StatusActive  TaskStatus = "active"
	StatusPaused  TaskStatus = "paused"
	StatusDone    TaskStatus = "done"
	StatusDecayed TaskStatus = "decayed"
)

// Task is one item on the user's What Now? shelf.
type Task struct {
	ID           string     `json:"id"`
	Title        string     `json:"title"`
	Status       TaskStatus `json:"status"`
	Rationale    string     `json:"rationale,omitempty"`
	Trigger      string     `json:"trigger,omitempty"`
	DurationMin  *int       `json:"durationMin,omitempty"`
	Deadline     string     `json:"deadline,omitempty"`
	Category     string     `json:"category,omitempty"`
	Vague        bool       `json:"vague,omitempty"`
	Chips        []Chip     `json:"chips,omitempty"`
	ResumeNote   string     `json:"resumeNote,omitempty"`
	DependsOn    []string   `json:"dependsOn,omitempty"`
	CreatedAt    string     `json:"createdAt,omitempty"`
	CompletedAt  string     `json:"completedAt,omitempty"`
	// ScheduledStart is the RFC3339 start time of this task's time block on
	// the Plan Day timeline. Empty when the task is unscheduled.
	ScheduledStart string `json:"scheduledStart,omitempty"`

	// Internal fields — not exposed on the wire, used to drive PickNow/sweep/recap.
	touchedAt      time.Time
	pinnedUntil    *time.Time
	planPosition   *int
	scheduledStart *time.Time
	revivedAt      *time.Time
	decayedAt      *time.Time
	userID         string
}

// NowResponse is returned by GET /tasks/now.
type NowResponse struct {
	Primary      *Task  `json:"primary"`
	Alternatives []Task `json:"alternatives"`
	Rationale    string `json:"rationale"`
}

// CompleteResponse is returned by POST /tasks/:id/complete.
type CompleteResponse struct {
	UnlockedTasks []Task `json:"unlockedTasks"`
}

// StuckReason is why the user is stuck on a task.
type StuckReason string

const (
	StuckTooBig            StuckReason = "too_big"
	StuckNotSureItMatters   StuckReason = "not_sure_it_matters"
	StuckDeadlineUnreal    StuckReason = "deadline_unreal"
	StuckCantFocus         StuckReason = "cant_focus"
)

// StuckResolution is the canned response to a stuck report.
type StuckResolution struct {
	Message string `json:"message"`
	Task    *Task  `json:"task,omitempty"`
}

// BreakdownStep is one proposed step of a task breakdown.
type BreakdownStep struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	DurationMin *int   `json:"durationMin,omitempty"`
}

// BreakdownProposal is the fixed 3-step breakdown template for a task.
type BreakdownProposal struct {
	TaskID string          `json:"taskId"`
	Steps  []BreakdownStep `json:"steps"`
}

// PlanToday is today's planned task list.
type PlanToday struct {
	Tasks      []Task `json:"tasks"`
	Cap        int    `json:"cap"`
	Throughput int    `json:"throughput"`
}

// WeeklyRecap summarizes the last 7 days of activity.
type WeeklyRecap struct {
	Completed int    `json:"completed"`
	Revived   int    `json:"revived"`
	Released  int    `json:"released"`
	Summary   string `json:"summary"`
}

// TaskPatch is a partial update to a Task. Nil fields are left unchanged.
type TaskPatch struct {
	Title       *string     `json:"title,omitempty"`
	Status      *TaskStatus `json:"status,omitempty"`
	Trigger     *string     `json:"trigger,omitempty"`
	DurationMin *int        `json:"durationMin,omitempty"`
	Deadline    *string     `json:"deadline,omitempty"`
	Category    *string     `json:"category,omitempty"`
	Chips       []Chip      `json:"chips,omitempty"`
	ResumeNote  *string     `json:"resumeNote,omitempty"`
	// Pinned promotes (true) or un-promotes (false) the task as the hard
	// "do this now" override for PickNow. See service.go PickNow.
	Pinned *bool `json:"pinned,omitempty"`
	// ScheduledStart is an RFC3339 timestamp to schedule the task's time
	// block; an empty string clears it (unschedules), same NULLIF convention
	// as Deadline. Nil leaves it unchanged.
	ScheduledStart *string `json:"scheduledStart,omitempty"`
}

// DayPlan is the Plan Day view for one calendar day: tasks already time-
// blocked that day, plus the unscheduled backlog ranked by plan_position.
type DayPlan struct {
	Date        string `json:"date"`
	Scheduled   []Task `json:"scheduled"`
	Unscheduled []Task `json:"unscheduled"`
}

// PlanTodayRequest is the body for POST /plan/today.
type PlanTodayRequest struct {
	TaskIDs []string `json:"taskIds"`
}

// CaptureRequest is the body for POST /tasks.
type CaptureRequest struct {
	Raw string `json:"raw"`
}

// PauseRequest is the body for POST /tasks/:id/pause.
type PauseRequest struct {
	ResumeNote string `json:"resumeNote"`
}

// StuckRequest is the body for POST /tasks/:id/stuck.
type StuckRequest struct {
	Reason StuckReason `json:"reason"`
}

// EnergyRequest is the body for PUT /me/energy.
type EnergyRequest struct {
	Energy Energy `json:"energy"`
}

// NowQuery holds the parsed query params for GET /tasks/now.
type NowQuery struct {
	Energy       Energy
	AvailableMin *int
}

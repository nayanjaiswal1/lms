package habit

import "time"

// Cadence determines which section of the tracker a habit renders in and how
// its period_start values are aligned: a day for daily, the Monday of that
// ISO week for weekly, the 1st of the month for monthly.
type Cadence string

const (
	CadenceDaily   Cadence = "daily"
	CadenceWeekly  Cadence = "weekly"
	CadenceMonthly Cadence = "monthly"
)

func validCadence(c Cadence) bool {
	switch c {
	case CadenceDaily, CadenceWeekly, CadenceMonthly:
		return true
	}
	return false
}

// Color is one slot in the fixed 8-hue categorical palette habits render
// with (daily wheel wedges, weekly checkboxes, monthly checkboxes). A new
// habit is assigned the next slot in this order, rotating; the user can
// change it afterward via UpdateColorRequest. Free-form hex is deliberately
// not supported — the fixed set keeps every combination CVD-safe.
type Color string

const (
	ColorBlue    Color = "blue"
	ColorOrange  Color = "orange"
	ColorAqua    Color = "aqua"
	ColorYellow  Color = "yellow"
	ColorMagenta Color = "magenta"
	ColorGreen   Color = "green"
	ColorViolet  Color = "violet"
	ColorRed     Color = "red"
)

// ColorPalette is the fixed assignment order — also mirrored as the literal
// SQL array in Repo.Create so a new habit's default color is computed in
// the same INSERT that picks its sort_order.
var ColorPalette = []Color{ColorBlue, ColorOrange, ColorAqua, ColorYellow, ColorMagenta, ColorGreen, ColorViolet, ColorRed}

func validColor(c Color) bool {
	for _, v := range ColorPalette {
		if v == c {
			return true
		}
	}
	return false
}

// TargetCount and Weekdays together select a weekly habit's tracking mode —
// mutually exclusive, enforced in Service.Create's validateWeeklyOptions:
//   - TargetCount > 1, Weekdays empty: "any N times a week" — the weekly
//     wedge accumulates check-ins up to TargetCount within one period.
//   - Weekdays non-empty, TargetCount == 1: "specific weekdays" — completion
//     is tracked per calendar day, same as a daily habit, but only on the
//     chosen weekdays. Values are Sunday=0..Saturday=6, matching Go's
//     time.Weekday so no translation is needed against mondayOfWeek.
//
// Daily and monthly habits always carry TargetCount 1 and empty Weekdays.
type Habit struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	Name        string    `json:"name"`
	Cadence     Cadence   `json:"cadence"`
	SortOrder   int       `json:"sort_order"`
	Color       Color     `json:"color"`
	TargetCount int       `json:"target_count"`
	Weekdays    []int32   `json:"weekdays"`
	CreatedAt   time.Time `json:"created_at"`
}

type CreateRequest struct {
	Name        string  `json:"name"`
	Cadence     Cadence `json:"cadence"`
	TargetCount int     `json:"target_count"`
	Weekdays    []int32 `json:"weekdays"`
}

type UpdateColorRequest struct {
	Color Color `json:"color"`
}

// Completion is a single checked-off period for a habit. PeriodStart is
// formatted "2006-01-02" — a plain date, not a timestamp. Count is always 1
// except for an "any N times a week" habit, where it tracks how many of the
// habit's TargetCount check-ins have landed in this period.
type Completion struct {
	HabitID     string `json:"habit_id"`
	PeriodStart string `json:"period_start"`
	Count       int    `json:"count"`
}

// MonthView is everything the tracker needs to render one viewed month: the
// user's habits plus every completion whose period overlaps that month
// (including a weekly row whose Monday falls in the prior month but whose
// week still spans into this one).
type MonthView struct {
	Habits      []Habit      `json:"habits"`
	Completions []Completion `json:"completions"`
}

package habit

import (
	"time"
	"unicode/utf8"
)

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

// HabitType selects which structured entry form (if any) renders below the
// habit grid when a habit is clicked. Generic habits have no form — just the
// plain done/not-done grid, same as before this feature existed. The
// built-in types (gym/sleep/reading) have a fixed field set defined in
// builtinMetadataFields (service.go); Custom's fields are user-defined per
// habit via CustomFields below.
type HabitType string

const (
	HabitTypeGeneric HabitType = "generic"
	HabitTypeGym     HabitType = "gym"
	HabitTypeSleep   HabitType = "sleep"
	HabitTypeReading HabitType = "reading"
	HabitTypeCustom  HabitType = "custom"
)

func validHabitType(t HabitType) bool {
	switch t {
	case HabitTypeGeneric, HabitTypeGym, HabitTypeSleep, HabitTypeReading, HabitTypeCustom:
		return true
	}
	return false
}

// CustomFieldKind is the input shape for one field of a "custom" habit's
// entry form — the same five kinds the built-in types (gym/sleep/reading)
// render with, just picked by the user instead of hardcoded per type.
type CustomFieldKind string

const (
	CustomFieldText     CustomFieldKind = "text"
	CustomFieldNumber   CustomFieldKind = "number"
	CustomFieldTextarea CustomFieldKind = "textarea"
	CustomFieldTime     CustomFieldKind = "time"
	CustomFieldSlider   CustomFieldKind = "slider"
)

func validCustomFieldKind(k CustomFieldKind) bool {
	switch k {
	case CustomFieldText, CustomFieldNumber, CustomFieldTextarea, CustomFieldTime, CustomFieldSlider:
		return true
	}
	return false
}

// CustomField is one entry-form field of a "custom" habit. Key is what
// metadata is keyed by (must be unique within the habit); Label is what the
// form shows.
type CustomField struct {
	Key   string          `json:"key"`
	Label string          `json:"label"`
	Kind  CustomFieldKind `json:"kind"`
}

// Color is one slot in the fixed 8-hue categorical palette habits render
// with (daily wheel wedges, weekly checkboxes, monthly checkboxes). A new
// habit is assigned the next slot in this order, rotating; the user can
// change it afterward via UpdateRequest. Free-form hex is deliberately
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

// IconOptions is the curated set a habit's icon may be set to — kept in sync
// with frontend/lib/habits/icons.ts and the habits_icon_check DB constraint.
// "" is always valid too: it means "no override," so the UI falls back to
// the type/cadence icon (see HABIT_TYPE_ICON / CADENCE_ICON on the frontend).
var IconOptions = []string{
	"dumbbell", "moon", "book-open", "brain", "droplet", "utensils", "flower",
	"footprints", "phone-off", "heart", "music", "palette", "code", "piggy-bank",
	"leaf", "sun", "coffee", "pen-tool", "target", "users", "briefcase",
	"graduation-cap", "bike", "smile",
}

// maxCustomIconRunes caps a non-curated icon value (an emoji typed via the
// OS/Android keyboard picker rather than picked from IconOptions) — not
// validating "is this really an emoji" (no stdlib support for that, and
// it's a purely decorative field), just bounding length as an abuse guard.
// Mirrored by the habits_icon_check DB CHECK.
const maxCustomIconRunes = 8

func validIcon(icon string) bool {
	if icon == "" {
		return true
	}
	for _, v := range IconOptions {
		if v == icon {
			return true
		}
	}
	return utf8.RuneCountInString(icon) <= maxCustomIconRunes
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
	ID           string        `json:"id"`
	UserID       string        `json:"user_id"`
	Name         string        `json:"name"`
	Cadence      Cadence       `json:"cadence"`
	SortOrder    int           `json:"sort_order"`
	Color        Color         `json:"color"`
	TargetCount  int           `json:"target_count"`
	Weekdays     []int32       `json:"weekdays"`
	Type         HabitType     `json:"type"`
	CustomFields []CustomField `json:"custom_fields"`
	// Icon overrides the type/cadence default when non-empty — one of
	// IconOptions. Tags are free-form, user-defined categories used to
	// filter the tracker (see Service.normalizeTags for the cap/dedup
	// rules); neither persists any history beyond the habit row itself.
	Icon      string    `json:"icon"`
	Tags      []string  `json:"tags"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateRequest struct {
	Name         string        `json:"name"`
	Cadence      Cadence       `json:"cadence"`
	TargetCount  int           `json:"target_count"`
	Weekdays     []int32       `json:"weekdays"`
	Type         HabitType     `json:"type"`
	CustomFields []CustomField `json:"custom_fields"`
	Icon         string        `json:"icon"`
	Tags         []string      `json:"tags"`
}

// UpdateRequest partially updates a habit's appearance/organization — the
// only attributes changeable after creation. Each field is a pointer so a
// caller can change just one (e.g. the color picker only ever sends Color)
// without clobbering the others; nil means "leave unchanged."
type UpdateRequest struct {
	Color *Color    `json:"color"`
	Icon  *string   `json:"icon"`
	Tags  *[]string `json:"tags"`
}

// Completion is a single checked-off period for a habit. PeriodStart is
// formatted "2006-01-02" — a plain date, not a timestamp. Count is always 1
// except for an "any N times a week" habit, where it tracks how many of the
// habit's TargetCount check-ins have landed in this period.
type Completion struct {
	HabitID     string         `json:"habit_id"`
	PeriodStart string         `json:"period_start"`
	Count       int            `json:"count"`
	Metadata    map[string]any `json:"metadata"`
}

// SetMetadataRequest is the body of PUT .../completions/{period}/metadata.
type SetMetadataRequest struct {
	Metadata map[string]any `json:"metadata"`
}

// MonthView is everything the tracker needs to render one viewed month: the
// user's habits plus every completion whose period overlaps that month
// (including a weekly row whose Monday falls in the prior month but whose
// week still spans into this one).
type MonthView struct {
	Habits      []Habit      `json:"habits"`
	Completions []Completion `json:"completions"`
}

package focuswall

import "time"

// Color and Category are constrained sets matching the DB CHECK constraints —
// validated in the service layer so a bad value 422s before it reaches Postgres.
type Color string

const (
	ColorYellow Color = "yellow"
	ColorBlue   Color = "blue"
	ColorPink   Color = "pink"
	ColorGreen  Color = "green"
)

func validColor(c Color) bool {
	switch c {
	case ColorYellow, ColorBlue, ColorPink, ColorGreen:
		return true
	}
	return false
}

type Category string

const (
	CategoryPersonal Category = "personal"
	CategoryStudy    Category = "study"
	CategoryUrgent   Category = "urgent"
)

var builtInCategories = map[Category]bool{
	CategoryPersonal: true,
	CategoryStudy:    true,
	CategoryUrgent:   true,
}

func isBuiltInCategory(c Category) bool {
	return builtInCategories[c]
}

// FocusCategory is a user-defined category beyond the three built-ins.
type FocusCategory struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateCategoryRequest struct {
	Name string `json:"name"`
}

// Note is one sticky note on a user's personal Focus Wall.
type Note struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Text      string    `json:"text"`
	Color     Color     `json:"color"`
	Category  Category  `json:"category"`
	PositionX float64   `json:"position_x"`
	PositionY float64   `json:"position_y"`
	Rotation  float64   `json:"rotation"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ─── Request / Response ───────────────────────────────────────────────────────

type CreateRequest struct {
	Text      string   `json:"text"`
	Color     Color    `json:"color"`
	Category  Category `json:"category"`
	PositionX float64  `json:"position_x"`
	PositionY float64  `json:"position_y"`
	Rotation  float64  `json:"rotation"`
}

// UpdateRequest patches a note. Every field is a pointer so "omitted" (no
// change) is distinguishable from a zero value — dragging a note only sends
// PositionX/PositionY, editing text only sends Text.
type UpdateRequest struct {
	Text      *string   `json:"text,omitempty"`
	Color     *Color    `json:"color,omitempty"`
	Category  *Category `json:"category,omitempty"`
	PositionX *float64  `json:"position_x,omitempty"`
	PositionY *float64  `json:"position_y,omitempty"`
	Rotation  *float64  `json:"rotation,omitempty"`
}

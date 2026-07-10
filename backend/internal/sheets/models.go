package sheets

import "time"

// Sheet is a curated problem list — either system-seeded (Striver's A2Z,
// NeetCode 150, Blind 75, Grind 169) or created by a user.
type Sheet struct {
	ID             string    `json:"id"`
	Name           string    `json:"name"`
	Slug           string    `json:"slug"`
	Description    *string   `json:"description,omitempty"`
	Category       *string   `json:"category,omitempty"`
	IsSystem       bool      `json:"is_system"`
	CreatedBy      *string   `json:"created_by,omitempty"`
	SourceSheetIDs []string  `json:"source_sheet_ids,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// UserSheetSummary is one row in the current user's sheet tab bar — a Sheet
// plus the role that put it there.
type UserSheetSummary struct {
	Sheet
	Role string `json:"role"` // "owner" | "subscriber"
}

// SheetItem is one problem within a sheet, joined with the requesting user's
// cross-sheet progress for its topic_tag.
type SheetItem struct {
	ID          string     `json:"id"`
	SheetID     string     `json:"sheet_id"`
	Title       string     `json:"title"`
	TopicTag    string     `json:"topic_tag"`
	Category    *string    `json:"category,omitempty"`
	Difficulty  *string    `json:"difficulty,omitempty"`
	ExternalURL *string    `json:"external_url,omitempty"`
	OrderIndex  int        `json:"order_index"`
	Status      string     `json:"status"` // "todo" | "done" | "revisit"
	SolvedAt    *time.Time `json:"solved_at,omitempty"`
	RevisionAt  *time.Time `json:"revision_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
}

// CreateSheetRequest is the body for POST /api/sheets.
type CreateSheetRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
	Category    *string `json:"category,omitempty"`
}

// CombineSheetsRequest is the body for POST /api/sheets/combine. The new
// sheet's items are the union of every listed sheet's items, deduped by
// topic_tag (first occurrence, in SheetIDs order, wins).
type CombineSheetsRequest struct {
	Name     string   `json:"name"`
	SheetIDs []string `json:"sheet_ids"`
}

// AddItemRequest is the body for POST /api/sheets/:id/items.
type AddItemRequest struct {
	Title       string  `json:"title"`
	Category    *string `json:"category,omitempty"`
	Difficulty  *string `json:"difficulty,omitempty"`
	ExternalURL *string `json:"external_url,omitempty"`
}

// UpdateItemRequest is the body for PATCH /api/sheets/:id/items/:itemId.
// Nil fields are left unchanged.
type UpdateItemRequest struct {
	Title       *string `json:"title,omitempty"`
	Category    *string `json:"category,omitempty"`
	Difficulty  *string `json:"difficulty,omitempty"`
	ExternalURL *string `json:"external_url,omitempty"`
}

// UpdateProgressRequest is the body for PATCH /api/progress/:topic_tag.
type UpdateProgressRequest struct {
	Status string `json:"status"`
}

// SheetItemsResponse is the payload for GET /api/sheets/:slug/items.
type SheetItemsResponse struct {
	Sheet Sheet       `json:"sheet"`
	Items []SheetItem `json:"items"`
}

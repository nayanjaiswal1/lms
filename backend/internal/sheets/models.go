package sheets

import (
	"encoding/json"
	"time"
)

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
	// ItemCount and Topics are only populated by the listing queries
	// (ListPublicSheets, ListUserSheets) — zero-value elsewhere.
	ItemCount int      `json:"item_count"`
	Topics    []string `json:"topics,omitempty"`
}

// UserSheetSummary is one row in the current user's sheet tab bar — a Sheet
// plus the role that put it there and how many of its items the user has
// marked done, for a per-sheet progress indicator.
type UserSheetSummary struct {
	Sheet
	Role        string `json:"role"` // "owner" | "subscriber"
	SolvedCount int    `json:"solved_count"`
}

// SheetPreview is the minimal metadata shown on the share/join page before a
// user decides to subscribe — visible to any authenticated user regardless
// of ownership, unlike GetSheetItems which enforces real access.
type SheetPreview struct {
	Sheet
	IsSubscribed bool `json:"is_subscribed"`
}

// UpdateSheetRequest is the body for PATCH /api/sheets/:id. Nil fields are
// left unchanged.
type UpdateSheetRequest struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
}

// SheetItem is one problem within a sheet, joined with the requesting user's
// cross-sheet progress for its topic_tag.
type SheetItem struct {
	ID          string          `json:"id"`
	SheetID     string          `json:"sheet_id"`
	Title       string          `json:"title"`
	TopicTag    string          `json:"topic_tag"`
	Category    *string         `json:"category,omitempty"`
	Difficulty  *string         `json:"difficulty,omitempty"`
	ExternalURL *string         `json:"external_url,omitempty"`
	OrderIndex  int             `json:"order_index"`
	Status      string          `json:"status"` // "todo" | "done" | "revisit"
	SolvedAt    *time.Time      `json:"solved_at,omitempty"`
	RevisionAt  *time.Time      `json:"revision_at,omitempty"`
	ReviewCount int             `json:"review_count"` // successful "Reviewed" clicks since last freshly marked done
	Notes       json.RawMessage `json:"notes"`        // opaque TipTap JSON, same shape as wiki_pages.content
	IsStarred   bool            `json:"is_starred"`   // per-user bookmark, independent of status
	CreatedAt   time.Time       `json:"created_at"`
}

// CreateSheetRequest is the body for POST /api/sheets.
type CreateSheetRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
	Category    *string `json:"category,omitempty"`
}

// CombineSheetsRequest is the body for POST /api/sheets/combine. The new
// sheet's items are the union of every listed sheet's items, deduped by
// topic_tag (first occurrence, in SheetIDs order, wins), minus anything in
// ExcludeTopicTags. A single sheet ID is allowed — that clones one sheet
// with specific problems left out.
type CombineSheetsRequest struct {
	Name             string   `json:"name"`
	SheetIDs         []string `json:"sheet_ids"`
	ExcludeTopicTags []string `json:"exclude_topic_tags,omitempty"`
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
// SheetID identifies which sheet's revision settings apply — required
// whenever Status is "done", since a topic_tag's progress is shared across
// every sheet that contains it but the growth scheme is per-sheet.
type UpdateProgressRequest struct {
	Status  string `json:"status"`
	SheetID string `json:"sheet_id,omitempty"`
}

// UpdateProgressNotesRequest is the body for PATCH /api/progress/:topic_tag/notes.
type UpdateProgressNotesRequest struct {
	Notes json.RawMessage `json:"notes"`
}

// UpdateProgressStarredRequest is the body for PATCH /api/progress/:topic_tag/star.
type UpdateProgressStarredRequest struct {
	Starred bool `json:"starred"`
}

// UpdateRevisionRequest is the body for PATCH /api/progress/:topic_tag/revision
// — directly sets an already-scheduled revision date to a new one.
type UpdateRevisionRequest struct {
	RevisionAt time.Time `json:"revision_at"`
}

// MarkReviewedRequest is the body for PATCH /api/progress/:topic_tag/review
// — the "I still remember this" action. SheetID selects whose growth scheme
// computes the next, longer interval.
type MarkReviewedRequest struct {
	SheetID string `json:"sheet_id"`
}

// UserSheetSettings is the current user's spaced-repetition configuration
// for one sheet — every sheet a user tracks can use a different base
// interval and growth scheme.
type UserSheetSettings struct {
	BaseRevisionDays int    `json:"base_revision_days"`
	GrowthScheme     string `json:"growth_scheme"` // "doubling" | "ladder" | "linear"
}

// UpdateSheetSettingsRequest is the body for PUT /api/sheets/settings.
type UpdateSheetSettingsRequest struct {
	SheetID          string `json:"sheet_id"`
	BaseRevisionDays int    `json:"base_revision_days"`
	GrowthScheme     string `json:"growth_scheme"`
}

// SheetItemsResponse is the payload for GET /api/sheets/:slug/items.
type SheetItemsResponse struct {
	Sheet Sheet       `json:"sheet"`
	Items []SheetItem `json:"items"`
}

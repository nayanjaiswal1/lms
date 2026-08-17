package journal

import "time"

// Entry is one day's logged learning under a free-typed category ->
// subcategory path (e.g. Backend / Redis).
type Entry struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	EntryDate   string    `json:"entry_date"` // "2006-01-02"
	Category    string    `json:"category"`
	Subcategory string    `json:"subcategory"`
	Title       string    `json:"title"`
	Content     string    `json:"content"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// CreateEntryRequest is the body for POST /api/journal. EntryDate nil/empty
// defaults to today.
type CreateEntryRequest struct {
	EntryDate   *string `json:"entry_date,omitempty"`
	Category    string  `json:"category"`
	Subcategory string  `json:"subcategory"`
	Title       string  `json:"title"`
	Content     string  `json:"content"`
}

// UpdateEntryRequest is the body for PATCH /api/journal/:id. Nil fields are
// left unchanged.
type UpdateEntryRequest struct {
	EntryDate   *string `json:"entry_date,omitempty"`
	Category    *string `json:"category,omitempty"`
	Subcategory *string `json:"subcategory,omitempty"`
	Title       *string `json:"title,omitempty"`
	Content     *string `json:"content,omitempty"`
}

// ListEntriesFilter narrows GET /api/journal / list_journal_entries.
type ListEntriesFilter struct {
	Category    string // exact match, "" = all
	Subcategory string // exact match, "" = all; only meaningful alongside Category
	Search      string // ILIKE over title+content, "" = no filter
}

// CategoryNode is one entry in the caller's category -> subcategories tree,
// backing GET /api/journal/categories and the frontend's nested filter chips.
type CategoryNode struct {
	Category      string   `json:"category"`
	Subcategories []string `json:"subcategories"`
}

// SimilarPair is one edge in the graph view — two of the caller's own
// entries whose titles cleared journalMatchThreshold against each other.
type SimilarPair struct {
	SourceID string `json:"source_id"`
	TargetID string `json:"target_id"`
}

// GraphResponse is the payload for GET /api/journal/graph.
type GraphResponse struct {
	Entries []Entry       `json:"entries"`
	Links   []SimilarPair `json:"links"`
}

// CreateEntryResponse wraps a newly created entry with any similarly-titled
// entries already in the journal (see Repo.FindSimilarEntries), so the
// caller can surface "you've learned something like this before" without a
// second round trip.
type CreateEntryResponse struct {
	Entry          Entry   `json:"entry"`
	SimilarEntries []Entry `json:"similar_entries"`
}

// StructureRequest is the body for POST /api/journal/structure — raw text
// the caller pasted, not yet a journal entry.
type StructureRequest struct {
	Text string `json:"text"`
}

// StructureResponse is the AI's suggested category/subcategory/title, plus
// a cleaned-up/restructured rewrite of the pasted text, for
// StructureRequest.Text — a suggestion only, nothing is saved. The caller
// reviews/edits it and creates the entry via the normal POST /api/journal.
type StructureResponse struct {
	Category    string `json:"category"`
	Subcategory string `json:"subcategory"`
	Title       string `json:"title"`
	Content     string `json:"content"`
}

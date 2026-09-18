package captures

import "time"

// Capture is one ingested screenshot/PDF/link, moving through the
// pending -> processing -> ready -> promoted|dismissed lifecycle (or
// -> failed on any stage error). See docs/captures.md for the full pipeline.
type Capture struct {
	ID              string     `json:"id"`
	UserID          string     `json:"user_id"`
	Type            string     `json:"type"` // image | pdf | link
	StorageKey      *string    `json:"storage_key,omitempty"`
	SourceURL       *string    `json:"source_url,omitempty"`
	Status          string     `json:"status"` // pending | processing | ready | failed | promoted | dismissed
	ExtractedText   *string    `json:"extracted_text,omitempty"`
	Kind            *string    `json:"kind,omitempty"` // note | question, set once ready
	Category        *string    `json:"category,omitempty"`
	Subcategory     *string    `json:"subcategory,omitempty"`
	Title           *string    `json:"title,omitempty"`
	Content         *string    `json:"content,omitempty"`
	JournalEntryID  *string    `json:"journal_entry_id,omitempty"`
	SRSCardID       *string    `json:"srs_card_id,omitempty"`
	ErrorMessage    *string    `json:"error_message,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	ProcessedAt     *time.Time `json:"processed_at,omitempty"`
}

// Status values. "promoted"/"dismissed" are terminal states the review step
// moves a "ready" capture into; "failed" is retryable via RequeueCapture.
const (
	StatusPending    = "pending"
	StatusProcessing = "processing"
	StatusReady      = "ready"
	StatusFailed     = "failed"
	StatusPromoted   = "promoted"
	StatusDismissed  = "dismissed"
)

// Type values.
const (
	TypeImage = "image"
	TypePDF   = "pdf"
	TypeLink  = "link"
	// TypeHTML is raw HTML the caller pasted directly (e.g. copied page
	// source) — text is extracted synchronously at creation time (pure CPU,
	// no network fetch needed), unlike TypeLink which needs the async job to
	// fetch it first.
	TypeHTML = "html"
)

// Kind values, set by the AI structuring step.
const (
	KindNote     = "note"
	KindQuestion = "question"
)

// ListFilter narrows GET /api/captures — the inbox view.
type ListFilter struct {
	Status string // exact match, "" = all
	Limit  int
}

const DefaultListLimit = 100
const MaxListLimit = 500

// CreateJSONRequest is the JSON body for POST /api/captures when the request
// isn't a multipart file upload — one request can capture several links
// and/or several raw-HTML pastes at once (each becomes its own Capture row
// and its own captures.process job, so one bad item never blocks the rest).
type CreateJSONRequest struct {
	URLs []string `json:"urls,omitempty"`
	HTML []string `json:"html,omitempty"`
}

// MaxItemsPerRequest bounds both a JSON request's combined urls+html count
// and a multipart request's file count — a personal capture batch (e.g.
// clearing out a camera roll of screenshots), not an unbounded bulk-import.
const MaxItemsPerRequest = 20

// StructuredSuggestion is what the AI structuring step produced for a
// capture, persisted by Repo.MarkReady.
type StructuredSuggestion struct {
	Kind        string `json:"kind"`
	Category    string `json:"category,omitempty"`
	Subcategory string `json:"subcategory,omitempty"`
	Title       string `json:"title"`
	Content     string `json:"content"`
}

// CaptureDetail wraps a capture with its live-computed similar matches
// (recomputed on every read, not stored — see journal.CreateEntryResponse
// for why: a match found "now" can go stale the moment the user creates
// another entry, so baking it in at MarkReady time would drift).
type CaptureDetail struct {
	Capture        Capture        `json:"capture"`
	SimilarEntries []SimilarMatch `json:"similar_entries"`
}

// SimilarMatch is one existing journal entry or SRS card that cleared the
// similarity threshold against this capture's title — surfaced so the
// reviewer can merge into it instead of creating a near-duplicate.
type SimilarMatch struct {
	Type  string `json:"type"` // journal_entry | srs_card
	ID    string `json:"id"`
	Title string `json:"title"`
}

// PromoteRequest is the body for POST /api/captures/{id}/promote. Fields
// left empty fall back to the AI's own suggestion already stored on the
// capture; MergeIntoID, if set, appends/links into that existing item
// instead of creating a new journal entry / SRS card.
type PromoteRequest struct {
	Category    *string `json:"category,omitempty"`
	Subcategory *string `json:"subcategory,omitempty"`
	Title       *string `json:"title,omitempty"`
	Content     *string `json:"content,omitempty"`
	MergeIntoID string  `json:"merge_into_id,omitempty"`
}

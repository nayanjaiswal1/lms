package diary

import "time"

// Entry is one user's free-form prose entry for one calendar day.
type Entry struct {
	ID         string      `json:"id"`
	UserID     string      `json:"user_id"`
	EntryDate  string      `json:"entry_date"` // "2006-01-02"
	Content    string      `json:"content"`
	Highlights []Highlight `json:"highlights"`
	AnalyzedAt *time.Time  `json:"analyzed_at"`
	CreatedAt  time.Time   `json:"created_at"`
	UpdatedAt  time.Time   `json:"updated_at"`
	// AnalyzedHash is the sha256(content) as of the last completed analysis
	// pass — internal bookkeeping only, never serialized to the API.
	AnalyzedHash string `json:"-"`
}

// HighlightKind classifies one detected span in an entry's content, and what
// it resolved to in the habit/whatnow domains (see Service.Preview/Apply).
type HighlightKind string

const (
	// HighlightHabit marks a sentence describing an existing tracked habit
	// being done today — RefID is that habit's id.
	HighlightHabit HighlightKind = "habit"
	// HighlightTaskDone marks a sentence describing an existing open What
	// Now? task being completed — RefID is that task's id.
	HighlightTaskDone HighlightKind = "task_done"
	// HighlightTaskNew marks a sentence describing a new to-do with no
	// matching existing task — RefID is the newly captured task's id.
	HighlightTaskNew HighlightKind = "task_new"
	// HighlightBuyNew is HighlightTaskNew for a shopping/errand item —
	// captured as a What Now? task tagged "#buy".
	HighlightBuyNew HighlightKind = "buy_new"
)

// Highlight is one AI-detected span of an entry's content.
type Highlight struct {
	Start int           `json:"start"`
	End   int           `json:"end"`
	Text  string        `json:"text"`
	Kind  HighlightKind `json:"kind"`
	// RefID is the habit id (kind=habit) or whatnow task id (kind=task_done/
	// task_new/buy_new) this span resolved to. Empty only if resolution
	// failed and the span was dropped before storage.
	RefID string `json:"ref_id,omitempty"`
	// Metadata is set only for kind=habit, when the habit's type has a
	// structured entry form (gym/sleep/reading/custom) and the AI extracted
	// values for one or more of its fields from this span's text (e.g. a
	// sleep habit's slept_at/woke_up times). Keys are validated against the
	// habit's own field schema before being written — see
	// Service.applyHighlights.
	Metadata map[string]any `json:"metadata,omitempty"`
}

// aiAnalysis is the shape stored in diary_entries.ai_analysis.
type aiAnalysis struct {
	Highlights []Highlight `json:"highlights"`
}

// previewLength bounds EntryPreview.Preview — long enough to recognize the
// day at a glance in a history list, short enough to keep the list payload
// small.
const previewLength = 150

// EntryPreview is one row of GET /api/diary's history list.
type EntryPreview struct {
	ID        string `json:"id"`
	EntryDate string `json:"entry_date"`
	Preview   string `json:"preview"`
}

// ListEntriesResponse is the body of GET /api/diary.
type ListEntriesResponse struct {
	Entries    []EntryPreview `json:"entries"`
	NextCursor *string        `json:"next_cursor"`
}

// UpdateContentRequest is the body of PATCH /api/diary/{date}.
type UpdateContentRequest struct {
	Content string `json:"content"`
}

// AnalyzePreviewRequest is the body of POST /api/diary/{date}/analyze/preview.
type AnalyzePreviewRequest struct {
	Content string `json:"content"`
}

// AnalyzePreviewResponse is the body of POST /api/diary/{date}/analyze/preview
// — detected spans the writer reviews (and may edit or drop) before anything
// is written to the habit/whatnow domains.
type AnalyzePreviewResponse struct {
	Highlights []Highlight `json:"highlights"`
}

// ApplyAnalysisRequest is the body of POST /api/diary/{date}/analyze/apply —
// the reviewer's edited/filtered copy of a prior preview's highlights, e.g.
// with a habit's extracted metadata corrected or an unwanted span removed.
type ApplyAnalysisRequest struct {
	Highlights []Highlight `json:"highlights"`
}

// FixEnglishRequest is the body of POST /api/diary/{date}/fix-english.
type FixEnglishRequest struct {
	Content string `json:"content"`
}

// FixEnglishSegmentKind is one segment's role in the same/del/add diff.
type FixEnglishSegmentKind string

const (
	SegmentSame FixEnglishSegmentKind = "same"
	SegmentDel  FixEnglishSegmentKind = "del"
	SegmentAdd  FixEnglishSegmentKind = "add"
)

// FixEnglishSegment is one piece of the ordered same/del/add diff covering
// the whole reviewed text — see FixEnglishResponse.
type FixEnglishSegment struct {
	Kind FixEnglishSegmentKind `json:"kind"`
	Text string                `json:"text"`
}

// FixEnglishResponse is the body of POST /api/diary/{date}/fix-english. A
// "del" segment is always immediately followed by its "add" replacement, so
// the frontend renders adjacent pairs as strikethrough(red)/insert(green)
// and reconstructs the accepted text by keeping "same" as-is and, per pair,
// either "add" (accepted) or "del" (rejected).
type FixEnglishResponse struct {
	Segments []FixEnglishSegment `json:"segments"`
}

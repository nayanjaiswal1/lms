package highlights

import "time"

// SourceType constrains which content types a highlight can anchor to.
// Assessments are intentionally excluded — AI assist during a live exam is cheating.
type SourceType string

const (
	SourceTypeWikiPage SourceType = "wiki_page"
	SourceTypeLesson   SourceType = "lesson"
	SourceTypeProblem  SourceType = "problem"
)

func validSourceType(s SourceType) bool {
	return s == SourceTypeWikiPage || s == SourceTypeLesson || s == SourceTypeProblem
}

// Highlight is a text selection anchored to a content resource by one user.
// ContextSnippet holds the surrounding paragraph text captured at creation time,
// so the saved-highlights page can display nearby content without re-fetching the source.
// SourceURL is the page path at creation time, used as the "go to source" navigation link.
type Highlight struct {
	ID               string       `json:"id"`
	UserID           string       `json:"user_id"`
	SourceType       SourceType   `json:"source_type"`
	SourceID         string       `json:"source_id"`
	SelectedText     string       `json:"selected_text"`
	TextHash         string       `json:"text_hash"`
	PositionStart    *int         `json:"position_start,omitempty"`
	PositionEnd      *int         `json:"position_end,omitempty"`
	ContextSnippet   *string      `json:"context_snippet,omitempty"`
	SourceURL        *string      `json:"source_url,omitempty"`
	SourceOrphaned   bool         `json:"source_orphaned"`
	SavedForRevision bool         `json:"saved_for_revision"`
	Explanation      *Explanation `json:"explanation,omitempty"`
	CreatedAt        time.Time    `json:"created_at"`
	UpdatedAt        time.Time    `json:"updated_at"`
}

// Explanation is the shared cached AI response for a (text, source_type) pair.
// FromCache indicates whether this was retrieved from the cache or freshly generated.
type Explanation struct {
	ID           string    `json:"id"`
	TextHash     string    `json:"text_hash"`
	SelectedText string    `json:"selected_text"`
	SourceType   string    `json:"source_type"`
	Explanation  string    `json:"explanation"`
	ModelUsed    string    `json:"model_used"`
	ServeCount   int       `json:"serve_count"`
	FromCache    bool      `json:"from_cache"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ─── Request / Response ───────────────────────────────────────────────────────

type CreateRequest struct {
	SourceType      SourceType `json:"source_type"`
	SourceID        string     `json:"source_id"`
	SelectedText    string     `json:"selected_text"`
	PositionStart   *int       `json:"position_start,omitempty"`
	PositionEnd     *int       `json:"position_end,omitempty"`
	ContextSnippet  *string    `json:"context_snippet,omitempty"`
	SourceURL       *string    `json:"source_url,omitempty"`
	SaveForRevision bool       `json:"save_for_revision"`
}

type ExplainRequest struct {
	SelectedText   string     `json:"selected_text"`
	SourceType     SourceType `json:"source_type"`
	SourceID       string     `json:"source_id"`
	PositionStart  *int       `json:"position_start,omitempty"`
	PositionEnd    *int       `json:"position_end,omitempty"`
	ContextSnippet *string    `json:"context_snippet,omitempty"`
	SourceURL      *string    `json:"source_url,omitempty"`
}

type ExplainResponse struct {
	HighlightID string       `json:"highlight_id"`
	Explanation *Explanation `json:"explanation"`
}

type ToggleRevisionRequest struct {
	SaveForRevision bool `json:"save_for_revision"`
}

type AnalyticsEntry struct {
	TextHash     string    `json:"text_hash"`
	SelectedText string    `json:"selected_text"`
	SourceType   string    `json:"source_type"`
	ServeCount   int       `json:"serve_count"`
	ModelUsed    string    `json:"model_used"`
	CreatedAt    time.Time `json:"created_at"`
}

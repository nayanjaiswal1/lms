package journal

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/whatnow"
)

// Handler exposes the learning journal domain over HTTP.
type Handler struct {
	repo     *Repo
	provider ai.LLMProvider
	tasks    *whatnow.Repo
}

// NewHandler constructs the journal handler from a connection pool and the
// shared LLM provider (used only by StructureEntry). It also stands up a
// whatnow.Repo over the same pool, used only to read the caller's completed
// What Now? tasks for the day-timeline merge in ListEntries.
func NewHandler(pool *pgxpool.Pool, provider ai.LLMProvider) *Handler {
	return &Handler{repo: NewRepo(pool), provider: provider, tasks: whatnow.NewRepo(pool)}
}

// ErrAIUnavailable is returned by StructureEntry when no LLM provider is configured.
var ErrAIUnavailable = errors.New("journal: AI provider not available")

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:      {Status: http.StatusNotFound, Message: "Not found."},
	ErrAIUnavailable: {Status: http.StatusServiceUnavailable, Message: "AI provider is not configured."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

const entryDateFormat = "2006-01-02"

// normalizeEntryDate turns an empty pointer into nil (so the repo's SQL
// COALESCE picks CURRENT_DATE/leaves the column unchanged) and validates a
// non-empty one parses as entryDateFormat, returning a field error otherwise.
func normalizeEntryDate(p *string) (*string, string) {
	if p == nil || *p == "" {
		return nil, ""
	}
	if _, err := time.Parse(entryDateFormat, *p); err != nil {
		return nil, "entry_date must be in YYYY-MM-DD format."
	}
	return p, ""
}

// ListEntries handles GET /api/journal. The response merges in the caller's
// completed What Now? tasks, each projected as a read-only entry on the day
// it was finished (see completedTaskEntries) — one unified day timeline,
// no separate "task view" round trip needed.
func (h *Handler) ListEntries(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	filter := ListEntriesFilter{
		Category:    q.Get("category"),
		Subcategory: q.Get("subcategory"),
		Search:      q.Get("q"),
	}
	entries, err := h.repo.ListEntries(r.Context(), claims.UserID, filter)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	tasks, err := h.tasks.ListCompletedTasks(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, fmt.Errorf("journal: list completed tasks: %w", err))
		return
	}
	entries = append(entries, completedTaskEntries(tasks, filter, claims.UserID)...)
	sort.SliceStable(entries, func(i, j int) bool { return entries[i].EntryDate > entries[j].EntryDate })

	httputil.WriteJSON(w, http.StatusOK, entries)
}

// completedTaskEntries projects each done What Now? task into a read-only
// Entry on the day its CompletedAt falls, applying the same list filters the
// real entries got — a task has no real subcategory, so any Subcategory
// filter excludes tasks entirely (no match is possible), and a Category
// filter only keeps tasks when it's exactly "Task".
func completedTaskEntries(tasks []whatnow.Task, filter ListEntriesFilter, userID string) []Entry {
	if filter.Subcategory != "" {
		return nil
	}
	if filter.Category != "" && filter.Category != "Task" {
		return nil
	}
	search := strings.ToLower(filter.Search)

	out := make([]Entry, 0, len(tasks))
	for _, t := range tasks {
		if t.CompletedAt == "" {
			continue
		}
		completedAt, err := time.Parse(time.RFC3339, t.CompletedAt)
		if err != nil {
			continue
		}
		if search != "" && !strings.Contains(strings.ToLower(t.Title), search) {
			continue
		}
		subcategory := t.Category
		if subcategory == "" {
			subcategory = "Completed"
		}
		out = append(out, Entry{
			ID:           "task:" + t.ID,
			UserID:       userID,
			EntryDate:    completedAt.Format(entryDateFormat),
			Category:     "Task",
			Subcategory:  subcategory,
			Title:        t.Title,
			CreatedAt:    completedAt,
			UpdatedAt:    completedAt,
			Source:       "task",
			SourceTaskID: t.ID,
		})
	}
	return out
}

// ListCategories handles GET /api/journal/categories.
func (h *Handler) ListCategories(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	categories, err := h.repo.ListCategories(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, categories)
}

// GetGraph handles GET /api/journal/graph — every entry plus the pairs whose
// titles matched, for the mind-map view. Unfiltered by category/search; the
// frontend fetches this once and dims non-matching nodes client-side rather
// than re-fetching (and re-laying-out the canvas) on every keystroke.
func (h *Handler) GetGraph(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	entries, err := h.repo.ListEntries(r.Context(), claims.UserID, ListEntriesFilter{})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	links, err := h.repo.ListSimilarPairs(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, GraphResponse{Entries: entries, Links: links})
}

// GetEntry handles GET /api/journal/:id.
func (h *Handler) GetEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	entry, err := h.repo.GetEntry(r.Context(), claims.UserID, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entry)
}

// CreateEntry handles POST /api/journal. The response includes any of the
// caller's own past entries with a closely-matching title (see
// Repo.FindSimilarEntries), so the client can surface "you've learned
// something like this before" right when it's actionable.
func (h *Handler) CreateEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateEntryRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	fieldErrors := map[string]string{}
	req.Title = strings.TrimSpace(req.Title)
	req.Category = strings.TrimSpace(req.Category)
	req.Subcategory = strings.TrimSpace(req.Subcategory)
	if req.Title == "" || len(req.Title) > 200 {
		fieldErrors["title"] = "title is required and must be at most 200 characters."
	}
	if req.Category == "" || len(req.Category) > 60 {
		fieldErrors["category"] = "category is required and must be at most 60 characters."
	}
	if req.Subcategory == "" || len(req.Subcategory) > 60 {
		fieldErrors["subcategory"] = "subcategory is required and must be at most 60 characters."
	}
	if req.Content == "" || len(req.Content) > 20000 {
		fieldErrors["content"] = "content is required and must be at most 20000 characters."
	}
	entryDate, dateErr := normalizeEntryDate(req.EntryDate)
	if dateErr != "" {
		fieldErrors["entry_date"] = dateErr
	}
	req.EntryDate = entryDate
	if len(fieldErrors) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fieldErrors)
		return
	}

	entry, err := h.repo.CreateEntry(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	similar, err := h.repo.FindSimilarEntries(r.Context(), claims.UserID, entry.Title, entry.ID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, CreateEntryResponse{Entry: entry, SimilarEntries: similar})
}

// UpdateEntry handles PATCH /api/journal/:id.
func (h *Handler) UpdateEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")

	var req UpdateEntryRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	fieldErrors := map[string]string{}
	if req.Title != nil {
		trimmed := strings.TrimSpace(*req.Title)
		if trimmed == "" || len(trimmed) > 200 {
			fieldErrors["title"] = "title must be 1-200 characters."
		}
		req.Title = &trimmed
	}
	if req.Category != nil {
		trimmed := strings.TrimSpace(*req.Category)
		if trimmed == "" || len(trimmed) > 60 {
			fieldErrors["category"] = "category must be 1-60 characters."
		}
		req.Category = &trimmed
	}
	if req.Subcategory != nil {
		trimmed := strings.TrimSpace(*req.Subcategory)
		if trimmed == "" || len(trimmed) > 60 {
			fieldErrors["subcategory"] = "subcategory must be 1-60 characters."
		}
		req.Subcategory = &trimmed
	}
	if req.Content != nil && (*req.Content == "" || len(*req.Content) > 20000) {
		fieldErrors["content"] = "content must be 1-20000 characters."
	}
	entryDate, dateErr := normalizeEntryDate(req.EntryDate)
	if dateErr != "" {
		fieldErrors["entry_date"] = dateErr
	}
	req.EntryDate = entryDate
	if len(fieldErrors) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fieldErrors)
		return
	}

	entry, err := h.repo.UpdateEntry(r.Context(), claims.UserID, id, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entry)
}

// MergeEntries handles POST /api/journal/:id/merge — {id} is kept and has
// req.OtherID's content appended onto it; req.OtherID is deleted. Both must
// belong to the caller and share the same entry_date (merging across days
// isn't what "merge cards for a day" means).
func (h *Handler) MergeEntries(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	keepID := chi.URLParam(r, "id")

	var req MergeEntriesRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	req.OtherID = strings.TrimSpace(req.OtherID)
	if req.OtherID == "" || req.OtherID == keepID {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"other_id": "other_id is required and must differ from the entry being kept.",
		})
		return
	}

	keep, err := h.repo.GetEntry(r.Context(), claims.UserID, keepID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	other, err := h.repo.GetEntry(r.Context(), claims.UserID, req.OtherID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if keep.EntryDate != other.EntryDate {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"other_id": "Both entries must be on the same day to merge.",
		})
		return
	}

	kept, removed, err := h.repo.MergeEntries(r.Context(), claims.UserID, keepID, req.OtherID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, MergeEntriesResponse{Entry: kept, Removed: removed})
}

// DeleteEntry handles DELETE /api/journal/:id.
func (h *Handler) DeleteEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.DeleteEntry(r.Context(), claims.UserID, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

const (
	structureTextMinLength = 20
	structureTextMaxLength = 20000
)

// StructureEntry handles POST /api/journal/structure. Given raw pasted
// text, it asks the LLM to suggest a category/subcategory/title and a
// cleaned-up rewrite of the text — nothing is written to the database
// here; the caller reviews the suggestion (and can still edit it) before
// creating the entry via the normal POST /api/journal.
func (h *Handler) StructureEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req StructureRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	trimmed := strings.TrimSpace(req.Text)
	if len(trimmed) < structureTextMinLength || len(trimmed) > structureTextMaxLength {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"text": fmt.Sprintf("text must be %d-%d characters.", structureTextMinLength, structureTextMaxLength),
		})
		return
	}

	if !h.provider.Available() {
		writeDomainError(w, ErrAIUnavailable)
		return
	}

	categories, err := h.repo.ListCategories(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	resp, err := h.provider.Complete(r.Context(), ai.CompletionRequest{
		SystemPrompt: ai.JournalStructureSystemPrompt,
		UserPrompt:   buildStructureUserPrompt(trimmed, categories),
		MaxTokens:    4096,
		Temperature:  0.3,
		JSONMode:     true,
	})
	if err != nil {
		writeDomainError(w, fmt.Errorf("journal: call AI: %w", err))
		return
	}

	var parsed StructureResponse
	if err := json.Unmarshal([]byte(resp.Content), &parsed); err != nil {
		writeDomainError(w, fmt.Errorf("journal: parse AI structure response: %w", err))
		return
	}

	parsed.Category = clampField(parsed.Category, 60)
	parsed.Subcategory = clampField(parsed.Subcategory, 60)
	parsed.Title = clampField(parsed.Title, 200)
	// A blank rewrite (AI omitted it, or clamping emptied whitespace-only
	// output) falls back to the original pasted text rather than handing
	// the caller an entry with no content.
	parsed.Content = clampField(parsed.Content, 20000)
	if parsed.Content == "" {
		parsed.Content = trimmed
	}
	if parsed.Category == "" || parsed.Subcategory == "" || parsed.Title == "" {
		writeDomainError(w, fmt.Errorf("journal: AI structure response missing required fields"))
		return
	}

	httputil.WriteJSON(w, http.StatusOK, parsed)
}

// buildStructureUserPrompt lists the caller's existing category/subcategory
// pairs (so the AI can reuse one instead of inventing a near-duplicate),
// then the pasted text itself — the full validated text (already capped at
// structureTextMaxLength), not further truncated, since the AI needs the
// whole thing to rewrite it faithfully rather than just enough to classify
// it. It arrived as clipboard text/plain on the frontend, so no HTML can be
// embedded in it.
func buildStructureUserPrompt(text string, categories []CategoryNode) string {
	var sb strings.Builder
	if len(categories) > 0 {
		sb.WriteString("Existing category / subcategory pairs:\n")
		for _, c := range categories {
			for _, sc := range c.Subcategories {
				fmt.Fprintf(&sb, "- %s / %s\n", c.Category, sc)
			}
		}
		sb.WriteString("\n")
	}
	sb.WriteString("Pasted text:\n")
	sb.WriteString(text)
	return sb.String()
}

// clampField trims whitespace and caps length so a slightly-over-limit AI
// response degrades to a truncated value instead of failing CreateEntry's
// own length validation later.
func clampField(s string, maxLen int) string {
	s = strings.TrimSpace(s)
	if len(s) > maxLen {
		s = strings.TrimSpace(s[:maxLen])
	}
	return s
}

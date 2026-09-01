package diary

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/whatnow"
)

// Handler exposes the diary domain over HTTP.
type Handler struct {
	repo    *Repo
	service *Service
}

// NewHandler constructs the diary handler. It stands up its own
// habit.Service/whatnow.Service over the shared pool — both are stateless
// wrappers (Service holds only a *Repo), the same pattern
// journal.NewHandler already uses for its own whatnow.Repo, so this doesn't
// need the router's existing habit/whatnow instances threaded through.
func NewHandler(pool *pgxpool.Pool, provider ai.LLMProvider) *Handler {
	repo := NewRepo(pool)
	svc := NewService(repo, provider, habit.NewService(habit.NewRepo(pool)), whatnow.NewService(whatnow.NewRepo(pool)))
	return &Handler{repo: repo, service: svc}
}

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
const maxContentLength = 20000

func validateDate(w http.ResponseWriter, date string) bool {
	if _, err := time.Parse(entryDateFormat, date); err != nil {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"date": "date must be in YYYY-MM-DD format.",
		})
		return false
	}
	return true
}

// GetToday handles GET /api/diary/today — gets or creates the caller's
// entry for the current server date.
func (h *Handler) GetToday(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	today := time.Now().Format(entryDateFormat)
	entry, err := h.repo.GetOrCreateByDate(r.Context(), claims.UserID, today)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entry)
}

// GetByDate handles GET /api/diary/{date}.
func (h *Handler) GetByDate(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	date := chi.URLParam(r, "date")
	if !validateDate(w, date) {
		return
	}
	entry, err := h.repo.GetByDate(r.Context(), claims.UserID, date)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entry)
}

// ListEntries handles GET /api/diary?from=&to=&cursor=&limit=.
func (h *Handler) ListEntries(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	from, to, cursor := q.Get("from"), q.Get("to"), q.Get("cursor")
	for _, v := range []string{from, to, cursor} {
		if v != "" && !validateDate(w, v) {
			return
		}
	}
	limit := normalizeLimit(0)
	if raw := q.Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"limit": "limit must be an integer."})
			return
		}
		limit = normalizeLimit(n)
	}

	entries, err := h.repo.ListEntries(r.Context(), claims.UserID, from, to, cursor, limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	resp := ListEntriesResponse{Entries: entries}
	if len(entries) == limit {
		next := entries[len(entries)-1].EntryDate
		resp.NextCursor = &next
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
}

func normalizeLimit(n int) int {
	if n <= 0 || n > maxListLimit {
		return defaultListLimit
	}
	return n
}

// UpdateContent handles PATCH /api/diary/{date} — upserts the day's entry
// content. Analysis is triggered separately by the writer via AnalyzePreview/
// AnalyzeApply below, not automatically on every save.
func (h *Handler) UpdateContent(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	date := chi.URLParam(r, "date")
	if !validateDate(w, date) {
		return
	}
	var req UpdateContentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.Content) > maxContentLength {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"content": fmt.Sprintf("content must be at most %d characters.", maxContentLength),
		})
		return
	}

	existing, err := h.repo.GetOrCreateByDate(r.Context(), claims.UserID, date)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	entry, err := h.repo.UpdateContent(r.Context(), claims.UserID, existing.ID, req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, entry)
}

// AnalyzePreview handles POST /api/diary/{date}/analyze/preview — a
// synchronous, unpersisted habit/task detection pass over the posted
// content (the writer's current text, which may not be saved yet — same
// convention as FixEnglish). Nothing is written to the habit/whatnow domains
// here; the caller reviews the returned highlights, edits or drops any of
// them, and POSTs the result to AnalyzeApply below.
func (h *Handler) AnalyzePreview(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	date := chi.URLParam(r, "date")
	if !validateDate(w, date) {
		return
	}
	var req AnalyzePreviewRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Content == "" || len(req.Content) > maxContentLength {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"content": fmt.Sprintf("content is required and must be at most %d characters.", maxContentLength),
		})
		return
	}

	highlights, err := h.service.Preview(r.Context(), claims.UserID, date, req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, AnalyzePreviewResponse{Highlights: highlights})
}

// AnalyzeApply handles POST /api/diary/{date}/analyze/apply — commits the
// writer-reviewed highlight list from a prior AnalyzePreview: applies each
// kept span's mutation (habit completion + any extracted metadata, task
// completion, new task capture) and persists the resolved list on the day's
// saved entry.
func (h *Handler) AnalyzeApply(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	date := chi.URLParam(r, "date")
	if !validateDate(w, date) {
		return
	}
	var req ApplyAnalysisRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	entry, err := h.repo.GetByDate(r.Context(), claims.UserID, date)
	if err != nil {
		writeDomainError(w, err)
		return
	}

	if _, err := h.service.Apply(r.Context(), entry, req.Highlights); err != nil {
		writeDomainError(w, err)
		return
	}

	// Re-fetch rather than patching entry in place — Apply's SaveAnalysis
	// also stamps analyzed_at/analyzed_hash in the DB, and the response
	// should reflect exactly what's now stored.
	updated, err := h.repo.GetByDate(r.Context(), claims.UserID, date)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

// FixEnglish handles POST /api/diary/{date}/fix-english — a synchronous,
// unpersisted grammar/spelling diff of the posted content. Nothing is saved
// here; the caller PATCHes the resolved text back through UpdateContent.
func (h *Handler) FixEnglish(w http.ResponseWriter, r *http.Request) {
	_, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	date := chi.URLParam(r, "date")
	if !validateDate(w, date) {
		return
	}
	var req FixEnglishRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Content == "" || len(req.Content) > maxContentLength {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"content": fmt.Sprintf("content is required and must be at most %d characters.", maxContentLength),
		})
		return
	}

	segments, err := h.service.FixEnglish(r.Context(), req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, FixEnglishResponse{Segments: segments})
}

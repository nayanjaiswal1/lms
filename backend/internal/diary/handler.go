package diary

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the diary domain over HTTP.
type Handler struct {
	repo    *Repo
	service *Service
	habits  *habit.Service
}

// NewHandler constructs the diary handler. It stands up its own
// habit.Service/courses.Repo over the shared pool — both are stateless
// wrappers, the same pattern journal.NewHandler already uses for its own
// whatnow.Repo, so this doesn't need the router's existing instances
// threaded through. Diary has no dependency on internal/whatnow.
func NewHandler(pool *pgxpool.Pool, provider ai.LLMProvider) *Handler {
	repo := NewRepo(pool)
	habits := habit.NewService(habit.NewRepo(pool))
	svc := NewService(repo, provider, habits, courses.NewRepo(pool))
	return &Handler{repo: repo, service: svc, habits: habits}
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
	resp, err := h.withGoals(r.Context(), claims.UserID, entry)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
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
	resp, err := h.withGoals(r.Context(), claims.UserID, entry)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
}

// withGoals joins entry with the writer's full goal structure — every habit,
// grouped by cadence, with whether it's done for the period covering entry's
// date — a read-only display projection (see EntryResponse) reused by
// GetToday and GetByDate so the diary page can show daily/weekly/monthly
// goal planning without a separate trip to the habit tracker.
func (h *Handler) withGoals(ctx context.Context, userID string, entry Entry) (EntryResponse, error) {
	day, err := time.Parse(entryDateFormat, entry.EntryDate)
	if err != nil {
		return EntryResponse{}, fmt.Errorf("diary: parse entry date: %w", err)
	}
	monthView, err := h.habits.MonthView(ctx, userID, day.Format("2006-01"))
	if err != nil {
		return EntryResponse{}, fmt.Errorf("diary: load habits for goals section: %w", err)
	}
	completedPeriods := make(map[string]bool, len(monthView.Completions))
	for _, c := range monthView.Completions {
		completedPeriods[c.HabitID+"|"+c.PeriodStart] = true
	}
	goals := make([]GoalStatus, 0, len(monthView.Habits))
	for _, hb := range monthView.Habits {
		period := alignPeriod(day, hb.Cadence).Format(entryDateFormat)
		goals = append(goals, GoalStatus{
			ID: hb.ID, Name: hb.Name, Cadence: string(hb.Cadence),
			Done: completedPeriods[hb.ID+"|"+period],
		})
	}
	return EntryResponse{Entry: entry, Goals: goals}, nil
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

	if _, err := h.service.Apply(r.Context(), entry, claims.OrgID, req.Highlights); err != nil {
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

// Review handles POST /api/diary/{date}/review — the combined "AI" button:
// FixEnglish then Analyze-Preview over the corrected text, in one call.
// Synchronous and unpersisted, same as FixEnglish/AnalyzePreview; the caller
// still PATCHes the corrected content and POSTs to AnalyzeApply separately
// once they've reviewed the highlights.
func (h *Handler) Review(w http.ResponseWriter, r *http.Request) {
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

	content, highlights, err := h.service.ReviewDump(r.Context(), claims.UserID, claims.OrgID, date, req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, ReviewResponse{Content: content, Highlights: highlights})
}

// ─── Diary-owned tasks ──────────────────────────────────────────────────────

// ListTasks handles GET /api/diary/tasks?tag=&done=.
func (h *Handler) ListTasks(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	var done *bool
	if raw := q.Get("done"); raw != "" {
		parsed, err := strconv.ParseBool(raw)
		if err != nil {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"done": "done must be true or false."})
			return
		}
		done = &parsed
	}
	tasks, err := h.repo.ListTasks(r.Context(), claims.UserID, q.Get("tag"), done)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, TaskListResponse{Tasks: tasks})
}

// CreateTask handles POST /api/diary/tasks — a manually-added todo/buy item
// (AI-captured ones go through AnalyzeApply instead).
func (h *Handler) CreateTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req TaskCreateRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if len(req.Title) == 0 || len(req.Title) > 300 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"title": "title must be 1-300 characters."})
		return
	}
	kind := req.Kind
	if kind == "" {
		kind = TaskKindTodo
	}
	if kind != TaskKindTodo && kind != TaskKindBuy {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"kind": "kind must be 'todo' or 'buy'."})
		return
	}
	task, err := h.repo.CreateTask(r.Context(), claims.UserID, req.Title, string(kind), nil, req.Tags)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, task)
}

// PatchTask handles PATCH /api/diary/tasks/{id} — toggling done, editing
// title/tags. Nil fields are left unchanged.
func (h *Handler) PatchTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	id := chi.URLParam(r, "id")
	var req TaskPatchRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	task, err := h.repo.UpdateTask(r.Context(), claims.UserID, id, req.Title, req.Tags)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	if req.Done != nil {
		task, err = h.repo.SetTaskDone(r.Context(), claims.UserID, id, *req.Done)
		if err != nil {
			writeDomainError(w, err)
			return
		}
	}
	httputil.WriteJSON(w, http.StatusOK, task)
}

// DeleteTask handles DELETE /api/diary/tasks/{id}.
func (h *Handler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.DeleteTask(r.Context(), claims.UserID, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

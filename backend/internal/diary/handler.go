package diary

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/whatnow"
)

// Handler exposes the diary domain over HTTP.
type Handler struct {
	repo     *Repo
	service  *Service
	pool     *pgxpool.Pool
	registry *jobs.Registry
}

// NewHandler constructs the diary handler. It stands up its own
// habit.Service/whatnow.Service over the shared pool — both are stateless
// wrappers (Service holds only a *Repo), the same pattern
// journal.NewHandler already uses for its own whatnow.Repo, so this doesn't
// need the router's existing habit/whatnow instances threaded through.
func NewHandler(pool *pgxpool.Pool, provider ai.LLMProvider, jobsRegistry *jobs.Registry) *Handler {
	repo := NewRepo(pool)
	svc := NewService(repo, provider, habit.NewService(habit.NewRepo(pool)), whatnow.NewService(whatnow.NewRepo(pool)))
	return &Handler{repo: repo, service: svc, pool: pool, registry: jobsRegistry}
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

// llmJobHandler mirrors handlers.HandlerLLM ("llm.task",
// internal/jobs/handlers/constants.go) — duplicated locally rather than
// imported, since jobs/handlers imports this package (for the diary_analyze
// job body) and importing back would cycle. Same precedent as
// internal/digest and internal/notifications' own local emailSendHandler
// consts mirroring handlers.HandlerEmailSend.
const llmJobHandler = "llm.task"

// llmJobPayload mirrors handlers.LLMPayload's wire shape (task/entity_id) —
// duplicated for the same import-cycle reason as llmJobHandler above.
type llmJobPayload struct {
	Task     string `json:"task"`
	EntityID string `json:"entity_id"`
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
// content and, if it actually changed since the last completed analysis
// pass, enqueues a diary_analyze background job (see
// internal/jobs/handlers/llm.go) to detect habit/task mentions and write
// them into the caller's real habit/whatnow records.
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

	if hash := ContentHash(entry.Content); hash != existing.AnalyzedHash {
		_, enqErr := jobs.Enqueue(r.Context(), h.pool, h.registry, jobs.EnqueueParams{
			Handler:  llmJobHandler,
			Priority: jobs.PriorityLow,
			Payload:  llmJobPayload{Task: "diary_analyze", EntityID: entry.ID},
		})
		if enqErr != nil && !errors.Is(enqErr, jobs.ErrDuplicateKey) {
			// Best-effort enrichment — the entry itself already saved, so a
			// failed enqueue doesn't fail the request.
			slog.ErrorContext(r.Context(), "diary: enqueue analyze job", "entry_id", entry.ID, "error", enqErr)
		}
	}

	httputil.WriteJSON(w, http.StatusOK, entry)
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

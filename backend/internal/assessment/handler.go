package assessment

import (
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/jobs"
)

// Handler exposes the assessment domain over HTTP. It owns the service and repo.
type Handler struct {
	repo        *Repo
	service     *Service
	pool        *pgxpool.Pool
	jobRegistry *jobs.Registry
}

// NewHandler builds the assessment HTTP handler and its dependency graph.
func NewHandler(repo *Repo, service *Service, pool *pgxpool.Pool, jobRegistry *jobs.Registry) *Handler {
	return &Handler{repo: repo, service: service, pool: pool, jobRegistry: jobRegistry}
}

// ─── shared helpers ──────────────────────────────────────────────────────────

// ctxClaims pulls the authenticated claims or writes 401 and returns false.
func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

// writeDomainError maps domain/service errors to HTTP responses.
func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrNotDraft):
		httputil.WriteError(w, http.StatusConflict, "Only draft assessments can be edited.")
	case errors.Is(err, ErrConflict):
		httputil.WriteError(w, http.StatusConflict, "This action conflicts with the current state.")
	case errors.Is(err, ErrNotAssigned):
		httputil.WriteError(w, http.StatusForbidden, "This assessment is not assigned to you.")
	case errors.Is(err, ErrNotAttemptOwner):
		httputil.WriteError(w, http.StatusForbidden, "This attempt belongs to another user.")
	case errors.Is(err, ErrNotOpen):
		httputil.WriteError(w, http.StatusConflict, "This assessment is not open for attempts.")
	case errors.Is(err, ErrNoAttemptsLeft):
		httputil.WriteError(w, http.StatusConflict, "You have no attempts remaining.")
	case errors.Is(err, ErrAttemptClosed):
		httputil.WriteError(w, http.StatusConflict, "This attempt has already been submitted.")
	case errors.Is(err, ErrAttemptExpired):
		httputil.WriteError(w, http.StatusConflict, "Your time for this attempt has expired.")
	case errors.Is(err, ErrNoQuestions):
		httputil.WriteError(w, http.StatusUnprocessableEntity, "Add at least one question first.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

var slugInvalid = regexp.MustCompile(`[^a-z0-9]+`)

// slugify produces a URL-safe slug and appends a short random suffix to avoid
// per-org collisions on similar titles.
func slugify(s string) string {
	base := slugInvalid.ReplaceAllString(strings.ToLower(strings.TrimSpace(s)), "-")
	base = strings.Trim(base, "-")
	if base == "" {
		base = "item"
	}
	if len(base) > 60 {
		base = base[:60]
	}
	return base + "-" + shortID()
}

// chiURLParam reads a path parameter; thin wrapper kept for call-site brevity.
func chiURLParam(r *http.Request, key string) string {
	return chi.URLParam(r, key)
}

func queryInt(r *http.Request, key string, def int) int {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

// ─── Categories ──────────────────────────────────────────────────────────────

type categoryRequest struct {
	Name     string  `json:"name"`
	ParentID *string `json:"parent_id"`
}

func (h *Handler) CreateCategory(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req categoryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"name": "Name is required."})
		return
	}
	cat, err := h.repo.CreateCategory(r.Context(), claims.OrgID, req.ParentID, req.Name, slugify(req.Name))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, cat)
}

func (h *Handler) ListCategories(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	cats, err := h.repo.ListCategories(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"categories": cats})
}

// ─── Questions ───────────────────────────────────────────────────────────────

type questionRequest struct {
	CategoryID    *string         `json:"category_id"`
	Type          string          `json:"type"`
	Title         string          `json:"title"`
	Difficulty    string          `json:"difficulty"`
	DefaultPoints float64         `json:"default_points"`
	Tags          []string        `json:"tags"`
	Content       json.RawMessage `json:"content"`
}

// validate checks the question request and normalises gradable content. For MCQ
// it assigns option IDs and requires at least one correct answer; for coding it
// requires at least one test case and assigns case IDs.
func (req *questionRequest) validate() (json.RawMessage, map[string]string) {
	fields := map[string]string{}
	if strings.TrimSpace(req.Title) == "" {
		fields["title"] = "Title is required."
	}
	validQTypes := map[string]bool{QuestionTypeMCQ: true, QuestionTypeCoding: true, QuestionTypeSubjective: true}
	if !validQTypes[req.Type] {
		fields["type"] = "Type must be 'mcq', 'coding', or 'subjective'."
	}
	if req.Difficulty == "" {
		req.Difficulty = "intermediate"
	} else if !contains(ValidDifficulties, req.Difficulty) {
		fields["difficulty"] = "Invalid difficulty."
	}
	if req.DefaultPoints < 0 {
		fields["default_points"] = "Points cannot be negative."
	}
	if req.DefaultPoints == 0 {
		req.DefaultPoints = 1
	}
	if len(fields) > 0 {
		return nil, fields
	}

	switch req.Type {
	case QuestionTypeMCQ:
		var c MCQContent
		if err := json.Unmarshal(req.Content, &c); err != nil {
			fields["content"] = "Invalid MCQ content."
			return nil, fields
		}
		if len(c.Options) < 2 {
			fields["content"] = "Provide at least two options."
			return nil, fields
		}
		hasCorrect := false
		for i := range c.Options {
			if strings.TrimSpace(c.Options[i].ID) == "" {
				c.Options[i].ID = newID()
			}
			if c.Options[i].IsCorrect {
				hasCorrect = true
			}
		}
		if !hasCorrect {
			fields["content"] = "Mark at least one correct option."
			return nil, fields
		}
		raw, _ := json.Marshal(c)
		return raw, nil

	case QuestionTypeCoding:
		var c CodingContent
		if err := json.Unmarshal(req.Content, &c); err != nil {
			fields["content"] = "Invalid coding content."
			return nil, fields
		}
		if len(c.TestCases) == 0 {
			fields["content"] = "Provide at least one test case."
			return nil, fields
		}
		if len(c.Languages) == 0 {
			fields["content"] = "Specify at least one allowed language."
			return nil, fields
		}
		for i := range c.TestCases {
			if strings.TrimSpace(c.TestCases[i].ID) == "" {
				c.TestCases[i].ID = newID()
			}
			if c.TestCases[i].Weight <= 0 {
				c.TestCases[i].Weight = 1
			}
		}
		if c.TimeLimitMs <= 0 {
			c.TimeLimitMs = 2000
		}
		if c.MemoryLimitKb <= 0 {
			c.MemoryLimitKb = 262144
		}
		raw, _ := json.Marshal(c)
		return raw, nil

	case QuestionTypeSubjective:
		var c SubjectiveContent
		if err := json.Unmarshal(req.Content, &c); err != nil {
			fields["content"] = "Invalid subjective content."
			return nil, fields
		}
		if strings.TrimSpace(c.Prompt) == "" {
			fields["content"] = "Prompt is required."
			return nil, fields
		}
		if c.ExpectedTopics == nil {
			c.ExpectedTopics = []string{}
		}
		if c.Skills == nil {
			c.Skills = []string{}
		}
		raw, _ := json.Marshal(c)
		return raw, nil
	}
	return nil, fields
}

func (h *Handler) CreateQuestion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req questionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	content, fields := req.validate()
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	q := Question{
		OrgID:         claims.OrgID,
		CategoryID:    req.CategoryID,
		Type:          req.Type,
		Title:         req.Title,
		Difficulty:    req.Difficulty,
		DefaultPoints: req.DefaultPoints,
		Tags:          normaliseTags(req.Tags),
		CreatedBy:     claims.UserID,
	}
	created, err := h.repo.CreateQuestion(r.Context(), q, content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, created)
}

func (h *Handler) UpdateQuestion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	id := chiURLParam(r, "questionID")
	var req questionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	// Type cannot change after creation; load existing to fix it for validation.
	existing, err := h.repo.GetQuestion(r.Context(), claims.OrgID, id)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	req.Type = existing.Type

	var content json.RawMessage
	if len(req.Content) > 0 {
		c, fields := req.validate()
		if len(fields) > 0 {
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
			return
		}
		content = c
	}

	q := Question{
		ID:            id,
		CategoryID:    req.CategoryID,
		Title:         req.Title,
		Difficulty:    req.Difficulty,
		DefaultPoints: req.DefaultPoints,
		Tags:          normaliseTags(req.Tags),
	}
	updated, err := h.repo.UpdateQuestion(r.Context(), claims.OrgID, q, content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, updated)
}

func (h *Handler) GetQuestion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	q, err := h.repo.GetQuestion(r.Context(), claims.OrgID, chiURLParam(r, "questionID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, q)
}

func (h *Handler) ListQuestions(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	var tags []string
	if t := q.Get("tags"); t != "" {
		tags = strings.Split(t, ",")
	}
	filter := QuestionFilter{
		Type:       q.Get("type"),
		CategoryID: q.Get("category_id"),
		Difficulty: q.Get("difficulty"),
		Tags:       tags,
		Search:     q.Get("search"),
		Status:     q.Get("status"),
		Limit:      queryInt(r, "limit", 50),
		Offset:     queryInt(r, "offset", 0),
	}
	items, total, err := h.repo.ListQuestions(r.Context(), claims.OrgID, filter)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"questions": items, "total": total})
}

func (h *Handler) ArchiveQuestion(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	if err := h.repo.ArchiveQuestion(r.Context(), claims.OrgID, chiURLParam(r, "questionID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Question archived."})
}

func normaliseTags(tags []string) []string {
	out := make([]string, 0, len(tags))
	seen := map[string]bool{}
	for _, t := range tags {
		t = strings.ToLower(strings.TrimSpace(t))
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return out
}

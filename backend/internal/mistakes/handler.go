package mistakes

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	repo *Repo
	svc  *Service
}

func NewHandler(repo *Repo, svc *Service) *Handler {
	return &Handler{repo: repo, svc: svc}
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeDomainError(w http.ResponseWriter, err error) {
	if errors.Is(err, ErrNotFound) {
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
		return
	}
	httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
}

// HandleList handles GET /api/mistakes?category=&context_tag=&from=&to=
// (from/to are RFC3339 timestamps).
func (h *Handler) HandleList(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	f := ListFilter{}
	q := r.URL.Query()
	if v := q.Get("category"); v != "" {
		f.Category = &v
	}
	if v := q.Get("context_tag"); v != "" {
		f.ContextTag = &v
	}
	if v := q.Get("from"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			f.From = &t
		}
	}
	if v := q.Get("to"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			f.To = &t
		}
	}

	entries, err := h.repo.List(r.Context(), claims.UserID, f)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"entries": entries})
}

// HandleCreate handles POST /api/mistakes.
func (h *Handler) HandleCreate(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req LogRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	fields := map[string]string{}
	if !ValidCategories[req.Category] {
		fields["category"] = "category must be a recognized mistake category."
	}
	if req.SubTopic == "" {
		fields["sub_topic"] = "sub_topic is required."
	}
	if req.OriginalText == "" {
		fields["original_text"] = "original_text is required."
	}
	if req.CorrectedText == "" {
		fields["corrected_text"] = "corrected_text is required."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	entry, err := h.svc.LogMistake(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, entry)
}

// HandleSummary handles GET /api/mistakes/summary.
func (h *Handler) HandleSummary(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	summary, err := h.repo.Summary(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"categories": summary})
}

// HandleResolve handles POST /api/mistakes/{id}/resolve.
func (h *Handler) HandleResolve(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	entryID := chi.URLParam(r, "id")
	if err := h.repo.MarkResolved(r.Context(), claims.UserID, entryID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"resolved": true})
}

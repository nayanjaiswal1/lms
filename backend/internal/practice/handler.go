package practice

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
	repo    *Repo
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound: {Status: http.StatusNotFound, Message: "Not found."},
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

var suggestedTechnologies = []string{
	"Go", "Python", "JavaScript", "TypeScript", "Java", "Rust", "C++",
	"React", "Next.js", "Node.js", "PostgreSQL", "Redis", "Docker",
	"Kubernetes", "AWS", "System Design", "Data Structures", "Algorithms",
	"GraphQL", "REST APIs", "Microservices", "CI/CD",
}

func (h *Handler) GetSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionID")
	session, err := h.repo.GetSession(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, session)
}

func (h *Handler) UpdateSessionStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionID")
	var body struct {
		Status SessionStatus `json:"status"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Status != StatusCompleted && body.Status != StatusAbandoned {
		httputil.WriteError(w, http.StatusBadRequest, "status must be 'completed' or 'abandoned'.")
		return
	}
	if err := h.repo.UpdateSessionStatus(r.Context(), sessionID, claims.UserID, body.Status); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) SubmitAnswer(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionID")
	posStr := chi.URLParam(r, "position")
	position, err := strconv.Atoi(posStr)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid position.")
		return
	}
	var body struct {
		AnswerText string `json:"answer_text"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.AnswerText == "" {
		httputil.WriteError(w, http.StatusBadRequest, "answer_text is required.")
		return
	}
	item, err := h.service.SubmitAnswer(r.Context(), sessionID, claims.UserID, position, body.AnswerText)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) ListTechnologies(w http.ResponseWriter, _ *http.Request) {
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"technologies": suggestedTechnologies})
}

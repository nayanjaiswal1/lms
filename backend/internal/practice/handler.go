package practice

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
	repo    *Repo
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeError(w http.ResponseWriter, err error) {
	if errors.Is(err, ErrNotFound) {
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
		return
	}
	httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
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

func (h *Handler) ListSessions(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessions, err := h.repo.ListSessions(r.Context(), claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"sessions": sessions})
}

func (h *Handler) CreateSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var body struct {
		Technology    string `json:"technology"`
		Difficulty    string `json:"difficulty"`
		QuestionCount int    `json:"question_count"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.Technology == "" {
		httputil.WriteError(w, http.StatusBadRequest, "technology is required.")
		return
	}
	if body.QuestionCount < 1 || body.QuestionCount > 20 {
		body.QuestionCount = 5
	}
	if body.Difficulty == "" {
		body.Difficulty = "intermediate"
	}

	var orgID *string
	if claims.OrgID != "" {
		orgID = &claims.OrgID
	}

	session, err := h.service.CreateSession(r.Context(), claims.UserID, orgID,
		body.Technology, body.Difficulty, body.QuestionCount, "")
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			httputil.WriteError(w, http.StatusServiceUnavailable, "AI response timed out. Please try again.")
			return
		}
		msg := err.Error()
		if strings.Contains(msg, "rate_limit") {
			httputil.WriteError(w, http.StatusServiceUnavailable, "AI service is rate-limited. Please wait and try again.")
			return
		}
		if strings.Contains(msg, "api error") {
			httputil.WriteError(w, http.StatusBadGateway, "AI service returned an error. Please try again.")
			return
		}
		httputil.WriteError(w, http.StatusServiceUnavailable, "AI service is unavailable. Please try again later.")
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, session)
}

func (h *Handler) GetSession(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionID")
	session, err := h.repo.GetSession(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, session)
}

func (h *Handler) UpdateSessionStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
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
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) SubmitAnswer(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
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
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

func (h *Handler) ListTechnologies(w http.ResponseWriter, _ *http.Request) {
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"technologies": suggestedTechnologies})
}

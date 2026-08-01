package systemdesign

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// ─── shared helpers ───────────────────────────────────────────────────────────

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:       {Status: http.StatusNotFound, Message: "System design question not found."},
	ErrNotQuestion:    {Status: http.StatusNotFound, Message: "System design question not found."},
	ErrNotOwner:       {Status: http.StatusForbidden, Message: "This attempt belongs to another user."},
	ErrAIUnavailable:  {Status: http.StatusServiceUnavailable, Message: "AI provider is not configured."},
	ErrEmptyMessage:   {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"content": "must not be empty"}},
	ErrMessageTooLong: {Status: http.StatusUnprocessableEntity, Fields: map[string]string{"content": "must not exceed 2000 characters"}},
	ErrEmptyScene:     {Status: http.StatusUnprocessableEntity, Message: "Add something to the canvas before requesting feedback."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

// ─── Attempts ─────────────────────────────────────────────────────────────────

// ListAttempts handles GET /api/modules/{moduleId}/design/attempts
func (h *Handler) ListAttempts(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	attempts, err := h.service.ListAttempts(r.Context(), claims.OrgID, claims.UserID, moduleID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, attempts)
}

// CreateAttempt handles POST /api/modules/{moduleId}/design/attempts
func (h *Handler) CreateAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	attempt, err := h.service.CreateAttempt(r.Context(), claims.OrgID, claims.UserID, moduleID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, attempt)
}

// GetAttempt handles GET /api/modules/{moduleId}/design/attempts/{attemptId}
func (h *Handler) GetAttempt(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	attemptID := chi.URLParam(r, "attemptId")
	attempt, err := h.service.GetAttempt(r.Context(), claims.OrgID, claims.UserID, moduleID, attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, attempt)
}

// SaveScene handles PUT /api/modules/{moduleId}/design/attempts/{attemptId}/scene
func (h *Handler) SaveScene(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req SaveSceneRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	attemptID := chi.URLParam(r, "attemptId")
	attempt, err := h.service.SaveScene(r.Context(), claims.UserID, moduleID, attemptID, req.Scene)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, attempt)
}

// GenerateFeedback handles POST /api/modules/{moduleId}/design/attempts/{attemptId}/feedback
func (h *Handler) GenerateFeedback(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	attemptID := chi.URLParam(r, "attemptId")
	resp, err := h.service.GenerateFeedback(r.Context(), claims.OrgID, claims.UserID, moduleID, attemptID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, resp)
}

// ─── Chat ─────────────────────────────────────────────────────────────────────

// ListChat handles GET /api/modules/{moduleId}/design/chat
func (h *Handler) ListChat(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	messages, err := h.service.ListChat(r.Context(), claims.OrgID, claims.UserID, moduleID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, messages)
}

// SendChatMessage handles POST /api/modules/{moduleId}/design/chat
func (h *Handler) SendChatMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req SendChatMessageRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	moduleID := chi.URLParam(r, "moduleId")
	messages, err := h.service.SendChatMessage(r.Context(), claims.OrgID, claims.UserID, moduleID, req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, messages)
}

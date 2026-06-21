package messaging

import (
	"encoding/json"
	"errors"
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

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		httputil.WriteError(w, http.StatusNotFound, "Not found.")
	case errors.Is(err, ErrForbidden):
		httputil.WriteError(w, http.StatusForbidden, "Forbidden.")
	case errors.Is(err, ErrEditWindowClosed):
		httputil.WriteError(w, http.StatusConflict, "Messages can only be edited within 15 minutes of posting.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

func queryStr(r *http.Request, key string) string {
	return r.URL.Query().Get(key)
}

func queryBool(r *http.Request, key string) bool {
	return r.URL.Query().Get(key) == "true"
}

func queryInt(r *http.Request, key string, def int) int {
	s := r.URL.Query().Get(key)
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil || n <= 0 {
		return def
	}
	return n
}

func (h *Handler) ListMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	f := ListMessagesFilter{
		Before:     queryStr(r, "before"),
		Limit:      queryInt(r, "limit", 20),
		Type:       queryStr(r, "type"),
		Unresolved: queryBool(r, "unresolved"),
		Pinned:     queryBool(r, "pinned"),
	}
	msgs, err := h.repo.ListMessages(r.Context(), claims.OrgID, batchID, claims.UserID, f)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"messages": msgs})
}

func (h *Handler) PostMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	var body struct {
		Body     string      `json:"body"`
		Type     MessageType `json:"type"`
		ParentID *string     `json:"parent_id"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	msg, err := h.service.PostMessage(r.Context(), claims.OrgID, batchID, claims.UserID, body.Body, body.Type, body.ParentID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, msg)
}

func (h *Handler) EditMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	var body struct {
		Body string `json:"body"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	msg, err := h.service.EditMessage(r.Context(), claims.OrgID, msgID, claims.UserID, body.Body)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, msg)
}

func (h *Handler) DeleteMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	if err := h.service.DeleteMessage(r.Context(), claims.OrgID, msgID, claims.UserID, claims.OrgRole); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) React(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	var body struct {
		Reaction Reaction `json:"reaction"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	added, err := h.service.React(r.Context(), msgID, claims.UserID, body.Reaction)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"added": added})
}

func (h *Handler) ResolveMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	if err := h.service.Resolve(r.Context(), claims.OrgID, msgID); err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) PinMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	if err := h.service.Pin(r.Context(), claims.OrgID, msgID); err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) PromoteToFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	var body struct {
		CourseID string `json:"course_id"`
		Question string `json:"question"`
		Answer   string `json:"answer"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if body.CourseID == "" {
		httputil.WriteError(w, http.StatusBadRequest, "course_id is required.")
		return
	}
	faq, err := h.service.PromoteToFAQ(r.Context(), claims.OrgID, body.CourseID, msgID, claims.UserID, body.Question, body.Answer)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, faq)
}

func (h *Handler) ListFAQs(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	faqs, err := h.repo.ListFAQs(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"faqs": faqs})
}

func (h *Handler) CreateFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	var body struct {
		Question string `json:"question"`
		Answer   string `json:"answer"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	faq, err := h.repo.CreateFAQ(r.Context(), claims.OrgID, courseID, claims.UserID, body.Question, body.Answer)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, faq)
}

func (h *Handler) UpdateFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	faqID := chi.URLParam(r, "faqID")
	var body struct {
		Question *string `json:"question"`
		Answer   *string `json:"answer"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	faq, err := h.repo.UpdateFAQ(r.Context(), claims.OrgID, faqID, body.Question, body.Answer)
	if err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, faq)
}

func (h *Handler) DeleteFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	faqID := chi.URLParam(r, "faqID")
	if err := h.repo.DeleteFAQ(r.Context(), claims.OrgID, faqID); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ReorderFAQs(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	var body struct {
		FAQIDs []string `json:"faq_ids"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}
	if err := h.repo.ReorderFAQs(r.Context(), claims.OrgID, courseID, body.FAQIDs); err != nil {
		writeError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

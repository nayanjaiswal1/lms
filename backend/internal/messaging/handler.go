package messaging

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/middleware"
)

const (
	defaultSimilarFAQThreshold = 0.3
	defaultSimilarFAQLimit     = 5
)

type Handler struct {
	service *Service
	repo    *Repo
	pool    *pgxpool.Pool
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:         {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden:        {Status: http.StatusForbidden, Message: "Forbidden."},
	ErrEditWindowClosed: {Status: http.StatusConflict, Message: "Messages can only be edited within 15 minutes of posting."},
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

func queryFloat(r *http.Request, key string, def float64) float64 {
	s := r.URL.Query().Get(key)
	if s == "" {
		return def
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil || f <= 0 {
		return def
	}
	return f
}

func (h *Handler) ListMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"messages": msgs})
}

func (h *Handler) PostMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, msg)
}

func (h *Handler) EditMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, msg)
}

func (h *Handler) DeleteMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	// Live-looked-up org role, not claims.OrgRole: a demoted staff member's
	// stale JWT would otherwise keep the "any staff can delete any message"
	// privilege until token expiry (see middleware.LiveOrgRole).
	liveRole, _ := middleware.LiveOrgRole(r.Context(), h.pool, claims.UserID, claims.OrgID)
	if err := h.service.DeleteMessage(r.Context(), claims.OrgID, msgID, claims.UserID, liveRole); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) React(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"added": added})
}

func (h *Handler) ResolveMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	if err := h.service.Resolve(r.Context(), claims.OrgID, msgID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) PinMessage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	msgID := chi.URLParam(r, "msgID")
	if err := h.service.Pin(r.Context(), claims.OrgID, msgID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) PromoteToFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, faq)
}

func (h *Handler) ListFAQs(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	faqs, err := h.repo.ListFAQs(r.Context(), claims.OrgID, courseID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"faqs": faqs})
}

func (h *Handler) GetSimilarFAQs(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	courseID := chi.URLParam(r, "courseID")
	question := queryStr(r, "q")
	threshold := queryFloat(r, "threshold", defaultSimilarFAQThreshold)
	limit := queryInt(r, "limit", defaultSimilarFAQLimit)
	faqs, err := h.service.SimilarFAQs(r.Context(), claims.OrgID, courseID, question, threshold, limit)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"faqs": faqs})
}

func (h *Handler) CreateFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, faq)
}

func (h *Handler) UpdateFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, faq)
}

func (h *Handler) DeleteFAQ(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	faqID := chi.URLParam(r, "faqID")
	if err := h.repo.DeleteFAQ(r.Context(), claims.OrgID, faqID); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) ReorderFAQs(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

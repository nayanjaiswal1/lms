package messaging

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/httputil"
)

// PermModerate gates moderation (resolve/pin/promote, FAQ management) and
// lets its holders read and delete every message in the org's batches.
const PermModerate = "messaging.moderate"

const (
	defaultSimilarFAQThreshold = 0.3
	defaultSimilarFAQLimit     = 5
)

type Handler struct {
	service *Service
	repo    *Repo
	perms   *authz.Service
}

// canModerate reports whether the caller holds messaging.moderate, writing
// the 500 itself when the lookup fails.
func (h *Handler) canModerate(w http.ResponseWriter, r *http.Request, claims *auth.Claims) (moderate, ok bool) {
	moderate, err := h.perms.HasPermission(r.Context(), claims.UserID, claims.OrgID, PermModerate)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Permission check failed.")
		return false, false
	}
	return moderate, true
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:         {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden:        {Status: http.StatusForbidden, Message: "Forbidden."},
	ErrEditWindowClosed: {Status: http.StatusConflict, Message: "Messages can only be edited within 15 minutes of posting."},
}

var writeDomainError = httputil.DomainErrorWriter(domainErrors, "Something went wrong.")

func (h *Handler) ListMessages(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	f := ListMessagesFilter{
		Before:     httputil.QueryStr(r, "before"),
		Limit:      httputil.QueryIntPositive(r, "limit", 20),
		Type:       httputil.QueryStr(r, "type"),
		Unresolved: httputil.QueryBool(r, "unresolved"),
		Pinned:     httputil.QueryBool(r, "pinned"),
	}
	moderate, ok := h.canModerate(w, r, claims)
	if !ok {
		return
	}
	msgs, err := h.repo.ListMessages(r.Context(), claims.OrgID, batchID, claims.UserID, moderate, f)
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
	if !httputil.DecodeJSON(w, r, &body) {
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
	if !httputil.DecodeJSON(w, r, &body) {
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
	// Live permission set, not the JWT's org_role claim: a demoted moderator's
	// stale token must not keep "delete any message" until it expires.
	moderate, ok := h.canModerate(w, r, claims)
	if !ok {
		return
	}
	if err := h.service.DeleteMessage(r.Context(), claims.OrgID, msgID, claims.UserID, moderate); err != nil {
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
	if !httputil.DecodeJSON(w, r, &body) {
		return
	}
	added, err := h.service.React(r.Context(), claims.OrgID, msgID, claims.UserID, body.Reaction)
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
	if !httputil.DecodeJSON(w, r, &body) {
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
	question := httputil.QueryStr(r, "q")
	threshold := httputil.QueryFloatPositive(r, "threshold", defaultSimilarFAQThreshold)
	limit := httputil.QueryIntPositive(r, "limit", defaultSimilarFAQLimit)
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
	if !httputil.DecodeJSON(w, r, &body) {
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
	if !httputil.DecodeJSON(w, r, &body) {
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
	if !httputil.DecodeJSON(w, r, &body) {
		return
	}
	if err := h.repo.ReorderFAQs(r.Context(), claims.OrgID, courseID, body.FAQIDs); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

package interviewexp

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

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

var domainErrors = map[error]httputil.ErrSpec{
	ErrNotFound:   {Status: http.StatusNotFound, Message: "Not found."},
	ErrForbidden:  {Status: http.StatusForbidden, Message: "You do not have permission to perform this action."},
	ErrValidation: {Status: http.StatusUnprocessableEntity, Message: "Invalid request."},
}

func writeDomainError(w http.ResponseWriter, err error) {
	httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.")
}

func optionalQueryParam(r *http.Request, key string) *string {
	v := r.URL.Query().Get(key)
	if v == "" {
		return nil
	}
	return &v
}

// ─── Posts ────────────────────────────────────────────────────────────────────

func (h *Handler) ListPosts(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}
	f := ListFilter{
		Company:  optionalQueryParam(r, "company"),
		Position: optionalQueryParam(r, "position"),
		Tag:      optionalQueryParam(r, "tag"),
		Query:    optionalQueryParam(r, "q"),
	}
	posts, err := h.service.ListPosts(r.Context(), f)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, posts)
}

func (h *Handler) CreatePost(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreatePostRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.service.CreatePost(r.Context(), claims.UserID, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, p)
}

func (h *Handler) GetPost(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	detail, err := h.service.GetPostDetail(r.Context(), claims.UserID, chi.URLParam(r, "id"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

// ─── Entries ──────────────────────────────────────────────────────────────────

func (h *Handler) CreateEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateEntryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	e, err := h.service.CreateEntry(r.Context(), claims.UserID, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, e)
}

// ─── Qna ──────────────────────────────────────────────────────────────────────

func (h *Handler) CreateStandaloneQna(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateQnaRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	q, err := h.service.CreateStandaloneQna(r.Context(), claims.UserID, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, q)
}

func (h *Handler) CreateEntryQna(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateQnaRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	q, err := h.service.CreateEntryQna(r.Context(), claims.UserID, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, q)
}

func (h *Handler) UpdateQna(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpdateQnaRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	q, err := h.service.UpdateQna(r.Context(), claims.UserID, claims.OrgRole, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, q)
}

func (h *Handler) DeleteQna(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteQna(r.Context(), claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

// ─── Comments ─────────────────────────────────────────────────────────────────

func (h *Handler) CreateComment(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req CreateCommentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.CreateComment(r.Context(), claims.UserID, chi.URLParam(r, "id"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, c)
}

func (h *Handler) UpdateComment(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpdateCommentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.UpdateComment(r.Context(), claims.UserID, chi.URLParam(r, "id"), req.Content)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, c)
}

func (h *Handler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteComment(r.Context(), claims.UserID, claims.OrgRole, chi.URLParam(r, "id")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

// ─── Votes ────────────────────────────────────────────────────────────────────

func (h *Handler) Vote(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req VoteRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.service.Vote(r.Context(), claims.UserID, req); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// ─── FAQ ──────────────────────────────────────────────────────────────────────

func (h *Handler) GetFaq(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	f := FaqFilter{
		Company: optionalQueryParam(r, "company"),
		Tag:     optionalQueryParam(r, "tag"),
		Status:  optionalQueryParam(r, "status"),
	}
	items, err := h.service.ListFaq(r.Context(), claims.UserID, f)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) UpdateFaqStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpdateFaqStatusRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.service.UpdateFaqStatus(r.Context(), claims.UserID, chi.URLParam(r, "qnaId"), req.Status); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (h *Handler) UpdateFaqStarred(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req UpdateFaqStarredRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.service.UpdateFaqStarred(r.Context(), claims.UserID, chi.URLParam(r, "qnaId"), req.Starred); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

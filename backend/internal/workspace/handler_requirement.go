package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ListQuestions is GET …/questions.
func (h *Handler) ListQuestions(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListQuestions(r.Context(), pc, httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// SimilarQuestions is GET …/questions/similar.
func (h *Handler) SimilarQuestions(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	items, err := h.service.SimilarQuestions(r.Context(), pc, httputil.QueryStr(r, "q"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, items)
}

// AskQuestion is POST …/questions.
func (h *Handler) AskQuestion(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req AskQuestionRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	result, err := h.service.AskQuestion(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, result)
}

// AnswerQuestion is POST …/questions/{questionID}/answer.
func (h *Handler) AnswerQuestion(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req AnswerQuestionRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	q, err := h.service.AnswerQuestion(r.Context(), pc, chi.URLParam(r, "questionID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, q)
}

// RequirementGaps is POST …/requirement/gaps.
func (h *Handler) RequirementGaps(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	gaps, err := h.service.RequirementGaps(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, gaps)
}

// ListQuestionComments is GET …/questions/{questionID}/comments.
func (h *Handler) ListQuestionComments(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListQuestionComments(r.Context(), pc, chi.URLParam(r, "questionID"),
		httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// CreateQuestionComment is POST …/questions/{questionID}/comments.
func (h *Handler) CreateQuestionComment(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateCommentRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.CreateQuestionComment(r.Context(), pc, chi.URLParam(r, "questionID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, c)
}

// ListItemComments is GET …/items/{itemID}/comments.
func (h *Handler) ListItemComments(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListItemComments(r.Context(), pc, chi.URLParam(r, "itemID"),
		httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// CreateItemComment is POST …/items/{itemID}/comments.
func (h *Handler) CreateItemComment(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateCommentRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	c, err := h.service.CreateItemComment(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, c)
}

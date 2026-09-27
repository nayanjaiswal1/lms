package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// GetDoc is GET …/items/{itemID}/doc.
func (h *Handler) GetDoc(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetDoc(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// SubmitDoc is POST …/items/{itemID}/doc/submit.
func (h *Handler) SubmitDoc(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.SubmitDoc(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// ReviewDoc is POST …/items/{itemID}/doc/reviews.
func (h *Handler) ReviewDoc(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req ReviewDocRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	view, err := h.service.ReviewDoc(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, view)
}

// ScheduleDesignReview is POST …/items/{itemID}/doc/design-review.
func (h *Handler) ScheduleDesignReview(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req ScheduleMeetingRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	meeting, err := h.service.ScheduleDesignReview(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, meeting)
}

// TriageBug is POST …/items/{itemID}/triage.
func (h *Handler) TriageBug(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req TriageBugRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	item, err := h.service.TriageBug(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

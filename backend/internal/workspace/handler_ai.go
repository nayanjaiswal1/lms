package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// SuggestEpics is POST …/ai/epics.
func (h *Handler) SuggestEpics(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	result, err := h.service.SuggestEpics(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// SuggestTaskBreakdown is POST …/items/{itemID}/ai/breakdown.
func (h *Handler) SuggestTaskBreakdown(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	result, err := h.service.SuggestTaskBreakdown(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// SuggestAssignees is POST …/items/{itemID}/ai/assignees.
func (h *Handler) SuggestAssignees(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	result, err := h.service.SuggestAssignees(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// ExplainLate is POST …/items/{itemID}/ai/why-late.
func (h *Handler) ExplainLate(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	result, err := h.service.ExplainLate(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// ChangeImpact is POST …/items/{itemID}/ai/change-impact.
func (h *Handler) ChangeImpact(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	result, err := h.service.ChangeImpact(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// GetWeeklySummary is POST …/ai/weekly-summary?regenerate=.
func (h *Handler) GetWeeklySummary(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	result, err := h.service.WeeklySummary(r.Context(), pc, httputil.QueryBool(r, "regenerate"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

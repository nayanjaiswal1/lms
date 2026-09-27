package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ListSprints is GET …/sprints.
func (h *Handler) ListSprints(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	sprints, err := h.service.ListSprints(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sprints)
}

// CreateSprint is POST …/sprints.
func (h *Handler) CreateSprint(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateSprintRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	sprint, err := h.service.CreateSprint(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, sprint)
}

// StartSprint is POST …/sprints/{sprintID}/start.
func (h *Handler) StartSprint(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	sprint, err := h.service.StartSprint(r.Context(), pc, chi.URLParam(r, "sprintID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sprint)
}

// CloseSprint is POST …/sprints/{sprintID}/close.
func (h *Handler) CloseSprint(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CloseSprintRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	sprint, err := h.service.CloseSprint(r.Context(), pc, chi.URLParam(r, "sprintID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, sprint)
}

// SetItemSprint is PUT …/items/{itemID}/sprint.
func (h *Handler) SetItemSprint(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req SetItemSprintRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	item, err := h.service.SetItemSprint(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ListWorkItems is GET .../items.
func (h *Handler) ListWorkItems(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	f := ItemFilter{
		Type:            httputil.QueryStr(r, "type"),
		Status:          httputil.QueryStr(r, "status"),
		TrackID:         httputil.QueryStr(r, "track"),
		AssigneeID:      httputil.QueryStr(r, "assignee"),
		ParentID:        httputil.QueryStr(r, "parent"),
		FeatureID:       httputil.QueryStr(r, "feature"),
		EpicID:          httputil.QueryStr(r, "epic"),
		ReleaseID:       httputil.QueryStr(r, "release"),
		SprintID:        httputil.QueryStr(r, "sprint"),
		Q:               httputil.QueryStr(r, "q"),
		IncludeArchived: httputil.QueryBool(r, "archived"),
		Cursor:          httputil.QueryStr(r, "cursor"),
		Limit:           httputil.QueryIntPositive(r, "limit", PageSizeDefault),
	}
	page, err := h.service.ListWorkItems(r.Context(), pc, f)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// CreateWorkItem is POST .../items.
func (h *Handler) CreateWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateWorkItemRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	result, err := h.service.CreateWorkItem(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, result)
}

// ListSimilarItems is GET .../items/similar.
func (h *Handler) ListSimilarItems(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	items, err := h.service.ListSimilarItems(r.Context(), pc, httputil.QueryStr(r, "q"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, items)
}

// GetWorkItem is GET .../items/{itemID} — itemID may be a uuid or "KEY-123".
func (h *Handler) GetWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	detail, err := h.service.GetWorkItem(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, detail)
}

// UpdateWorkItem is PATCH .../items/{itemID}.
func (h *Handler) UpdateWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req UpdateWorkItemRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	item, err := h.service.UpdateWorkItem(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// MoveWorkItem is POST .../items/{itemID}/move.
func (h *Handler) MoveWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req MoveWorkItemRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	item, err := h.service.MoveWorkItem(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// ArchiveWorkItem is POST .../items/{itemID}/archive.
func (h *Handler) ArchiveWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.ArchiveWorkItem(r.Context(), pc, chi.URLParam(r, "itemID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

// DeleteWorkItem is DELETE .../items/{itemID}.
func (h *Handler) DeleteWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteWorkItem(r.Context(), pc, chi.URLParam(r, "itemID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

// TransitionWorkItem is POST .../items/{itemID}/transition.
func (h *Handler) TransitionWorkItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req TransitionRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	item, err := h.service.TransitionItem(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

// SetAssignees is PUT .../items/{itemID}/assignees.
func (h *Handler) SetAssignees(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req SetAssigneesRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	assignees, err := h.service.SetAssignees(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, assignees)
}

// CreateItemLink is POST .../items/{itemID}/links.
func (h *Handler) CreateItemLink(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateLinkRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	link, err := h.service.CreateLink(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, link)
}

// DeleteItemLink is DELETE .../items/{itemID}/links/{toItemID}/{kind}.
func (h *Handler) DeleteItemLink(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	err := h.service.DeleteLink(r.Context(), pc, chi.URLParam(r, "itemID"), chi.URLParam(r, "toItemID"), chi.URLParam(r, "kind"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

// ListItemEvents is GET .../items/{itemID}/events.
func (h *Handler) ListItemEvents(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListItemEvents(r.Context(), pc, chi.URLParam(r, "itemID"),
		httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

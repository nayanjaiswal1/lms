package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ListReleases is GET …/releases.
func (h *Handler) ListReleases(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	releases, err := h.service.ListReleases(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, releases)
}

// CreateRelease is POST …/releases.
func (h *Handler) CreateRelease(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateReleaseRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	rel, err := h.service.CreateRelease(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, rel)
}

// UpdateRelease is PATCH …/releases/{releaseID}.
func (h *Handler) UpdateRelease(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req UpdateReleaseRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	rel, err := h.service.UpdateRelease(r.Context(), pc, chi.URLParam(r, "releaseID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rel)
}

// GetReleaseNotes is GET …/releases/{releaseID}/notes?polish=.
func (h *Handler) GetReleaseNotes(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	notes, err := h.service.GetReleaseNotes(r.Context(), pc, chi.URLParam(r, "releaseID"), httputil.QueryBool(r, "polish"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, notes)
}

// SetItemRelease is PUT …/items/{itemID}/release.
func (h *Handler) SetItemRelease(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req SetItemReleaseRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	item, err := h.service.SetItemRelease(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, item)
}

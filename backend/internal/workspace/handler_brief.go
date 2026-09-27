package workspace

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// GetBrief is GET …/brief.
func (h *Handler) GetBrief(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.GetBrief(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

// CreateBriefPage is POST …/brief.
func (h *Handler) CreateBriefPage(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.CreateBriefPage(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, view)
}

// ApproveBrief is POST …/brief/approve.
func (h *Handler) ApproveBrief(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	view, err := h.service.ApproveBrief(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

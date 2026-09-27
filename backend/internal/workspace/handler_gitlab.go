package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ProvisionGitlab is POST …/gitlab/provision (owner, StatusesPlanning,
// gitlab_enabled — contract-phase4.md D8).
func (h *Handler) ProvisionGitlab(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	project, err := h.service.ProvisionGitlab(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	maskShareToken(project, pc)
	httputil.WriteJSON(w, http.StatusOK, project)
}

// GetItemGitlabLinks is GET …/items/{itemID}/gitlab (viewer).
func (h *Handler) GetItemGitlabLinks(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	links, err := h.service.ListItemGitlabLinks(r.Context(), pc, chi.URLParam(r, "itemID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, links)
}

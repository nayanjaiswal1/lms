package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/httputil"
)

// respond writes v as 200 JSON or the mapped domain error.
func respond[T any](w http.ResponseWriter, v T, err error) {
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, v)
}

func (h *Handler) GitActivity(w http.ResponseWriter, r *http.Request) {
	if pc, ok := projectCtxOr500(w, r); ok {
		v, err := h.service.TeamGitActivity(r.Context(), pc)
		respond(w, v, err)
	}
}

func (h *Handler) GitContributions(w http.ResponseWriter, r *http.Request) {
	if pc, ok := projectCtxOr500(w, r); ok {
		v, err := h.service.TeamGitContributions(r.Context(), pc)
		respond(w, v, err)
	}
}

func (h *Handler) GitOwnership(w http.ResponseWriter, r *http.Request) {
	if pc, ok := projectCtxOr500(w, r); ok {
		v, err := h.service.TeamGitOwnership(r.Context(), pc)
		respond(w, v, err)
	}
}

func (h *Handler) GitCheckpoints(w http.ResponseWriter, r *http.Request) {
	if pc, ok := projectCtxOr500(w, r); ok {
		v, err := h.service.TeamCheckpoints(r.Context(), pc)
		respond(w, v, err)
	}
}

const (
	maxProposalTitleLen = 200
	maxProposalDescLen  = 3000
	maxProposalLinkLen  = 500
)

func (h *Handler) SubmitProposal(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req struct {
		Title       string  `json:"title"`
		Description *string `json:"description"`
		Link        *string `json:"link"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	fields := map[string]string{}
	if t := len([]rune(req.Title)); t == 0 || t > maxProposalTitleLen {
		fields["title"] = "A title of up to 200 characters is required."
	}
	if req.Description != nil && len(*req.Description) > maxProposalDescLen {
		fields["description"] = "Description must be 3000 characters or fewer."
	}
	if req.Link != nil && len(*req.Link) > maxProposalLinkLen {
		fields["link"] = "Link must be 500 characters or fewer."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	p, err := h.service.SubmitDesignProposal(r.Context(), pc, chi.URLParam(r, "checkpointID"), req.Title, req.Description, req.Link)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, p)
}

func (h *Handler) ListProposals(w http.ResponseWriter, r *http.Request) {
	if pc, ok := projectCtxOr500(w, r); ok {
		v, err := h.service.ListDesignProposals(r.Context(), pc, chi.URLParam(r, "checkpointID"))
		respond(w, v, err)
	}
}

// proposalAction builds a handler for a proposal-scoped gitlab call
// returning 204 on success.
func (h *Handler) proposalAction(call func(g *gitlab.Service, r *http.Request, orgID, userID string) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		pc, ok := projectCtxOr500(w, r)
		if !ok {
			return
		}
		err := h.service.ProposalAction(r.Context(), pc, chi.URLParam(r, "proposalID"), func(g *gitlab.Service, orgID, userID string) error {
			return call(g, r, orgID, userID)
		})
		if err != nil {
			writeDomainError(w, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func (h *Handler) VoteProposal() http.HandlerFunc {
	return h.proposalAction(func(g *gitlab.Service, r *http.Request, orgID, userID string) error {
		return g.VoteForProposal(r.Context(), orgID, userID, chi.URLParam(r, "proposalID"))
	})
}

func (h *Handler) UnvoteProposal() http.HandlerFunc {
	return h.proposalAction(func(g *gitlab.Service, r *http.Request, orgID, userID string) error {
		return g.RemoveVote(r.Context(), orgID, userID, chi.URLParam(r, "proposalID"))
	})
}

func (h *Handler) DeleteProposal() http.HandlerFunc {
	return h.proposalAction(func(g *gitlab.Service, r *http.Request, orgID, userID string) error {
		return g.DeleteDesignProposal(r.Context(), orgID, userID, chi.URLParam(r, "proposalID"))
	})
}

// GitHandoff is POST …/gitlab/handoff (owner, completed).
func (h *Handler) GitHandoff(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req struct {
		Mode                string `json:"mode"`
		TargetNamespaceID   int64  `json:"target_namespace_id"`
		TargetNamespacePath string `json:"target_namespace_path"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	ho, err := h.service.HandoffGitlab(r.Context(), pc, req.Mode, req.TargetNamespaceID, req.TargetNamespacePath)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusAccepted, ho)
}

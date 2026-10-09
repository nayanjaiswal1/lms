package gitlab

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ListAllDesignProposals handles GET
// /api/workspace-cohorts/checkpoints/{checkpointID}/proposals — staff-only, every
// team's proposals against the checkpoint (the view AcceptDesignProposal
// decides from).
func (h *Handler) ListAllDesignProposals(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	proposals, err := h.service.ListDesignProposalsForCheckpoint(r.Context(), claims.OrgID, chi.URLParam(r, "checkpointID"), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, proposals)
}

// AcceptDesignProposal handles POST
// /api/workspace-cohorts/proposals/{proposalID}/accept — staff-only.
func (h *Handler) AcceptDesignProposal(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	proposal, err := h.service.AcceptDesignProposal(r.Context(), claims.OrgID, chi.URLParam(r, "proposalID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, proposal)
}

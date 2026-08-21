package gitlab

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Length caps on free text shared by Batch 7's proposal/task endpoints —
// cheap to enforce at the boundary, expensive to retrofit once a giant
// paste has already landed in the table.
const (
	maxTitleLen       = 200
	maxDescriptionLen = 3000
	maxLinkLen        = 500
)

type designProposalRequest struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`
	Link        *string `json:"link"`
}

func validateDesignProposalRequest(req designProposalRequest) map[string]string {
	fields := map[string]string{}
	if strings.TrimSpace(req.Title) == "" {
		fields["title"] = "A title is required."
	} else if len(req.Title) > maxTitleLen {
		fields["title"] = fmt.Sprintf("Title must be %d characters or fewer.", maxTitleLen)
	}
	if req.Description != nil && len(*req.Description) > maxDescriptionLen {
		fields["description"] = fmt.Sprintf("Description must be %d characters or fewer.", maxDescriptionLen)
	}
	if req.Link != nil && len(*req.Link) > maxLinkLen {
		fields["link"] = fmt.Sprintf("Link must be %d characters or fewer.", maxLinkLen)
	}
	return fields
}

// SubmitDesignProposal handles POST
// /api/projects/teams/{teamID}/checkpoints/{checkpointID}/proposals.
func (h *Handler) SubmitDesignProposal(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req designProposalRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if fields := validateDesignProposalRequest(req); len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}
	proposal, err := h.service.SubmitDesignProposal(r.Context(), claims.OrgID, claims.UserID,
		chi.URLParam(r, "checkpointID"), chi.URLParam(r, "teamID"), req.Title, req.Description, req.Link)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, proposal)
}

// ListDesignProposals handles GET
// /api/projects/teams/{teamID}/checkpoints/{checkpointID}/proposals.
func (h *Handler) ListDesignProposals(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	proposals, err := h.service.ListDesignProposals(r.Context(), claims.OrgID, claims.UserID,
		chi.URLParam(r, "checkpointID"), chi.URLParam(r, "teamID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, proposals)
}

// ListAllDesignProposals handles GET
// /api/projects/checkpoints/{checkpointID}/proposals — staff-only, every
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

// VoteForProposal handles POST /api/projects/proposals/{proposalID}/vote.
func (h *Handler) VoteForProposal(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.VoteForProposal(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "proposalID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Vote recorded."})
}

// RemoveVote handles DELETE /api/projects/proposals/{proposalID}/vote.
func (h *Handler) RemoveVote(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.RemoveVote(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "proposalID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Vote removed."})
}

// DeleteDesignProposal handles DELETE /api/projects/proposals/{proposalID} —
// a team member withdrawing their own proposal.
func (h *Handler) DeleteDesignProposal(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteDesignProposal(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "proposalID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Proposal withdrawn."})
}

// AcceptDesignProposal handles POST
// /api/projects/proposals/{proposalID}/accept — staff-only.
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

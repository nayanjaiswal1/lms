package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ─── invitations (no RequireProjectRole — the invitee isn't a member yet) ──────

func (h *Handler) ListMyInvitations(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	items, err := h.service.ListMyInvitations(r.Context(), claims.OrgID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, items)
}

func (h *Handler) RespondToInvite(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var req RespondInviteRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.RespondToInvite(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "workspaceID"), req.Accept); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

// ─── members ────────────────────────────────────────────────────────────────

func (h *Handler) ListMembers(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	members, err := h.service.ListMembers(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, members)
}

func (h *Handler) AddMember(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req AddMemberRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	m, err := h.service.AddMember(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, m)
}

func (h *Handler) UpdateMember(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req UpdateMemberRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	m, err := h.service.UpdateMemberRole(r.Context(), pc, chi.URLParam(r, "userID"), req.Role)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, m)
}

func (h *Handler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.RemoveMember(r.Context(), pc, chi.URLParam(r, "userID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── tracks ─────────────────────────────────────────────────────────────────

func (h *Handler) ListTracks(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	tracks, err := h.service.ListTracks(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, tracks)
}

func (h *Handler) CreateTrack(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateTrackRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	t, err := h.service.CreateTrack(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, t)
}

func (h *Handler) UpdateTrack(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req UpdateTrackRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	t, err := h.service.UpdateTrack(r.Context(), pc, chi.URLParam(r, "trackID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, t)
}

func (h *Handler) DeleteTrack(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteTrack(r.Context(), pc, chi.URLParam(r, "trackID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) JoinTrack(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req TrackMembershipRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	userID := req.UserID
	if userID == "" {
		userID = pc.UserID
	}
	if err := h.service.JoinTrack(r.Context(), pc, chi.URLParam(r, "trackID"), userID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

func (h *Handler) ApproveTrackMember(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.ApproveTrackMember(r.Context(), pc, chi.URLParam(r, "trackID"), chi.URLParam(r, "userID")); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

func (h *Handler) LeaveTrack(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.LeaveTrack(r.Context(), pc, chi.URLParam(r, "trackID"), chi.URLParam(r, "userID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ─── onboarding ─────────────────────────────────────────────────────────────

func (h *Handler) ListOnboarding(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	steps, err := h.service.ListOnboarding(r.Context(), pc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, steps)
}

func (h *Handler) CreateOnboardingStep(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req CreateOnboardingStepRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	step, err := h.service.CreateOnboardingStep(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, step)
}

func (h *Handler) UpdateOnboardingStep(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req UpdateOnboardingStepRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	step, err := h.service.UpdateOnboardingStep(r.Context(), pc, chi.URLParam(r, "stepID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, step)
}

func (h *Handler) DeleteOnboardingStep(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteOnboardingStep(r.Context(), pc, chi.URLParam(r, "stepID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) SetOnboardingStepDone(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req struct {
		Done bool `json:"done"`
	}
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.SetOnboardingStepDone(r.Context(), pc, chi.URLParam(r, "stepID"), req.Done); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

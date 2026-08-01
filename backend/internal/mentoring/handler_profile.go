package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// GetMentorProfile returns the single-mentor profile view (directory fields
// plus verified/response-time/hours/percentile) for the mentor profile page.
func (h *Handler) GetMentorProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	profile, err := h.service.GetMentorProfile(r.Context(), claims.OrgID, urlParam(r, "mentorID"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, profile)
}

// VerifyMentor toggles the verified-expert badge on a mentor profile.
// Body: {"verified": bool}. Gated by the mentoring.verify_mentors permission
// at the route level.
func (h *Handler) VerifyMentor(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	var req struct {
		Verified bool `json:"verified"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	mentorID := urlParam(r, "mentorID")
	if err := h.service.SetMentorVerified(r.Context(), claims.OrgID, mentorID, req.Verified, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"mentor_id": mentorID, "verified": req.Verified})
}

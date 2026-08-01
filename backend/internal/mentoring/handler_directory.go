package mentoring

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// ListMentorDirectory returns every mentor in the caller's org with a live
// mentee count and aggregated rating.
func (h *Handler) ListMentorDirectory(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	entries, err := h.service.ListMentorDirectory(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"mentors": entries})
}

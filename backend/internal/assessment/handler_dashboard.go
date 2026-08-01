package assessment

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// GetBatchAnalytics returns the full teacher-dashboard payload for one
// batch: class health, roster, chapter mastery heatmap, weakest/strongest
// chapter ranking, an estimated blockers breakdown, and the
// progress-vs-engagement scatter.
func (h *Handler) GetBatchAnalytics(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	batchID := chi.URLParam(r, "batchID")
	analytics, err := h.repo.BatchAnalytics(r.Context(), claims.OrgID, batchID)
	if err != nil {
		writeBatchExtError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, analytics)
}

package workspace

import (
	"net/http"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// PlanningBoard is GET /api/gitlab/planning/board — any authenticated caller,
// no project-role gate (it aggregates across every workspace they belong to
// rather than acting on one). Replaces internal/gitlab's embedded
// board.json fixture (contract-phase2.md "Planning fixtures").
func (h *Handler) PlanningBoard(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	board, err := h.service.BuildPlanningBoard(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, board)
}

// PlanningIssues is GET /api/gitlab/planning/issues — same caller scope as
// PlanningBoard. Replaces internal/gitlab's embedded issues.json fixture.
func (h *Handler) PlanningIssues(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	issues, err := h.service.BuildPlanningIssues(r.Context(), claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, issues)
}

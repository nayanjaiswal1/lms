package gitlab

import (
	_ "embed"
	"encoding/json"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// Planning & task board (Auto Expand Board UI: Eisenhower dashboard +
// GitLab-style issue list). Payloads are static fixtures embedded at build
// time — the UI is being built ahead of its persistence/GitLab sync layer.
// ponytail: embedded fixtures; replace with repo reads + GitLab issue sync when the board gets real tables.

//go:embed planningdata/board.json
var planningBoardJSON []byte

//go:embed planningdata/issues.json
var planningIssuesJSON []byte

// PlanningBoard serves GET /api/gitlab/planning/board.
func (h *Handler) PlanningBoard(w http.ResponseWriter, _ *http.Request) {
	httputil.WriteJSON(w, http.StatusOK, json.RawMessage(planningBoardJSON))
}

// PlanningIssues serves GET /api/gitlab/planning/issues.
func (h *Handler) PlanningIssues(w http.ResponseWriter, _ *http.Request) {
	httputil.WriteJSON(w, http.StatusOK, json.RawMessage(planningIssuesJSON))
}

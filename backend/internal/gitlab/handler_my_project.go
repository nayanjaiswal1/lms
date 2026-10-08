package gitlab

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// GetMyProject handles GET /api/my/projects/{teamID}[?include=contributions,checkpoints]
// — the caller's own team with its assignment context and the caller's role,
// plus whichever related collections are asked for (left null otherwise).
// 404s (not 403) for a team the caller doesn't belong to.
func (h *Handler) GetMyProject(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	var inc MyProjectIncludes
	for _, name := range strings.Split(r.URL.Query().Get("include"), ",") {
		switch strings.TrimSpace(name) {
		case "":
		case "contributions":
			inc.Contributions = true
		case "checkpoints":
			inc.Checkpoints = true
		default:
			httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
				"include": "allowed: contributions, checkpoints",
			})
			return
		}
	}
	view, err := h.service.GetMyProject(r.Context(), claims.OrgID, claims.UserID, chi.URLParam(r, "teamID"), inc)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, view)
}

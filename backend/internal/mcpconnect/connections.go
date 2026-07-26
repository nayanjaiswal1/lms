package mcpconnect

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

// ListMyConnections handles GET /api/mcp-connections — the settings page's
// list of currently-approved external clients.
func (rt *Router) ListMyConnections(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	conns, err := rt.repo.ListMyConnections(r.Context(), claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, conns)
}

// RevokeConnection handles DELETE /api/mcp-connections/{connectionID} —
// immediately invalidates the connection's refresh token, and its current
// access token too: GetConnectionByAccessHash joins on mc.status = 'active',
// so a revoked connection's in-flight access token stops authorizing /mcp
// requests right away rather than lingering for the rest of its 1h TTL.
func (rt *Router) RevokeConnection(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	connectionID := chi.URLParam(r, "connectionID")
	if err := rt.repo.RevokeConnection(r.Context(), claims.UserID, connectionID); err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Connection not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Something went wrong.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"revoked": true})
}

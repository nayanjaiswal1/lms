package mcpconnect

import (
	"context"
	"net/http"
	"strings"

	"github.com/mindforge/backend/internal/auth"
)

type contextKey int

const connectionContextKey contextKey = iota

// mcpIdentity is the resolved caller of an /mcp request — the student who
// approved the connection, plus the scopes they granted it.
type mcpIdentity struct {
	OrgID        string
	UserID       string
	ConnectionID string
	Scopes       map[string]bool
}

func (id mcpIdentity) hasScope(scope string) bool {
	return id.Scopes[scope]
}

// requireMCPAuth validates the Authorization: Bearer <access_token> header
// against mcp_access_tokens — this is deliberately separate from the
// cookie-based apimiddleware.RequireAuth used everywhere else, since the
// caller here is an external server (Claude/ChatGPT's backend), never a
// browser, and never carries our session cookie.
func (rt *Router) requireMCPAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		token, ok := strings.CutPrefix(authHeader, "Bearer ")
		if !ok || token == "" {
			w.Header().Set("WWW-Authenticate", `Bearer realm="mindforge"`)
			writeOAuthError(w, http.StatusUnauthorized, "invalid_token", "Missing or malformed bearer token.")
			return
		}

		conn, err := rt.repo.GetConnectionByAccessHash(r.Context(), auth.HashToken(token))
		if err != nil {
			w.Header().Set("WWW-Authenticate", `Bearer realm="mindforge"`)
			writeOAuthError(w, http.StatusUnauthorized, "invalid_token", "Access token is invalid, expired, or revoked.")
			return
		}

		// Checked on every call (not just at connect time) so an admin
			// turning the org's AI Connector off immediately blocks tool
			// calls from already-connected clients too — without revoking
			// the underlying connection/tokens, so re-enabling needs no
			// reconnect.
			enabled, err := rt.repo.OrgAIConnectorEnabled(r.Context(), conn.OrgID)
			if err != nil {
				writeOAuthError(w, http.StatusInternalServerError, "server_error", "Failed to check AI connector status.")
				return
			}
			if !enabled {
				writeOAuthError(w, http.StatusForbidden, "access_denied", "The AI Connector is turned off for your organization.")
				return
			}

			scopeSet := make(map[string]bool, len(conn.Scopes))
		for _, s := range conn.Scopes {
			scopeSet[s] = true
		}
		ctx := context.WithValue(r.Context(), connectionContextKey, mcpIdentity{
			OrgID: conn.OrgID, UserID: conn.UserID, ConnectionID: conn.ID, Scopes: scopeSet,
		})
		next(w, r.WithContext(ctx))
	}
}

func mcpIdentityFrom(ctx context.Context) (mcpIdentity, bool) {
	id, ok := ctx.Value(connectionContextKey).(mcpIdentity)
	return id, ok
}

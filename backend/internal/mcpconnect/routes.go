package mcpconnect

import "github.com/go-chi/chi/v5"

// RegisterPublicRoutes mounts every endpoint an external MCP client talks to
// directly — discovery, registration, the authorization redirect entry
// point, the token endpoint, and the MCP tool endpoint itself. None of these
// carry our session cookie (the caller is a server, or a browser making a
// top-level navigation, never same-origin JS), so none sit behind
// requireAuth/RequireCSRF; /mcp instead uses requireMCPAuth (bearer token).
func (rt *Router) RegisterPublicRoutes(r chi.Router) {
	r.Get("/.well-known/oauth-authorization-server", rt.HandleAuthServerMetadata)
	r.Get("/.well-known/oauth-protected-resource", rt.HandleProtectedResourceMetadata)
	r.Post("/oauth/register", rt.HandleRegister)
	r.Get("/oauth/authorize", rt.HandleAuthorize)
	r.Post("/oauth/token", rt.HandleToken)
	r.Post("/mcp", rt.requireMCPAuth(rt.HandleMCP))
}

// RegisterRoutes mounts the endpoints our own frontend calls — the consent
// screen (details/approve/deny) and the settings-page connection list.
// Caller has already applied requireAuth + requireCSRF middleware.
func (rt *Router) RegisterRoutes(r chi.Router) {
	r.Get("/oauth/authorize/details", rt.HandleAuthorizeDetails)
	r.Post("/oauth/authorize/approve", rt.HandleAuthorizeApprove)
	r.Post("/oauth/authorize/deny", rt.HandleAuthorizeDeny)

	r.Get("/api/mcp-connections", rt.ListMyConnections)
	r.Delete("/api/mcp-connections/{connectionID}", rt.RevokeConnection)

	r.Get("/api/mcp-action-log", rt.ListMyActionLog)
	r.Post("/api/mcp-action-log/{entryID}/revert", rt.RevertActionLogEntry)
}

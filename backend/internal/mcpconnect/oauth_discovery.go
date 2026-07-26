package mcpconnect

import "net/http"

// HandleAuthServerMetadata handles GET /.well-known/oauth-authorization-server
// (RFC 8414). This is what lets a client (Claude, ChatGPT) auto-configure
// itself from just the server URL instead of the user hand-entering endpoints.
func (rt *Router) HandleAuthServerMetadata(w http.ResponseWriter, r *http.Request) {
	base := rt.cfg.MCPPublicURL
	writeSpecJSON(w, http.StatusOK, map[string]any{
		"issuer":                                 base,
		"authorization_endpoint":                 base + "/oauth/authorize",
		"token_endpoint":                         base + "/oauth/token",
		"registration_endpoint":                  base + "/oauth/register",
		"scopes_supported":                       AllScopes,
		"response_types_supported":               []string{"code"},
		"grant_types_supported":                  []string{"authorization_code", "refresh_token"},
		"code_challenge_methods_supported":       []string{"S256"},
		"token_endpoint_auth_methods_supported":  []string{"none"},
	})
}

// HandleProtectedResourceMetadata handles GET /.well-known/oauth-protected-resource
// (RFC 9728) — tells the client which authorization server protects /mcp.
func (rt *Router) HandleProtectedResourceMetadata(w http.ResponseWriter, r *http.Request) {
	base := rt.cfg.MCPPublicURL
	writeSpecJSON(w, http.StatusOK, map[string]any{
		"resource":              base + "/mcp",
		"authorization_servers": []string{base},
		"scopes_supported":      AllScopes,
	})
}

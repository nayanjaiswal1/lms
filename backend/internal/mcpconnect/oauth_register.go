package mcpconnect

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/url"
)

// HandleRegister handles POST /oauth/register — Dynamic Client Registration
// (RFC 7591). Claude/ChatGPT call this once, automatically, the first time a
// user adds the connector URL; no admin approval step, matching how every
// public MCP server handles first contact. Registered clients are public
// (token_endpoint_auth_method "none") — PKCE at the token endpoint is what
// authenticates the client, not a secret, since a distributed app like Claude
// Desktop cannot keep one safely.
func (rt *Router) HandleRegister(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClientName   string   `json:"client_name"`
		RedirectURIs []string `json:"redirect_uris"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "Malformed JSON body.")
		return
	}
	if req.ClientName == "" {
		req.ClientName = "MCP Client"
	}
	if len(req.RedirectURIs) == 0 {
		writeOAuthError(w, http.StatusBadRequest, "invalid_redirect_uri", "redirect_uris is required.")
		return
	}
	for _, u := range req.RedirectURIs {
		parsed, err := url.Parse(u)
		if err != nil || parsed.Scheme == "" || parsed.Host == "" {
			writeOAuthError(w, http.StatusBadRequest, "invalid_redirect_uri", "Every redirect_uri must be an absolute URL.")
			return
		}
	}

	clientID, err := randomHex(16)
	if err != nil {
		writeOAuthError(w, http.StatusInternalServerError, "server_error", "Failed to register client.")
		return
	}

	client, err := rt.repo.RegisterClient(r.Context(), clientID, req.ClientName, req.RedirectURIs)
	if err != nil {
		writeOAuthError(w, http.StatusInternalServerError, "server_error", "Failed to register client.")
		return
	}

	writeSpecJSON(w, http.StatusCreated, map[string]any{
		"client_id":                  client.ClientID,
		"client_name":                client.ClientName,
		"redirect_uris":              client.RedirectURIs,
		"token_endpoint_auth_method": "none",
		"grant_types":                []string{"authorization_code", "refresh_token"},
		"response_types":             []string{"code"},
	})
}

func randomHex(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

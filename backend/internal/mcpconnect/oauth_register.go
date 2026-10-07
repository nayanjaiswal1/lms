package mcpconnect

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"
	"unicode"
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
	r.Body = http.MaxBytesReader(w, r.Body, maxRegisterBodyBytes)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "Malformed or oversized JSON body.")
		return
	}
	req.ClientName = cleanClientName(req.ClientName)
	if len(req.RedirectURIs) == 0 {
		writeOAuthError(w, http.StatusBadRequest, "invalid_redirect_uri", "redirect_uris is required.")
		return
	}
	if len(req.RedirectURIs) > maxRedirectURIs {
		writeOAuthError(w, http.StatusBadRequest, "invalid_redirect_uri", "Too many redirect_uris.")
		return
	}
	for _, u := range req.RedirectURIs {
		if !validRedirectURI(u) {
			writeOAuthError(w, http.StatusBadRequest, "invalid_redirect_uri", "Every redirect_uri must be an https URL, or an http URL on localhost.")
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

const (
	maxRegisterBodyBytes = 8 << 10
	maxRedirectURIs      = 10
	maxRedirectURILen    = 2048
	maxClientNameLen     = 100
	defaultClientName    = "MCP Client"
)

// validRedirectURI accepts https URLs and http only for loopback hosts (native
// clients such as mcp-remote listen on localhost). Other schemes (javascript:,
// data:, file:) and fragments are rejected: the consent flow redirects the
// browser to this URI carrying an authorization code.
func validRedirectURI(raw string) bool {
	if len(raw) > maxRedirectURILen {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" || u.Fragment != "" || u.User != nil {
		return false
	}
	switch u.Scheme {
	case "https":
		return true
	case "http":
		host := u.Hostname()
		return host == "localhost" || host == "127.0.0.1" || host == "::1"
	}
	return false
}

// cleanClientName bounds and sanitizes the attacker-chosen display name shown
// on the consent screen: control characters are dropped and length is capped.
func cleanClientName(name string) string {
	clean := strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return -1
		}
		return r
	}, name))
	if runes := []rune(clean); len(runes) > maxClientNameLen {
		clean = string(runes[:maxClientNameLen])
	}
	if clean == "" {
		return defaultClientName
	}
	return clean
}

// redirectHost is the host the authorization code will be sent to, shown on
// the consent screen so a look-alike client name cannot hide a hostile redirect.
func redirectHost(raw string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	return u.Host
}

func randomHex(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

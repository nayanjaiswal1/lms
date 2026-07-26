package mcpconnect

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/auth"
)

// HandleToken handles POST /oauth/token (RFC 6749 §3.2). Real OAuth/MCP
// clients POST this as application/x-www-form-urlencoded, not JSON — this is
// the one endpoint in the package that must speak form encoding to be
// interoperable.
func (rt *Router) HandleToken(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "Malformed form body.")
		return
	}

	switch r.FormValue("grant_type") {
	case "authorization_code":
		rt.exchangeAuthorizationCode(w, r)
	case "refresh_token":
		rt.exchangeRefreshToken(w, r)
	default:
		writeOAuthError(w, http.StatusBadRequest, "unsupported_grant_type", "Only authorization_code and refresh_token are supported.")
	}
}

func (rt *Router) exchangeAuthorizationCode(w http.ResponseWriter, r *http.Request) {
	code := r.FormValue("code")
	if code == "" {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "code is required.")
		return
	}

	ac, err := rt.repo.ConsumeAuthCode(r.Context(), code)
	if err != nil {
		if errors.Is(err, ErrExpired) || errors.Is(err, ErrInvalidGrant) {
			writeOAuthError(w, http.StatusBadRequest, "invalid_grant", "Authorization code is invalid or expired.")
			return
		}
		writeOAuthError(w, http.StatusInternalServerError, "server_error", "Token exchange failed.")
		return
	}

	// A code is single-use the moment ConsumeAuthCode deletes it — every check
	// below runs after deletion, so a failure here cannot be retried with the
	// same code (matches RFC 6749 §4.1.2's replay-prevention requirement).
	if r.FormValue("client_id") != ac.ClientID {
		writeOAuthError(w, http.StatusBadRequest, "invalid_grant", "client_id does not match the authorization request.")
		return
	}
	if r.FormValue("redirect_uri") != ac.RedirectURI {
		writeOAuthError(w, http.StatusBadRequest, "invalid_grant", "redirect_uri does not match the authorization request.")
		return
	}
	if !verifyPKCE(r.FormValue("code_verifier"), ac.CodeChallenge) {
		writeOAuthError(w, http.StatusBadRequest, "invalid_grant", "code_verifier does not match code_challenge.")
		return
	}

	rt.issueTokens(w, r, ac.OrgID, ac.UserID, ac.ClientID, ac.Scopes, "")
}

func (rt *Router) exchangeRefreshToken(w http.ResponseWriter, r *http.Request) {
	raw := r.FormValue("refresh_token")
	if raw == "" {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "refresh_token is required.")
		return
	}

	conn, err := rt.repo.GetConnectionByRefreshHash(r.Context(), auth.HashToken(raw))
	if err != nil {
		writeOAuthError(w, http.StatusBadRequest, "invalid_grant", "Refresh token is invalid, expired, or revoked.")
		return
	}
	if clientID := r.FormValue("client_id"); clientID != "" && clientID != conn.ClientID {
		writeOAuthError(w, http.StatusBadRequest, "invalid_grant", "client_id does not match this refresh token.")
		return
	}

	rt.issueTokens(w, r, conn.OrgID, conn.UserID, conn.ClientID, conn.Scopes, conn.ID)
}

// issueTokens mints a fresh access token (always) and refresh token (always —
// rotation-on-use for an existing connection, initial issuance for a new
// one), persists the connection/token rows, and writes the token response.
// existingConnectionID is "" on first-time authorization (UpsertConnection
// creates the row); non-empty on a refresh (RotateRefreshToken updates it).
func (rt *Router) issueTokens(w http.ResponseWriter, r *http.Request, orgID, userID, clientID string, scopes []string, existingConnectionID string) {
	rawAccess, accessHash, err := auth.CreateRefreshToken()
	if err != nil {
		writeOAuthError(w, http.StatusInternalServerError, "server_error", "Token issuance failed.")
		return
	}
	rawRefresh, refreshHash, err := auth.CreateRefreshToken()
	if err != nil {
		writeOAuthError(w, http.StatusInternalServerError, "server_error", "Token issuance failed.")
		return
	}

	var connectionID string
	if existingConnectionID != "" {
		if err := rt.repo.RotateRefreshToken(r.Context(), existingConnectionID, refreshHash, time.Now().Add(refreshTokenTTL)); err != nil {
			writeOAuthError(w, http.StatusInternalServerError, "server_error", "Token issuance failed.")
			return
		}
		connectionID = existingConnectionID
	} else {
		connectionID, err = rt.repo.UpsertConnection(r.Context(), orgID, userID, clientID, scopes, refreshHash, time.Now().Add(refreshTokenTTL))
		if err != nil {
			writeOAuthError(w, http.StatusInternalServerError, "server_error", "Token issuance failed.")
			return
		}
	}

	if err := rt.repo.InsertAccessToken(r.Context(), connectionID, accessHash, time.Now().Add(accessTokenTTL)); err != nil {
		writeOAuthError(w, http.StatusInternalServerError, "server_error", "Token issuance failed.")
		return
	}

	writeSpecJSON(w, http.StatusOK, map[string]any{
		"access_token":  rawAccess,
		"token_type":    "Bearer",
		"expires_in":    int(accessTokenTTL.Seconds()),
		"refresh_token": rawRefresh,
		"scope":         strings.Join(scopes, " "),
	})
}

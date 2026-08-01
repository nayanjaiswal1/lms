package mcpconnect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

var errUnknownRedirect = errors.New("mcpconnect: redirect_uri not registered for this client")

// resolveAuthRequest validates client_id + redirect_uri together (never
// redirect to a URI we haven't confirmed the client registered — that would
// be an open redirect) and parses+validates the requested scope string.
// Shared by the details, approve, and deny handlers so all three agree on
// what "valid request" means.
func (rt *Router) resolveAuthRequest(ctx context.Context, clientID, redirectURI, scopeParam string) (Client, []string, error) {
	client, err := rt.repo.GetClient(ctx, clientID)
	if err != nil {
		return Client{}, nil, err
	}
	redirectOK := false
	for _, u := range client.RedirectURIs {
		if u == redirectURI {
			redirectOK = true
			break
		}
	}
	if !redirectOK {
		return Client{}, nil, errUnknownRedirect
	}

	var scopes []string
	for _, s := range strings.Fields(scopeParam) {
		if !validScope(s) {
			return Client{}, nil, fmt.Errorf("mcpconnect: unknown scope %q", s)
		}
		scopes = append(scopes, s)
	}
	if len(scopes) == 0 {
		scopes = AllScopes
	}
	return client, scopes, nil
}

// HandleAuthorize handles GET /oauth/authorize — the browser lands here via a
// top-level redirect from the external client. This handler only validates
// that the request is well-formed and the redirect_uri is one the client
// actually registered, then hands off to our own frontend's consent page,
// which enforces login (via existing middleware on /settings/*) and renders
// the approve/deny UI. We deliberately never render HTML from the Go backend —
// the design system lives entirely in the Next.js frontend.
func (rt *Router) HandleAuthorize(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()

	if q.Get("response_type") != "code" {
		writeOAuthError(w, http.StatusBadRequest, "unsupported_response_type", "Only response_type=code is supported.")
		return
	}
	if q.Get("code_challenge_method") != "S256" {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "code_challenge_method=S256 is required.")
		return
	}
	if q.Get("code_challenge") == "" {
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "code_challenge is required.")
		return
	}

	_, _, err := rt.resolveAuthRequest(r.Context(), q.Get("client_id"), q.Get("redirect_uri"), q.Get("scope"))
	if err != nil {
		// client_id/redirect_uri are unverified at this point — respond directly
		// rather than redirecting anywhere, since we cannot yet trust redirect_uri.
		writeOAuthError(w, http.StatusBadRequest, "invalid_request", "Unknown client or unregistered redirect_uri.")
		return
	}

	dest := rt.cfg.FrontendURL + "/settings/integrations/authorize?" + q.Encode()
	http.Redirect(w, r, dest, http.StatusFound)
}

// HandleAuthorizeDetails handles GET /oauth/authorize/details — called by our
// own consent page (authenticated, same-origin fetch) to render the client
// name and a human-readable scope list before the user approves.
func (rt *Router) HandleAuthorizeDetails(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}
	q := r.URL.Query()
	client, scopes, err := rt.resolveAuthRequest(r.Context(), q.Get("client_id"), q.Get("redirect_uri"), q.Get("scope"))
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Unknown client or unregistered redirect_uri.")
		return
	}
	descriptions := make([]string, 0, len(scopes))
	for _, s := range scopes {
		descriptions = append(descriptions, ScopeDescriptions[s])
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"client_name":        client.ClientName,
		"scopes":             scopes,
		"scope_descriptions": descriptions,
	})
}

type authorizeDecisionRequest struct {
	ClientID      string `json:"client_id"`
	RedirectURI   string `json:"redirect_uri"`
	Scope         string `json:"scope"`
	State         string `json:"state"`
	CodeChallenge string `json:"code_challenge"`
}

// HandleAuthorizeApprove handles POST /oauth/authorize/approve — the user
// clicked Approve on our consent page. Mints a single-use authorization code
// and returns the URL the frontend should navigate the browser to next
// (the external client's own redirect_uri, carrying the code).
func (rt *Router) HandleAuthorizeApprove(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	if enabled, err := rt.repo.OrgAIConnectorEnabled(r.Context(), claims.OrgID); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to check AI connector status.")
		return
	} else if !enabled {
		httputil.WriteError(w, http.StatusForbidden, "The AI Connector is turned off for your organization.")
		return
	}

	var req authorizeDecisionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	_, scopes, err := rt.resolveAuthRequest(r.Context(), req.ClientID, req.RedirectURI, req.Scope)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Unknown client or unregistered redirect_uri.")
		return
	}
	if req.CodeChallenge == "" {
		httputil.WriteError(w, http.StatusBadRequest, "Missing code_challenge.")
		return
	}

	code, err := randomHex(32)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to approve connection.")
		return
	}

	if err := rt.repo.InsertAuthCode(r.Context(), AuthCode{
		Code:          code,
		ClientID:      req.ClientID,
		OrgID:         claims.OrgID,
		UserID:        claims.UserID,
		Scopes:        scopes,
		CodeChallenge: req.CodeChallenge,
		RedirectURI:   req.RedirectURI,
		ExpiresAt:     time.Now().Add(authCodeTTL),
	}); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to approve connection.")
		return
	}

	params := map[string]string{"code": code}
	if req.State != "" {
		params["state"] = req.State
	}
	redirectURL, err := appendRedirectParams(req.RedirectURI, params)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to approve connection.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"redirect_url": redirectURL})
}

// appendRedirectParams merges params into rawURL's query string. redirectURI
// values only ever reach here after resolveAuthRequest has confirmed they
// exactly match one of the client's registered (and registration-time
// URL-parsed) redirect_uris, so a parse failure here would indicate a bug
// rather than user input — still handled explicitly rather than assumed away.
func appendRedirectParams(rawURL string, params map[string]string) (string, error) {
	dest, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("mcpconnect: parse redirect_uri: %w", err)
	}
	qs := dest.Query()
	for k, v := range params {
		qs.Set(k, v)
	}
	dest.RawQuery = qs.Encode()
	return dest.String(), nil
}

// HandleAuthorizeDeny handles POST /oauth/authorize/deny — the user clicked
// Deny; returns the redirect_url carrying the standard access_denied error
// instead of a code, so the external client's own UI shows the rejection.
func (rt *Router) HandleAuthorizeDeny(w http.ResponseWriter, r *http.Request) {
	if _, ok := auth.RequireClaims(w, r); !ok {
		return
	}
	var req authorizeDecisionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if _, _, err := rt.resolveAuthRequest(r.Context(), req.ClientID, req.RedirectURI, req.Scope); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Unknown client or unregistered redirect_uri.")
		return
	}

	params := map[string]string{"error": "access_denied"}
	if req.State != "" {
		params["state"] = req.State
	}
	redirectURL, err := appendRedirectParams(req.RedirectURI, params)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to record denial.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"redirect_url": redirectURL})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return false
	}
	return true
}

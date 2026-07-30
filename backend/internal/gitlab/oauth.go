package gitlab

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Scopes requested for each OAuth flow. The installation's own service
// account needs broad admin API access; a member's personal connection is
// least-privilege at connect time (kind-herding-cookie.md §0's confirmed
// default) — incremental re-consent for anything wider (e.g. capstone
// handoff) is a later-batch concern, not built here.
var (
	InstallationOAuthScopes = []string{"api"}
	ConnectionOAuthScopes   = []string{"read_user", "read_repository", "write_repository"}
)

// GeneratePKCE returns a random S256 PKCE verifier/challenge pair (RFC 7636).
// The verifier is persisted server-side (gitlab_oauth_states) rather than a
// cookie because it must survive a cross-site top-level redirect back from
// the GitLab instance.
func GeneratePKCE() (verifier, challenge string, err error) {
	buf := make([]byte, 32)
	if _, err = rand.Read(buf); err != nil {
		return "", "", fmt.Errorf("gitlab: generate pkce verifier: %w", err)
	}
	verifier = base64.RawURLEncoding.EncodeToString(buf)
	sum := sha256.Sum256([]byte(verifier))
	challenge = base64.RawURLEncoding.EncodeToString(sum[:])
	return verifier, challenge, nil
}

// AuthorizeURL builds the {baseURL}/oauth/authorize redirect target for a
// GitLab OAuth authorization-code+PKCE consent request.
func AuthorizeURL(baseURL, clientID, redirectURI, state, codeChallenge string, scopes []string) string {
	q := url.Values{}
	q.Set("client_id", clientID)
	q.Set("redirect_uri", redirectURI)
	q.Set("response_type", "code")
	q.Set("scope", strings.Join(scopes, " "))
	q.Set("state", state)
	q.Set("code_challenge", codeChallenge)
	q.Set("code_challenge_method", "S256")
	return strings.TrimRight(baseURL, "/") + "/oauth/authorize?" + q.Encode()
}

// TokenResponse is GitLab's OAuth token endpoint response shape.
type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	CreatedAt    int64  `json:"created_at"`
	Scope        string `json:"scope"`
}

// ExpiresAt computes the absolute expiry from GitLab's relative expires_in +
// created_at (unix seconds); falls back to time.Now() when created_at is
// absent (some self-hosted versions omit it).
func (t *TokenResponse) ExpiresAt() time.Time {
	base := time.Now()
	if t.CreatedAt > 0 {
		base = time.Unix(t.CreatedAt, 0)
	}
	return base.Add(time.Duration(t.ExpiresIn) * time.Second)
}

// ExchangeCode exchanges an authorization code + PKCE verifier for an
// access/refresh token pair against {baseURL}/oauth/token. Hand-rolled rather
// than golang.org/x/oauth2.Config (as auth/social.go uses for Google/GitHub)
// because baseURL is per-org runtime data, not a compile-time oauth2.Endpoint.
func ExchangeCode(ctx context.Context, httpClient *http.Client, baseURL, clientID, clientSecret, code, verifier, redirectURI string) (*TokenResponse, error) {
	form := url.Values{
		"client_id":     {clientID},
		"grant_type":    {"authorization_code"},
		"code":          {code},
		"redirect_uri":  {redirectURI},
		"code_verifier": {verifier},
	}
	if clientSecret != "" {
		form.Set("client_secret", clientSecret)
	}
	tok, err := postTokenForm(ctx, httpClient, baseURL, form)
	if err != nil {
		return nil, fmt.Errorf("gitlab: exchange code: %w", err)
	}
	return tok, nil
}

// RefreshToken exchanges a refresh token for a new access/refresh token pair.
func RefreshToken(ctx context.Context, httpClient *http.Client, baseURL, clientID, clientSecret, refreshToken string) (*TokenResponse, error) {
	form := url.Values{
		"client_id":     {clientID},
		"grant_type":    {"refresh_token"},
		"refresh_token": {refreshToken},
	}
	if clientSecret != "" {
		form.Set("client_secret", clientSecret)
	}
	tok, err := postTokenForm(ctx, httpClient, baseURL, form)
	if err != nil {
		return nil, fmt.Errorf("gitlab: refresh token: %w", err)
	}
	return tok, nil
}

// RevokeToken revokes an access or refresh token against {baseURL}/oauth/revoke.
func RevokeToken(ctx context.Context, httpClient *http.Client, baseURL, clientID, clientSecret, token string) error {
	form := url.Values{
		"client_id": {clientID},
		"token":     {token},
	}
	if clientSecret != "" {
		form.Set("client_secret", clientSecret)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+"/oauth/revoke", strings.NewReader(form.Encode()))
	if err != nil {
		return fmt.Errorf("gitlab: build revoke request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("gitlab: revoke token request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return fmt.Errorf("gitlab: revoke token failed with status %d", resp.StatusCode)
	}
	return nil
}

func postTokenForm(ctx context.Context, httpClient *http.Client, baseURL string, form url.Values) (*TokenResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+"/oauth/token", strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("build token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("token request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		var apiErr struct {
			Error            string `json:"error"`
			ErrorDescription string `json:"error_description"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&apiErr)
		if apiErr.Error != "" {
			return nil, fmt.Errorf("token request failed: %s: %s", apiErr.Error, apiErr.ErrorDescription)
		}
		return nil, fmt.Errorf("token request failed with status %d", resp.StatusCode)
	}

	var tok TokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tok); err != nil {
		return nil, fmt.Errorf("decode token response: %w", err)
	}
	return &tok, nil
}

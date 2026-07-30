package gitlab

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

const oauthStateTTL = 10 * time.Minute

// CreateInstallationPAT validates a Personal Access Token and adds it to the
// org's installation pool as a new named entry — completes synchronously, no
// redirect round trip. oauthClientID/oauthClientSecret are optional even
// under a PAT install: setting them lets members personally connect via
// OAuth even though this installation itself authenticated with a plain
// token.
func (s *Service) CreateInstallationPAT(ctx context.Context, orgID, createdBy, name, baseURL, pat, oauthClientID, oauthClientSecret string) (*GitlabInstallation, error) {
	user, tier, accessTokenEnc, clientIDPtr, secretEnc, err := s.verifyAndEncryptPAT(ctx, baseURL, pat, oauthClientID, oauthClientSecret)
	if err != nil {
		return nil, err
	}
	return s.repo.CreateInstallationPAT(ctx, orgID, name, baseURL, tier, user.ID, user.Username, accessTokenEnc, clientIDPtr, secretEnc, createdBy)
}

// UpdateInstallationPAT re-verifies a Personal Access Token and replaces an
// existing pool entry's credentials in-place.
func (s *Service) UpdateInstallationPAT(ctx context.Context, orgID, id, baseURL, pat, oauthClientID, oauthClientSecret string) (*GitlabInstallation, error) {
	user, tier, accessTokenEnc, clientIDPtr, secretEnc, err := s.verifyAndEncryptPAT(ctx, baseURL, pat, oauthClientID, oauthClientSecret)
	if err != nil {
		return nil, err
	}
	return s.repo.UpdateInstallationPAT(ctx, orgID, id, baseURL, tier, user.ID, user.Username, accessTokenEnc, clientIDPtr, secretEnc)
}

func (s *Service) verifyAndEncryptPAT(ctx context.Context, baseURL, pat, oauthClientID, oauthClientSecret string) (user *GitlabUser, tier string, accessTokenEnc []byte, clientIDPtr *string, secretEnc []byte, err error) {
	client := NewClient(baseURL, pat)
	user, err = client.VerifyUser(ctx)
	if err != nil {
		return nil, "", nil, nil, nil, fmt.Errorf("gitlab: verify personal access token: %w", err)
	}
	var tierErr error
	tier, tierErr = client.DetectTier(ctx)
	if tierErr != nil {
		// Tier detection failing is not fatal to installing — default to free
		// and let a later re-verify refine it.
		tier = TierFree
	}

	accessTokenEnc, err = s.vault.Encrypt([]byte(pat))
	if err != nil {
		return nil, "", nil, nil, nil, fmt.Errorf("gitlab: encrypt access token: %w", err)
	}

	if oauthClientID != "" {
		clientIDPtr = &oauthClientID
		if oauthClientSecret != "" {
			secretEnc, err = s.vault.Encrypt([]byte(oauthClientSecret))
			if err != nil {
				return nil, "", nil, nil, nil, fmt.Errorf("gitlab: encrypt oauth client secret: %w", err)
			}
		}
	}
	return user, tier, accessTokenEnc, clientIDPtr, secretEnc, nil
}

// StartInstallOAuth begins the installation-purpose OAuth+PKCE flow: an org
// admin registers a GitLab OAuth Application themselves (client_id, and a
// secret if it's a confidential app) and this call stores that plus a fresh
// PKCE pair in gitlab_oauth_states, returning the URL to redirect the
// admin's browser to. GET /api/gitlab/callback (purpose=installation)
// completes it. installationID nil creates a new pool entry named name;
// non-nil reconnects that existing entry (name is ignored — reconnecting
// never renames).
func (s *Service) StartInstallOAuth(ctx context.Context, orgID, userID string, installationID *string, name, baseURL, oauthClientID, oauthClientSecret string) (authorizeURL string, err error) {
	return s.startOAuthFlow(ctx, orgID, userID, OAuthPurposeInstallation, &name, installationID, baseURL, oauthClientID, oauthClientSecret, InstallationOAuthScopes)
}

// StartConnect begins a member's personal OAuth+PKCE connection flow,
// reusing the OAuth Application already registered on the org's default
// installation — see Service.userClientFor's own doc comment for why
// personal connections don't carry their own installation selection.
// Returns ErrNoOAuthApp if that installation has none configured, or
// ErrNotFound if there's no default installation at all yet — either way
// the caller surfaces "ask your admin to connect GitLab first."
func (s *Service) StartConnect(ctx context.Context, orgID, userID string) (authorizeURL string, err error) {
	inst, err := s.repo.GetDefaultInstallation(ctx, orgID)
	if err != nil {
		return "", err
	}
	if inst.OAuthClientID == nil || *inst.OAuthClientID == "" {
		return "", ErrNoOAuthApp
	}
	var secret string
	if inst.OAuthClientSecretEnc != nil {
		dec, decErr := s.vault.Decrypt(inst.OAuthClientSecretEnc)
		if decErr != nil {
			return "", fmt.Errorf("gitlab: decrypt installation oauth client secret: %w", decErr)
		}
		secret = string(dec)
	}
	return s.startOAuthFlow(ctx, orgID, userID, OAuthPurposeConnection, nil, nil, inst.BaseURL, *inst.OAuthClientID, secret, ConnectionOAuthScopes)
}

func (s *Service) startOAuthFlow(ctx context.Context, orgID, userID, purpose string, name, installationID *string, baseURL, oauthClientID, oauthClientSecret string, scopes []string) (string, error) {
	verifier, challenge, err := GeneratePKCE()
	if err != nil {
		return "", err
	}
	state, err := randomState()
	if err != nil {
		return "", err
	}

	var secretEnc []byte
	if oauthClientSecret != "" {
		secretEnc, err = s.vault.Encrypt([]byte(oauthClientSecret))
		if err != nil {
			return "", fmt.Errorf("gitlab: encrypt oauth client secret: %w", err)
		}
	}

	if err := s.repo.InsertOAuthState(ctx, GitlabOAuthState{
		State:                state,
		OrgID:                orgID,
		UserID:               userID,
		Purpose:              purpose,
		CodeVerifier:         verifier,
		BaseURL:              &baseURL,
		OAuthClientID:        &oauthClientID,
		OAuthClientSecretEnc: secretEnc,
		Name:                 name,
		InstallationID:       installationID,
		ExpiresAt:            time.Now().Add(oauthStateTTL),
	}); err != nil {
		return "", err
	}

	return AuthorizeURL(baseURL, oauthClientID, s.callbackURL(), state, challenge, scopes), nil
}

// CompleteCallback finishes whichever flow `state` belongs to: exchanges the
// authorization code for tokens against the flow's own stored base_url and
// OAuth Application credentials, verifies the resulting identity, and
// persists the installation or connection row accordingly. Returns the
// purpose so the HTTP handler knows which frontend page to redirect back to.
func (s *Service) CompleteCallback(ctx context.Context, state, code string) (purpose string, err error) {
	st, err := s.repo.GetOAuthState(ctx, state)
	if err != nil {
		return "", err
	}
	if st.BaseURL == nil || st.OAuthClientID == nil {
		return "", fmt.Errorf("gitlab: oauth state missing base_url/client_id")
	}

	var clientSecret string
	if st.OAuthClientSecretEnc != nil {
		dec, decErr := s.vault.Decrypt(st.OAuthClientSecretEnc)
		if decErr != nil {
			return "", fmt.Errorf("gitlab: decrypt oauth state client secret: %w", decErr)
		}
		clientSecret = string(dec)
	}

	httpClient := &http.Client{Timeout: 15 * time.Second}
	tok, err := ExchangeCode(ctx, httpClient, *st.BaseURL, *st.OAuthClientID, clientSecret, code, st.CodeVerifier, s.callbackURL())
	if err != nil {
		return "", err
	}

	glClient := NewClient(*st.BaseURL, tok.AccessToken)
	user, err := glClient.VerifyUser(ctx)
	if err != nil {
		return "", fmt.Errorf("gitlab: verify user after oauth exchange: %w", err)
	}

	accessTokenEnc, err := s.vault.Encrypt([]byte(tok.AccessToken))
	if err != nil {
		return "", fmt.Errorf("gitlab: encrypt access token: %w", err)
	}
	var refreshTokenEnc []byte
	if tok.RefreshToken != "" {
		refreshTokenEnc, err = s.vault.Encrypt([]byte(tok.RefreshToken))
		if err != nil {
			return "", fmt.Errorf("gitlab: encrypt refresh token: %w", err)
		}
	}

	switch st.Purpose {
	case OAuthPurposeInstallation:
		tier, tierErr := glClient.DetectTier(ctx)
		if tierErr != nil {
			tier = TierFree
		}
		var secretEnc []byte
		if clientSecret != "" {
			secretEnc, err = s.vault.Encrypt([]byte(clientSecret))
			if err != nil {
				return "", fmt.Errorf("gitlab: re-encrypt oauth client secret: %w", err)
			}
		}
		if st.InstallationID != nil {
			if _, err := s.repo.FinalizeInstallationOAuthUpdate(ctx, state, st.OrgID, *st.InstallationID, *st.BaseURL, tier, user.ID, user.Username, accessTokenEnc, tok.ExpiresAt(), refreshTokenEnc, st.OAuthClientID, secretEnc); err != nil {
				return "", err
			}
			return OAuthPurposeInstallation, nil
		}
		name := "Default"
		if st.Name != nil && *st.Name != "" {
			name = *st.Name
		}
		if _, err := s.repo.FinalizeInstallationOAuthCreate(ctx, state, st.OrgID, name, *st.BaseURL, tier, user.ID, user.Username, accessTokenEnc, tok.ExpiresAt(), refreshTokenEnc, st.OAuthClientID, secretEnc, st.UserID); err != nil {
			return "", err
		}
		return OAuthPurposeInstallation, nil

	case OAuthPurposeConnection:
		var email, avatar *string
		if user.Email != "" {
			email = &user.Email
		}
		if user.AvatarURL != "" {
			avatar = &user.AvatarURL
		}
		if _, err := s.repo.FinalizeConnectionOAuth(ctx, state, st.OrgID, st.UserID, user.ID, user.Username, email, avatar, accessTokenEnc, tok.ExpiresAt(), refreshTokenEnc, ConnectionOAuthScopes); err != nil {
			return "", err
		}
		return OAuthPurposeConnection, nil

	default:
		return "", fmt.Errorf("gitlab: unknown oauth state purpose %q", st.Purpose)
	}
}

func (s *Service) callbackURL() string {
	return s.cfg.BackendURL + "/api/gitlab/callback"
}

func randomState() (string, error) {
	buf := make([]byte, 24)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("gitlab: generate oauth state: %w", err)
	}
	return hex.EncodeToString(buf), nil
}

// RefreshExpiringTokens refreshes OAuth-kind installation and connection
// tokens expiring within `window` — called by the gitlab.token_refresh cron
// job. A refresh failure (e.g. invalid_grant because the token was revoked
// on GitLab's side) flags the row status='expired' rather than retrying
// forever; the org admin / member sees "reconnect" the next time they load
// the settings page's status view.
func (s *Service) RefreshExpiringTokens(ctx context.Context, window time.Duration) error {
	before := time.Now().Add(window)
	httpClient := &http.Client{Timeout: 15 * time.Second}

	installations, err := s.repo.ListExpiringOAuthInstallations(ctx, before)
	if err != nil {
		return fmt.Errorf("gitlab: refresh tokens: list installations: %w", err)
	}
	for _, inst := range installations {
		if err := s.refreshInstallation(ctx, httpClient, inst); err != nil {
			slog.ErrorContext(ctx, "gitlab: refresh installation token failed", "org_id", inst.OrgID, "error", err)
		}
	}

	connections, err := s.repo.ListExpiringConnections(ctx, before)
	if err != nil {
		return fmt.Errorf("gitlab: refresh tokens: list connections: %w", err)
	}
	for _, conn := range connections {
		if err := s.refreshConnection(ctx, httpClient, conn); err != nil {
			slog.ErrorContext(ctx, "gitlab: refresh connection token failed", "org_id", conn.OrgID, "user_id", conn.UserID, "error", err)
		}
	}
	return nil
}

func (s *Service) refreshInstallation(ctx context.Context, httpClient *http.Client, inst GitlabInstallation) error {
	if inst.RefreshTokenEnc == nil || inst.OAuthClientID == nil {
		return s.repo.MarkInstallationExpired(ctx, inst.ID, "no refresh token or oauth application on file")
	}
	refreshToken, err := s.vault.Decrypt(inst.RefreshTokenEnc)
	if err != nil {
		return fmt.Errorf("decrypt refresh token: %w", err)
	}
	var secret string
	if inst.OAuthClientSecretEnc != nil {
		if dec, decErr := s.vault.Decrypt(inst.OAuthClientSecretEnc); decErr == nil {
			secret = string(dec)
		}
	}

	tok, refreshErr := RefreshToken(ctx, httpClient, inst.BaseURL, *inst.OAuthClientID, secret, string(refreshToken))
	if refreshErr != nil {
		return s.repo.MarkInstallationExpired(ctx, inst.ID, refreshErr.Error())
	}

	accessTokenEnc, err := s.vault.Encrypt([]byte(tok.AccessToken))
	if err != nil {
		return fmt.Errorf("encrypt refreshed access token: %w", err)
	}
	newRefreshEnc := inst.RefreshTokenEnc
	if tok.RefreshToken != "" {
		newRefreshEnc, err = s.vault.Encrypt([]byte(tok.RefreshToken))
		if err != nil {
			return fmt.Errorf("encrypt refreshed refresh token: %w", err)
		}
	}
	return s.repo.UpdateInstallationTokens(ctx, inst.ID, accessTokenEnc, tok.ExpiresAt(), newRefreshEnc)
}

func (s *Service) refreshConnection(ctx context.Context, httpClient *http.Client, conn GitlabConnection) error {
	inst, err := s.repo.GetDefaultInstallation(ctx, conn.OrgID)
	if err != nil || inst.OAuthClientID == nil {
		return s.repo.MarkConnectionExpired(ctx, conn.OrgID, conn.UserID)
	}
	if conn.RefreshTokenEnc == nil {
		return s.repo.MarkConnectionExpired(ctx, conn.OrgID, conn.UserID)
	}
	refreshToken, err := s.vault.Decrypt(conn.RefreshTokenEnc)
	if err != nil {
		return fmt.Errorf("decrypt refresh token: %w", err)
	}
	var secret string
	if inst.OAuthClientSecretEnc != nil {
		if dec, decErr := s.vault.Decrypt(inst.OAuthClientSecretEnc); decErr == nil {
			secret = string(dec)
		}
	}

	tok, refreshErr := RefreshToken(ctx, httpClient, inst.BaseURL, *inst.OAuthClientID, secret, string(refreshToken))
	if refreshErr != nil {
		return s.repo.MarkConnectionExpired(ctx, conn.OrgID, conn.UserID)
	}

	accessTokenEnc, err := s.vault.Encrypt([]byte(tok.AccessToken))
	if err != nil {
		return fmt.Errorf("encrypt refreshed access token: %w", err)
	}
	newRefreshEnc := conn.RefreshTokenEnc
	if tok.RefreshToken != "" {
		newRefreshEnc, err = s.vault.Encrypt([]byte(tok.RefreshToken))
		if err != nil {
			return fmt.Errorf("encrypt refreshed refresh token: %w", err)
		}
	}
	return s.repo.UpdateConnectionTokens(ctx, conn.OrgID, conn.UserID, accessTokenEnc, tok.ExpiresAt(), newRefreshEnc)
}

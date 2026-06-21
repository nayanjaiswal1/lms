package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/httputil"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/github"
	"golang.org/x/oauth2/google"
)

type providerUser struct {
	ProviderUID   string
	Email         string
	EmailVerified bool
	Name          string
	AvatarURL     string
}

func (h *Handler) oauthConfig(provider string) (*oauth2.Config, error) {
	switch provider {
	case "google":
		return &oauth2.Config{
			ClientID:     h.cfg.GoogleClientID,
			ClientSecret: h.cfg.GoogleClientSecret,
			RedirectURL:  h.cfg.BackendURL + "/api/auth/google/callback",
			Scopes:       []string{"openid", "email", "profile"},
			Endpoint:     google.Endpoint,
		}, nil
	case "github":
		return &oauth2.Config{
			ClientID:     h.cfg.GitHubClientID,
			ClientSecret: h.cfg.GitHubClientSecret,
			RedirectURL:  h.cfg.BackendURL + "/api/auth/github/callback",
			Scopes:       []string{"user:email"},
			Endpoint:     github.Endpoint,
		}, nil
	default:
		return nil, fmt.Errorf("unknown provider: %s", provider)
	}
}

// HandleOAuthRedirect starts the OAuth flow for the given provider.
// Returns an http.HandlerFunc so it can be registered once per provider.
func (h *Handler) HandleOAuthRedirect(provider string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cfg, err := h.oauthConfig(provider)
		if err != nil {
			httputil.WriteError(w, http.StatusBadRequest, "Unknown provider.")
			return
		}

		state, err := randomHex(16)
		if err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Failed to initiate login.")
			return
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "oauth_state",
			Value:    state,
			Path:     "/",
			MaxAge:   300,
			HttpOnly: true,
			SameSite: http.SameSiteLaxMode,
			Secure:   h.cfg.IsProd(),
		})

		http.Redirect(w, r, cfg.AuthCodeURL(state, oauth2.AccessTypeOnline), http.StatusTemporaryRedirect)
	}
}

// HandleOAuthCallback receives the provider redirect after user authorization,
// exchanges the code for user info, finds or creates the MindForge account,
// issues a short-lived exchange token, then redirects to the Next.js callback page.
func (h *Handler) HandleOAuthCallback(provider string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// The success redirect carries the one-time exchange token in its query
		// string; suppress the Referer header so the token cannot leak to any
		// third-party origin the destination page might contact.
		w.Header().Set("Referrer-Policy", "no-referrer")

		errRedirect := func(code string) {
			http.Redirect(w, r, h.cfg.FrontendURL+"/login?error="+code, http.StatusTemporaryRedirect)
		}

		stateCookie, err := r.Cookie("oauth_state")
		if err != nil || stateCookie.Value == "" || stateCookie.Value != r.URL.Query().Get("state") {
			errRedirect("state_mismatch")
			return
		}

		http.SetCookie(w, &http.Cookie{
			Name:     "oauth_state",
			Value:    "",
			Path:     "/",
			MaxAge:   -1,
			HttpOnly: true,
			SameSite: http.SameSiteLaxMode,
		})

		code := r.URL.Query().Get("code")
		if code == "" {
			errRedirect("missing_code")
			return
		}

		oauthCfg, err := h.oauthConfig(provider)
		if err != nil {
			errRedirect("unknown_provider")
			return
		}

		token, err := oauthCfg.Exchange(r.Context(), code)
		if err != nil {
			slog.Error("auth: oauth callback exchange", "provider", provider, "error", err)
			errRedirect("exchange_failed")
			return
		}

		pUser, err := h.getProviderUser(r.Context(), provider, oauthCfg, token)
		if err != nil {
			slog.Error("auth: oauth callback get user", "provider", provider, "error", err)
			errRedirect("userinfo_failed")
			return
		}

		userID, onboardingCompleted, err := h.findOrCreateSocialUser(r.Context(), provider, pUser)
		if err != nil {
			slog.Error("auth: oauth callback find/create user", "provider", provider, "error", err)
			errRedirect("account_error")
			return
		}

		exchangeToken, err := randomHex(32)
		if err != nil {
			slog.Error("auth: oauth callback exchange token", "error", err)
			errRedirect("server_error")
			return
		}

		if _, err := h.pool.Exec(r.Context(),
			`INSERT INTO oauth_exchanges (token, user_id, onboarding_completed, expires_at)
			 VALUES ($1, $2, $3, $4)`,
			exchangeToken, userID, onboardingCompleted,
			time.Now().Add(2*time.Minute),
		); err != nil {
			slog.Error("auth: oauth callback insert exchange", "error", err)
			errRedirect("server_error")
			return
		}

		http.Redirect(w, r,
			h.cfg.FrontendURL+"/auth/callback?token="+exchangeToken,
			http.StatusTemporaryRedirect,
		)
	}
}

// HandleSocialExchange consumes a one-time exchange token and issues full auth cookies.
// Called server-to-server by Next.js after the OAuth callback redirect lands on the browser.
func (h *Handler) HandleSocialExchange(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "Token is required.")
		return
	}

	var exID, userID string
	var onboardingCompleted bool
	err := h.pool.QueryRow(r.Context(),
		`SELECT id, user_id, onboarding_completed
		 FROM oauth_exchanges
		 WHERE token = $1 AND used_at IS NULL AND expires_at > now()`,
		req.Token,
	).Scan(&exID, &userID, &onboardingCompleted)
	if err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired exchange token.")
		return
	}

	if _, err := h.pool.Exec(r.Context(),
		`UPDATE oauth_exchanges SET used_at = now() WHERE id = $1`, exID,
	); err != nil {
		slog.Error("auth: social exchange mark used", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	if err := h.enforceMaxSessions(r.Context(), userID); err != nil {
		slog.Error("auth: social exchange enforce max sessions", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	// Fetch user first so SessionVersion is available for the access token claim.
	type userRow struct {
		ID             string
		Name           string
		Email          string
		AvatarURL      *string
		SessionVersion int
	}
	var u userRow
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, session_version FROM users WHERE id = $1`, userID,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.SessionVersion); err != nil {
		slog.Error("auth: social exchange get user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	var orgRole string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT role FROM org_members WHERE org_id = $1 AND user_id = $2`,
		h.cfg.DefaultOrgID, userID,
	).Scan(&orgRole); err != nil {
		orgRole = "student"
	}

	accessToken, err := CreateAccessToken(h.cfg, Claims{
		UserID:         userID,
		OrgID:          h.cfg.DefaultOrgID,
		OrgRole:        orgRole,
		AuthMethod:     "social",
		SessionVersion: u.SessionVersion,
	})
	if err != nil {
		slog.Error("auth: social exchange create access token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	rawRefresh, refreshHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: social exchange create refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	familyID, err := randomHex(16)
	if err != nil {
		slog.Error("auth: social exchange generate family_id", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, family_id, device_hint, ip)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		userID, refreshHash,
		time.Now().Add(h.cfg.RefreshTokenTTL),
		familyID, truncate(r.Header.Get("User-Agent"), 200), firstThreeOctets(r.RemoteAddr),
	); err != nil {
		slog.Error("auth: social exchange insert refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	csrfToken, err := CreateCSRFToken(h.cfg)
	if err != nil {
		slog.Error("auth: social exchange generate csrf token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	orgs, err := h.queryUserOrgs(r.Context(), u.ID)
	if err != nil {
		slog.Error("auth: social exchange query orgs", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Exchange failed.")
		return
	}

	setAccessCookie(w, h.cfg, accessToken)
	setRefreshCookie(w, h.cfg, rawRefresh)
	setCSRFCookie(w, h.cfg, csrfToken)

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"user": userResponse{
			ID:        u.ID,
			Name:      u.Name,
			Email:     u.Email,
			AvatarURL: u.AvatarURL,
		},
		"orgs":                 orgs,
		"onboarding_completed": onboardingCompleted,
	})
}

// ─── provider user fetching ───────────────────────────────────────────────────

func (h *Handler) getProviderUser(ctx context.Context, provider string, cfg *oauth2.Config, token *oauth2.Token) (*providerUser, error) {
	client := cfg.Client(ctx, token)
	switch provider {
	case "google":
		return getGoogleUser(ctx, client)
	case "github":
		return getGitHubUser(ctx, client)
	default:
		return nil, fmt.Errorf("unknown provider: %s", provider)
	}
}

func getGoogleUser(ctx context.Context, client *http.Client) (*providerUser, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://www.googleapis.com/oauth2/v3/userinfo", nil)
	if err != nil {
		return nil, fmt.Errorf("google userinfo request: %w", err)
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("google userinfo: %w", err)
	}
	defer resp.Body.Close()

	var g struct {
		Sub           string `json:"sub"`
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
		Name          string `json:"name"`
		Picture       string `json:"picture"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&g); err != nil {
		return nil, fmt.Errorf("google userinfo decode: %w", err)
	}
	if g.Sub == "" {
		return nil, fmt.Errorf("google userinfo: empty sub")
	}

	return &providerUser{
		ProviderUID:   g.Sub,
		Email:         g.Email,
		EmailVerified: g.EmailVerified,
		Name:          g.Name,
		AvatarURL:     g.Picture,
	}, nil
}

func getGitHubUser(ctx context.Context, client *http.Client) (*providerUser, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.github.com/user", nil)
	if err != nil {
		return nil, fmt.Errorf("github user request: %w", err)
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("github user: %w", err)
	}
	defer resp.Body.Close()

	var g struct {
		ID        int    `json:"id"`
		Login     string `json:"login"`
		Name      string `json:"name"`
		AvatarURL string `json:"avatar_url"`
		Email     string `json:"email"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&g); err != nil {
		return nil, fmt.Errorf("github user decode: %w", err)
	}
	if g.ID == 0 {
		return nil, fmt.Errorf("github user: empty id")
	}

	name := g.Name
	if name == "" {
		name = g.Login
	}

	// GitHub only exposes verified addresses: the public-profile email must be a
	// verified address, and getGitHubPrimaryEmail filters on Primary && Verified.
	// A non-empty resolved email is therefore always verified.
	email := g.Email
	if email == "" {
		email, _ = getGitHubPrimaryEmail(ctx, client)
	}

	return &providerUser{
		ProviderUID:   fmt.Sprintf("%d", g.ID),
		Email:         email,
		EmailVerified: email != "",
		Name:          name,
		AvatarURL:     g.AvatarURL,
	}, nil
}

func getGitHubPrimaryEmail(ctx context.Context, client *http.Client) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.github.com/user/emails", nil)
	if err != nil {
		return "", fmt.Errorf("github emails request: %w", err)
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("github emails: %w", err)
	}
	defer resp.Body.Close()

	var emails []struct {
		Email    string `json:"email"`
		Primary  bool   `json:"primary"`
		Verified bool   `json:"verified"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&emails); err != nil {
		return "", fmt.Errorf("github emails decode: %w", err)
	}

	for _, e := range emails {
		if e.Primary && e.Verified {
			return e.Email, nil
		}
	}
	return "", nil
}

// ─── user upsert ─────────────────────────────────────────────────────────────

func (h *Handler) findOrCreateSocialUser(ctx context.Context, provider string, p *providerUser) (userID string, onboardingCompleted bool, err error) {
	// Social account already linked → fast path
	err = h.pool.QueryRow(ctx,
		`SELECT user_id FROM social_accounts WHERE provider = $1 AND provider_uid = $2`,
		provider, p.ProviderUID,
	).Scan(&userID)
	if err == nil {
		onboardingCompleted, err = h.checkOnboardingCompleted(ctx, userID)
		return
	}

	// Email match → link social account to existing user.
	// Only auto-link on a provider-verified email; trusting an unverified address
	// would let an attacker take over an existing account by asserting its email.
	if p.Email != "" && p.EmailVerified {
		err = h.pool.QueryRow(ctx,
			`SELECT id FROM users WHERE email = $1`, p.Email,
		).Scan(&userID)
		if err == nil {
			if _, err = h.pool.Exec(ctx,
				`INSERT INTO social_accounts (user_id, provider, provider_uid, email)
				 VALUES ($1, $2, $3, $4)
				 ON CONFLICT (provider, provider_uid) DO NOTHING`,
				userID, provider, p.ProviderUID, p.Email,
			); err != nil {
				return "", false, fmt.Errorf("link social account: %w", err)
			}
			onboardingCompleted, err = h.checkOnboardingCompleted(ctx, userID)
			return
		}
	}

	// No existing user → create account
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return "", false, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	email := p.Email
	if email == "" {
		email = fmt.Sprintf("%s+%s@noreply.invalid", provider, p.ProviderUID)
	}

	avatarURL := &p.AvatarURL
	if p.AvatarURL == "" {
		avatarURL = nil
	}

	if err = tx.QueryRow(ctx,
		`INSERT INTO users (email, name, avatar_url, email_verified)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id`,
		email, p.Name, avatarURL, p.EmailVerified,
	).Scan(&userID); err != nil {
		return "", false, fmt.Errorf("insert user: %w", err)
	}

	if _, err = tx.Exec(ctx,
		`INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, 'student')`,
		h.cfg.DefaultOrgID, userID,
	); err != nil {
		return "", false, fmt.Errorf("insert org_member: %w", err)
	}

	if _, err = tx.Exec(ctx,
		`INSERT INTO social_accounts (user_id, provider, provider_uid, email)
		 VALUES ($1, $2, $3, $4)`,
		userID, provider, p.ProviderUID, p.Email,
	); err != nil {
		return "", false, fmt.Errorf("insert social_account: %w", err)
	}

	if err = tx.Commit(ctx); err != nil {
		return "", false, fmt.Errorf("commit tx: %w", err)
	}

	return userID, false, nil
}

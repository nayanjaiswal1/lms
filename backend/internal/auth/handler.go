package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/session"
	"golang.org/x/crypto/bcrypt"
)

var emailRE = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

// dummyBcryptHash is a syntactically valid cost-12 bcrypt hash used to equalize
// response timing when no real password hash is available (unknown email, or an
// account without a password). It must parse so that CompareHashAndPassword runs
// the full cost-12 key derivation; the checksum does not correspond to any
// password. The cost MUST match the cost used by GenerateFromPassword elsewhere.
const dummyBcryptHash = "$2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy"

// Handler holds dependencies for all auth HTTP handlers.
type Handler struct {
	cfg   *config.Config
	pool  *pgxpool.Pool
	cache *session.Cache
}

// NewHandler constructs a Handler with the given config, DB pool, and session cache.
func NewHandler(cfg *config.Config, pool *pgxpool.Pool, cache *session.Cache) *Handler {
	return &Handler{cfg: cfg, pool: pool, cache: cache}
}

// ─── request / response types ─────────────────────────────────────────────────

type registerRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type verifyEmailRequest struct {
	Token string `json:"token"`
}

type resendVerificationRequest struct {
	Email string `json:"email"`
}

type forgotPasswordRequest struct {
	Email string `json:"email"`
}

type resetPasswordRequest struct {
	Token       string `json:"token"`
	NewPassword string `json:"new_password"`
}

type userResponse struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Email     string  `json:"email"`
	AvatarURL *string `json:"avatar_url"`
}

type orgResponse struct {
	ID   string `json:"id"`
	Slug string `json:"slug"`
	Name string `json:"name"`
	Role string `json:"role"`
}

// ─── HandleRegister ───────────────────────────────────────────────────────────

func (h *Handler) HandleRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	fields := make(map[string]string)
	if len(req.Name) < 2 || len(req.Name) > 80 {
		fields["name"] = "Name must be between 2 and 80 characters."
	}
	if !emailRE.MatchString(req.Email) {
		fields["email"] = "Invalid email address."
	}
	if len(req.Password) < 8 || len(req.Password) > 72 {
		fields["password"] = "Password must be between 8 and 72 characters."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	var exists bool
	if err := h.pool.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`, req.Email,
	).Scan(&exists); err != nil {
		slog.Error("auth: register check duplicate", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}
	if exists {
		// Anti-enumeration: in production never reveal that the email is registered.
		// Respond exactly as a fresh registration would and notify the existing
		// account holder out-of-band. In development surface the conflict plainly
		// for developer clarity (enumeration is not a concern on a local stack).
		if h.cfg.IsProd() {
			if err := SendDuplicateRegistration(h.cfg, req.Email); err != nil {
				slog.Error("auth: register notify existing account", "error", err)
			}
			httputil.WriteJSON(w, http.StatusCreated, map[string]string{
				"message": "Check your email to verify your account.",
			})
			return
		}
		httputil.WriteError(w, http.StatusConflict, "An account with that email already exists.")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		slog.Error("auth: register bcrypt", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	emailToken, emailTokenHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: register generate email verification token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	tx, err := h.pool.Begin(r.Context())
	if err != nil {
		slog.Error("auth: register begin tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var userID string
	if err := tx.QueryRow(r.Context(),
		`INSERT INTO users (email, name, password_hash, email_verified)
		 VALUES ($1, $2, $3, false)
		 RETURNING id`,
		req.Email, req.Name, string(hash),
	).Scan(&userID); err != nil {
		slog.Error("auth: register insert user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	if _, err := tx.Exec(r.Context(),
		`INSERT INTO org_members (org_id, user_id, role)
		 VALUES ($1, $2, 'student')`,
		h.cfg.DefaultOrgID, userID,
	); err != nil {
		slog.Error("auth: register insert org_member", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	expires := time.Now().Add(h.cfg.EmailVerificationTTL)
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO email_verifications (user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, emailTokenHash, expires,
	); err != nil {
		slog.Error("auth: register insert email_verification", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		slog.Error("auth: register commit tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	if h.cfg.IsProd() {
		if err := SendVerification(h.cfg, req.Email, emailToken); err != nil {
			slog.Error("auth: register send verification email", "error", err)
		}
		httputil.WriteJSON(w, http.StatusCreated, map[string]string{
			"message": "Check your email to verify your account.",
		})
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]string{
		"message":   "Registration successful. Verify your email to sign in.",
		"dev_token": emailToken,
	})
}

// ─── HandleLogin ──────────────────────────────────────────────────────────────

func (h *Handler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	type userRow struct {
		ID             string
		Name           string
		Email          string
		AvatarURL      *string
		PasswordHash   *string
		EmailVerified  bool
		SessionVersion int
	}

	var u userRow
	err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, password_hash, email_verified, session_version
		 FROM users WHERE email = $1`,
		req.Email,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.PasswordHash, &u.EmailVerified, &u.SessionVersion)

	if err != nil {
		_ = bcrypt.CompareHashAndPassword([]byte(dummyBcryptHash), []byte(req.Password))
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid email or password.")
		return
	}

	if u.PasswordHash == nil {
		_ = bcrypt.CompareHashAndPassword([]byte(dummyBcryptHash), []byte(req.Password))
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid email or password.")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(*u.PasswordHash), []byte(req.Password)); err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid email or password.")
		return
	}

	if !u.EmailVerified {
		httputil.WriteError(w, http.StatusForbidden, "Please verify your email before signing in.")
		return
	}

	if err := h.enforceMaxSessions(r.Context(), u.ID); err != nil {
		slog.Error("auth: login enforce max sessions", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	var orgRole string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT role FROM org_members WHERE org_id = $1 AND user_id = $2`,
		h.cfg.DefaultOrgID, u.ID,
	).Scan(&orgRole); err != nil {
		orgRole = "student"
	}

	accessToken, err := CreateAccessToken(h.cfg, Claims{
		UserID:         u.ID,
		OrgID:          h.cfg.DefaultOrgID,
		OrgRole:        orgRole,
		AuthMethod:     "password",
		SessionVersion: u.SessionVersion,
	})
	if err != nil {
		slog.Error("auth: login create access token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	rawRefresh, refreshHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: login create refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	familyID, err := randomHex(16)
	if err != nil {
		slog.Error("auth: login generate family_id", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, family_id, device_hint, ip)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		u.ID, refreshHash,
		time.Now().Add(h.cfg.RefreshTokenTTL),
		familyID, truncate(r.Header.Get("User-Agent"), 200), firstThreeOctets(r.RemoteAddr),
	); err != nil {
		slog.Error("auth: login insert refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	csrfToken, err := CreateCSRFToken(h.cfg)
	if err != nil {
		slog.Error("auth: login generate csrf token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	setAccessCookie(w, h.cfg, accessToken)
	setRefreshCookie(w, h.cfg, rawRefresh)
	setCSRFCookie(w, h.cfg, csrfToken)

	orgs, err := h.queryUserOrgs(r.Context(), u.ID)
	if err != nil {
		slog.Error("auth: login query orgs", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

	onboardingCompleted, err := h.checkOnboardingCompleted(r.Context(), u.ID)
	if err != nil {
		slog.Error("auth: login check onboarding", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Login failed.")
		return
	}

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

// ─── HandleRefresh ────────────────────────────────────────────────────────────

func (h *Handler) HandleRefresh(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("refresh_token")
	if err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "No refresh token.")
		return
	}

	tokenHash := HashToken(cookie.Value)

	type tokenRow struct {
		ID        string
		UserID    string
		FamilyID  string
		RotatedAt *time.Time
		RevokedAt *time.Time
		ExpiresAt time.Time
	}
	var tok tokenRow
	err = h.pool.QueryRow(r.Context(),
		`SELECT id, user_id, family_id, rotated_at, revoked_at, expires_at
		 FROM refresh_tokens
		 WHERE token_hash = $1`,
		tokenHash,
	).Scan(&tok.ID, &tok.UserID, &tok.FamilyID, &tok.RotatedAt, &tok.RevokedAt, &tok.ExpiresAt)
	if err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired refresh token.")
		return
	}

	if !tok.ExpiresAt.After(time.Now()) {
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired refresh token.")
		return
	}

	// Theft detection: a token that has already been rotated or revoked must never
	// be accepted again. Any reuse means the token was captured — revoke the whole
	// family so neither the legitimate user nor the attacker keeps a live session.
	if tok.RotatedAt != nil || tok.RevokedAt != nil {
		if _, err := h.pool.Exec(r.Context(),
			`UPDATE refresh_tokens SET revoked_at = now()
			 WHERE family_id = $1 AND revoked_at IS NULL`,
			tok.FamilyID,
		); err != nil {
			slog.Error("auth: refresh revoke family", "error", err)
		}
		clearCookies(w)
		httputil.WriteError(w, http.StatusUnauthorized, "Session reuse detected. All sessions revoked.")
		return
	}

	type userRow struct {
		ID             string
		Name           string
		Email          string
		AvatarURL      *string
		SessionVersion int
	}
	var u userRow
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, session_version FROM users WHERE id = $1`,
		tok.UserID,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.SessionVersion); err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "User not found.")
		return
	}

	var orgRole string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT role FROM org_members WHERE org_id = $1 AND user_id = $2`,
		h.cfg.DefaultOrgID, u.ID,
	).Scan(&orgRole); err != nil {
		orgRole = "student"
	}

	newAccessToken, err := CreateAccessToken(h.cfg, Claims{
		UserID:         u.ID,
		OrgID:          h.cfg.DefaultOrgID,
		OrgRole:        orgRole,
		AuthMethod:     "refresh",
		SessionVersion: u.SessionVersion,
	})
	if err != nil {
		slog.Error("auth: refresh create access token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	rawRefresh, refreshHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: refresh create refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	tx, err := h.pool.Begin(r.Context())
	if err != nil {
		slog.Error("auth: refresh begin tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	if _, err := tx.Exec(r.Context(),
		`UPDATE refresh_tokens SET rotated_at = now(), revoked_at = now() WHERE id = $1`,
		tok.ID,
	); err != nil {
		slog.Error("auth: refresh update rotated_at", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	if _, err := tx.Exec(r.Context(),
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, family_id, device_hint, ip)
		 SELECT user_id, $1, $2, family_id, device_hint, ip
		 FROM refresh_tokens WHERE id = $3`,
		refreshHash,
		time.Now().Add(h.cfg.RefreshTokenTTL),
		tok.ID,
	); err != nil {
		slog.Error("auth: refresh insert new token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		slog.Error("auth: refresh commit tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	csrfToken, err := CreateCSRFToken(h.cfg)
	if err != nil {
		slog.Error("auth: refresh generate csrf token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	setAccessCookie(w, h.cfg, newAccessToken)
	setRefreshCookie(w, h.cfg, rawRefresh)
	setCSRFCookie(w, h.cfg, csrfToken)

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"user": userResponse{
			ID:        u.ID,
			Name:      u.Name,
			Email:     u.Email,
			AvatarURL: u.AvatarURL,
		},
	})
}

// ─── HandleLogout ─────────────────────────────────────────────────────────────

func (h *Handler) HandleLogout(w http.ResponseWriter, r *http.Request) {
	if cookie, err := r.Cookie("refresh_token"); err == nil {
		tokenHash := HashToken(cookie.Value)
		if _, err := h.pool.Exec(r.Context(),
			`UPDATE refresh_tokens SET revoked_at = now()
			 WHERE token_hash = $1 AND revoked_at IS NULL`,
			tokenHash,
		); err != nil {
			slog.Error("auth: logout revoke refresh token", "error", err)
		}
	}

	if cookie, err := r.Cookie("access_token"); err == nil {
		if claims, err := ParseToken(h.cfg, cookie.Value); err == nil {
			exp := claims.ExpiresAt.Time
			h.cache.BlockJTI(r.Context(), claims.ID, exp)
			if _, err := h.pool.Exec(r.Context(),
				`INSERT INTO jti_blocklist (jti, user_id, expires_at, reason)
				 VALUES ($1, $2, $3, 'logout')
				 ON CONFLICT DO NOTHING`,
				claims.ID, claims.UserID, exp,
			); err != nil {
				slog.Error("auth: logout insert jti_blocklist", "error", err)
			}
		}
	}

	clearCookies(w)
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Signed out."})
}

// ─── HandleLogoutAll ─────────────────────────────────────────────────────────

func (h *Handler) HandleLogoutAll(w http.ResponseWriter, r *http.Request) {
	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	if _, err := h.pool.Exec(r.Context(),
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE user_id = $1 AND revoked_at IS NULL`,
		claims.UserID,
	); err != nil {
		slog.Error("auth: logout-all revoke tokens", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Logout failed.")
		return
	}

	if _, err := h.pool.Exec(r.Context(),
		`UPDATE users SET session_version = session_version + 1 WHERE id = $1`,
		claims.UserID,
	); err != nil {
		slog.Error("auth: logout-all bump session_version", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Logout failed.")
		return
	}

	h.cache.InvalidateVersionCache(r.Context(), claims.UserID)
	clearCookies(w)
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "All sessions revoked."})
}

// ─── HandleVerifyEmail ────────────────────────────────────────────────────────

func (h *Handler) HandleVerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Token) == "" {
		httputil.WriteError(w, http.StatusBadRequest, "Token is required.")
		return
	}

	tokenHash := HashToken(strings.TrimSpace(req.Token))

	var evID, userID string
	err := h.pool.QueryRow(r.Context(),
		`SELECT id, user_id FROM email_verifications
		 WHERE token_hash = $1 AND verified_at IS NULL AND expires_at > now()`,
		tokenHash,
	).Scan(&evID, &userID)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid or expired token.")
		return
	}

	tx, err := h.pool.Begin(r.Context())
	if err != nil {
		slog.Error("auth: verify-email begin tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	if _, err := tx.Exec(r.Context(),
		`UPDATE email_verifications SET verified_at = now() WHERE id = $1`, evID,
	); err != nil {
		slog.Error("auth: verify-email update token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
		return
	}

	if _, err := tx.Exec(r.Context(),
		`UPDATE users SET email_verified = true WHERE id = $1`, userID,
	); err != nil {
		slog.Error("auth: verify-email update user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		slog.Error("auth: verify-email commit tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{
		"message": "Email verified. You can now sign in.",
	})
}

// ─── HandleResendVerification ─────────────────────────────────────────────────

func (h *Handler) HandleResendVerification(w http.ResponseWriter, r *http.Request) {
	var req resendVerificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	const msg = "If that email exists, a new verification link was sent."

	var userID string
	var verified bool
	err := h.pool.QueryRow(r.Context(),
		`SELECT id, email_verified FROM users WHERE email = $1`, req.Email,
	).Scan(&userID, &verified)

	if err != nil || verified {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	emailToken, emailTokenHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: resend-verification generate token", "error", err)
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	expires := time.Now().Add(h.cfg.EmailVerificationTTL)
	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO email_verifications (user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, emailTokenHash, expires,
	); err != nil {
		slog.Error("auth: resend-verification insert token", "error", err)
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	if !h.cfg.IsProd() {
		slog.Info("DEV EMAIL: Resend verification token", "email", req.Email, "token", emailToken)
	} else {
		if err := SendVerification(h.cfg, req.Email, emailToken); err != nil {
			slog.Error("auth: resend-verification send email", "error", err)
		}
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
}

// ─── HandleForgotPassword ─────────────────────────────────────────────────────

func (h *Handler) HandleForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req forgotPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	defer func() {
		_ = bcrypt.CompareHashAndPassword(
			[]byte(dummyBcryptHash),
			[]byte("dummy"),
		)
	}()

	const msg = "If that email exists, a reset link was sent."

	var userID string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id FROM users WHERE email = $1`, req.Email,
	).Scan(&userID); err != nil {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	rawToken, tokenHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: forgot-password generate token", "error", err)
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	expires := time.Now().Add(h.cfg.PasswordResetTTL)
	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, tokenHash, expires,
	); err != nil {
		slog.Error("auth: forgot-password insert token", "error", err)
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	if !h.cfg.IsProd() {
		slog.Info("DEV EMAIL: Password reset token", "email", req.Email, "token", rawToken)
	} else {
		if err := SendPasswordReset(h.cfg, req.Email, rawToken); err != nil {
			slog.Error("auth: forgot-password send email", "error", err)
		}
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
}

// ─── HandleResetPassword ─────────────────────────────────────────────────────

func (h *Handler) HandleResetPassword(w http.ResponseWriter, r *http.Request) {
	var req resetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	req.Token = strings.TrimSpace(req.Token)
	if req.Token == "" {
		httputil.WriteError(w, http.StatusBadRequest, "Token is required.")
		return
	}
	if len(req.NewPassword) < 8 || len(req.NewPassword) > 72 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"new_password": "Password must be between 8 and 72 characters.",
		})
		return
	}

	tokenHash := HashToken(req.Token)

	var prtID, userID string
	err := h.pool.QueryRow(r.Context(),
		`SELECT id, user_id FROM password_reset_tokens
		 WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()`,
		tokenHash,
	).Scan(&prtID, &userID)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid or expired reset token.")
		return
	}

	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		slog.Error("auth: reset-password bcrypt", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}

	tx, err := h.pool.Begin(r.Context())
	if err != nil {
		slog.Error("auth: reset-password begin tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	if _, err := tx.Exec(r.Context(),
		`UPDATE users SET password_hash = $1, updated_at = now(),
		                  session_version = session_version + 1
		 WHERE id = $2`,
		string(newHash), userID,
	); err != nil {
		slog.Error("auth: reset-password update user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}

	if _, err := tx.Exec(r.Context(),
		`UPDATE password_reset_tokens SET used_at = now() WHERE id = $1`, prtID,
	); err != nil {
		slog.Error("auth: reset-password mark token used", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}

	if _, err := tx.Exec(r.Context(),
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE user_id = $1 AND revoked_at IS NULL`,
		userID,
	); err != nil {
		slog.Error("auth: reset-password revoke refresh tokens", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		slog.Error("auth: reset-password commit tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}

	h.cache.InvalidateVersionCache(r.Context(), userID)

	httputil.WriteJSON(w, http.StatusOK, map[string]string{
		"message": "Password updated. Please sign in.",
	})
}

// ─── HandleMe ────────────────────────────────────────────────────────────────

func (h *Handler) HandleMe(w http.ResponseWriter, r *http.Request) {
	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	type userRow struct {
		ID        string
		Name      string
		Email     string
		AvatarURL *string
	}
	var u userRow
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url FROM users WHERE id = $1`,
		claims.UserID,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL); err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "User not found.")
		return
	}

	orgs, err := h.queryUserOrgs(r.Context(), u.ID)
	if err != nil {
		slog.Error("auth: me query orgs", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load user.")
		return
	}

	onboardingCompleted, err := h.checkOnboardingCompleted(r.Context(), u.ID)
	if err != nil {
		slog.Error("auth: me check onboarding", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load user.")
		return
	}

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

// ─── HandleCSRFToken ─────────────────────────────────────────────────────────

// HandleCSRFToken issues a fresh CSRF token for unauthenticated page loads.
func (h *Handler) HandleCSRFToken(w http.ResponseWriter, r *http.Request) {
	// Reuse the existing cookie only if it carries a valid signature — never echo
	// back an unsigned or attacker-injected value, which would defeat the guard.
	if cookie, err := r.Cookie("csrf_token"); err == nil && ValidCSRFToken(h.cfg, cookie.Value) {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"csrf_token": cookie.Value})
		return
	}

	token, err := CreateCSRFToken(h.cfg)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to generate CSRF token.")
		return
	}

	setCSRFCookie(w, h.cfg, token)
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"csrf_token": token})
}

// ─── shared helpers ───────────────────────────────────────────────────────────

func (h *Handler) enforceMaxSessions(ctx context.Context, userID string) error {
	var activeFamilies, maxSessions int
	if err := h.pool.QueryRow(ctx,
		`SELECT COUNT(DISTINCT family_id) FROM refresh_tokens
		 WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > now()`,
		userID,
	).Scan(&activeFamilies); err != nil {
		return err
	}

	if err := h.pool.QueryRow(ctx,
		`SELECT max_sessions FROM users WHERE id = $1`, userID,
	).Scan(&maxSessions); err != nil {
		return err
	}

	if activeFamilies >= maxSessions {
		if _, err := h.pool.Exec(ctx,
			`UPDATE refresh_tokens SET revoked_at = now()
			 WHERE family_id = (
			   SELECT family_id FROM refresh_tokens
			   WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > now()
			   ORDER BY created_at ASC LIMIT 1
			 )`,
			userID,
		); err != nil {
			return err
		}
	}
	return nil
}

func (h *Handler) queryUserOrgs(ctx context.Context, userID string) ([]orgResponse, error) {
	rows, err := h.pool.Query(ctx,
		`SELECT o.id, o.slug, o.name, om.role
		 FROM organizations o
		 JOIN org_members om ON o.id = om.org_id
		 WHERE om.user_id = $1
		 ORDER BY o.name`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orgs []orgResponse
	for rows.Next() {
		var org orgResponse
		if err := rows.Scan(&org.ID, &org.Slug, &org.Name, &org.Role); err != nil {
			return nil, err
		}
		orgs = append(orgs, org)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if orgs == nil {
		orgs = []orgResponse{}
	}
	return orgs, nil
}

func (h *Handler) checkOnboardingCompleted(ctx context.Context, userID string) (bool, error) {
	var completed bool
	err := h.pool.QueryRow(ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM user_profiles
		   WHERE user_id = $1 AND completed_at IS NOT NULL
		 )`,
		userID,
	).Scan(&completed)
	return completed, err
}

// ─── cookie helpers ───────────────────────────────────────────────────────────

func setAccessCookie(w http.ResponseWriter, cfg *config.Config, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "access_token",
		Value:    token,
		Path:     "/",
		MaxAge:   15 * 60,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   cfg.IsProd(),
	})
}

func setRefreshCookie(w http.ResponseWriter, cfg *config.Config, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "refresh_token",
		Value:    token,
		Path:     "/",
		MaxAge:   30 * 24 * 3600,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   cfg.IsProd(),
	})
}

// setCSRFCookie sets a readable (non-HttpOnly) cookie so the browser can read
// the value and echo it back via the X-CSRF-Token header on each mutation.
func setCSRFCookie(w http.ResponseWriter, cfg *config.Config, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "csrf_token",
		Value:    token,
		Path:     "/",
		MaxAge:   15 * 60,
		HttpOnly: false,
		SameSite: http.SameSiteLaxMode,
		Secure:   cfg.IsProd(),
	})
}

func clearCookies(w http.ResponseWriter) {
	for _, name := range []string{"access_token", "refresh_token", "csrf_token"} {
		http.SetCookie(w, &http.Cookie{
			Name:     name,
			Value:    "",
			Path:     "/",
			MaxAge:   -1,
			HttpOnly: name != "csrf_token",
			SameSite: http.SameSiteLaxMode,
		})
	}
}

// ─── string helpers ───────────────────────────────────────────────────────────

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// firstThreeOctets returns a coarse, privacy-preserving network prefix from a
// remote address for use as a device hint: the first three octets of an IPv4
// address, or the /48 routing prefix of an IPv6 address. The final host bits are
// dropped so the stored hint cannot pinpoint an individual device.
func firstThreeOctets(remoteAddr string) string {
	host := remoteAddr
	if h, _, err := net.SplitHostPort(remoteAddr); err == nil {
		host = h
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return host
	}

	if v4 := ip.To4(); v4 != nil {
		return fmt.Sprintf("%d.%d.%d", v4[0], v4[1], v4[2])
	}

	return ip.Mask(net.CIDRMask(48, 128)).String()
}

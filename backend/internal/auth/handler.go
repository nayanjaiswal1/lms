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

	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/mindforge/backend/internal/session"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

// emailSendHandler mirrors handlers.HandlerEmailSend (internal/jobs/handlers),
// and emailPriorityHigh mirrors jobs.PriorityHigh — both duplicated as
// literals rather than importing those packages. jobs/handlers imports this
// auth package already (to call SendVerification/SendPasswordReset from its
// own "auth_verify"/"password_reset" job cases); internal/jobs itself is
// imported by internal/middleware, which auth's own HTTP layer depends on —
// so either import back from here would cycle. MUST stay in sync with
// handlers.HandlerEmailSend ("email.send") and jobs.PriorityHigh (2).
const (
	emailSendHandler  = "email.send"
	emailPriorityHigh = 2
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
	cfg     *config.Config
	pool    *pgxpool.Pool
	cache   *session.Cache
	rdb     *redis.Client
	wa      *webauthn.WebAuthn
	limiter *ratelimit.Limiter
}

// NewHandler constructs a Handler with the given config, DB pool, session cache,
// and Redis client (used for passkey in-flight challenge storage and for the
// account-scoped rate limiter).
func NewHandler(cfg *config.Config, pool *pgxpool.Pool, cache *session.Cache, rdb *redis.Client) *Handler {
	wa, err := webauthn.New(&webauthn.Config{
		RPID:          cfg.WebAuthnRPID,
		RPDisplayName: cfg.WebAuthnRPDisplayName,
		RPOrigins:     []string{cfg.WebAuthnRPOrigin},
	})
	if err != nil {
		// FrontendURL is validated at config load, so RPID/RPOrigin are always
		// well-formed here — this only trips on a config bug, and the passkey
		// endpoints degrade to a clear 503 rather than panicking the server.
		slog.Error("auth: webauthn config invalid — passkey endpoints will 503", "error", err)
	}
	return &Handler{cfg: cfg, pool: pool, cache: cache, rdb: rdb, wa: wa, limiter: ratelimit.New(rdb)}
}

// enqueueAuthEmail queues an "auth_verify" or "password_reset" email as an
// email.send background job instead of sending it inline on the request
// path. Register/resend-verification/forgot-password used to call
// SendVerification/SendPasswordReset synchronously: an SMTP outage or a slow
// relay blocked the HTTP response on the send, and a failed send was only
// ever logged once with no retry and no record for support to find later.
// Routing through the job queue picks up its existing retry/backoff and
// dead-letter handling (see jobs.Fail, and the dead-letter hook registered
// for HandlerEmailSend in cmd/server/main.go) for free.
//
// idempKey is derived from the token hash so a client retry (or a double
// submit) never queues the same email twice.
func (h *Handler) enqueueAuthEmail(ctx context.Context, emailType, to, token, idempKey string) error {
	payload, err := json.Marshal(map[string]any{
		"type": emailType,
		"to":   to,
		"template_data": map[string]any{
			"token": token,
		},
	})
	if err != nil {
		return fmt.Errorf("auth: marshal %s email payload: %w", emailType, err)
	}
	if _, err := h.pool.Exec(ctx,
		`INSERT INTO jobs (handler, status, priority, payload, idempotency_key)
		 VALUES ($1, 'queued', $2, $3, $4)
		 ON CONFLICT (idempotency_key) DO NOTHING`,
		emailSendHandler, emailPriorityHigh, payload, idempKey,
	); err != nil {
		return fmt.Errorf("auth: enqueue %s email (to=%s): %w", emailType, to, err)
	}
	return nil
}

// limitByAccount applies a rate limit keyed on the account being acted upon,
// independent of the per-IP limit the RateLimit middleware already applied.
//
// The IP limit cannot carry this load on its own: every browser-facing auth
// call reaches this service from the Next.js server rather than from the user's
// browser, so one address fronts the entire user base. Keyed on IP alone, ten
// bad passwords from one person would lock every user out of login, while an
// attacker working through a password list against a single account would never
// be singled out. Keying on the account fixes both directions.
//
// action namespaces the key so login attempts and password-reset requests do
// not consume each other's budget. Returns true when the caller should stop.
func (h *Handler) limitByAccount(w http.ResponseWriter, r *http.Request, action, account string) bool {
	if account == "" {
		return false
	}
	// Hashed so the key does not put a plaintext email address into Redis.
	key := "rl:acct:" + action + ":" + HashToken(account)
	allowed, retryAfter := h.limiter.Allow(r.Context(), key, h.cfg.AuthRateLimitMax, h.cfg.AuthRateLimitWindow)
	if allowed {
		return false
	}
	w.Header().Set("Retry-After", fmt.Sprintf("%d", ratelimit.RetryAfterSeconds(retryAfter)))
	httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
	return true
}

// Account statuses, mirrored from the users.status CHECK constraint.
const (
	StatusActive      = "active"
	StatusSuspended   = "suspended"
	StatusDeactivated = "deactivated"
)

// registrationLegalVersion is the Terms/Privacy version stamped on the
// acceptance rows written at registration. Must match
// legal.CurrentVersion(legal.DocTerms) / (legal.DocPrivacy) — kept as a
// literal here rather than imported to avoid an auth<->legal import cycle.
const registrationLegalVersion = "2026-08-04"

// accountLockedMessage returns the message to show for a non-active account, or
// "" when the account may sign in.
//
// Deliberately vague about which of the two locked states applies. The
// distinction matters to operators, not to whoever is at the keyboard, and
// spelling it out would tell an attacker probing an address whether the account
// was banned or closed by its owner.
func accountLockedMessage(status string) string {
	if status == StatusActive {
		return ""
	}
	return "This account is not available. Contact support if you think this is a mistake."
}

// ─── request / response types ─────────────────────────────────────────────────

type registerRequest struct {
	Name        string `json:"name"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	AcceptTerms bool   `json:"accept_terms"`
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
	ID                 string  `json:"id"`
	Name               string  `json:"name"`
	Email              string  `json:"email"`
	AvatarURL          *string `json:"avatar_url"`
	PlatformRole       string  `json:"platform_role"`
	DefaultLandingPage *string `json:"default_landing_page"`
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
	if !req.AcceptTerms {
		fields["accept_terms"] = "You must agree to the Terms of Service and Privacy Policy."
	}
	if len(fields) > 0 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, fields)
		return
	}

	if h.limitByAccount(w, r, "register", req.Email) {
		return
	}

	// Runs after the length/format checks so an obviously-invalid request never
	// reaches the breach lookup, and after the rate limit so the endpoint cannot
	// be used to drive traffic at a third party.
	if rej := ValidatePassword(r.Context(), h.cfg, req.Password, req.Email, req.Name); rej != nil {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"password": rej.Reason,
		})
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
		// Anti-enumeration: never reveal that the email is already registered.
		// Respond exactly as a fresh registration would and notify the existing
		// account holder out-of-band. This is unconditional — the previous
		// version returned a plain 409 outside production, which turned a
		// mis-set ENV into an account-enumeration oracle.
		if err := SendDuplicateRegistration(h.cfg, req.Email); err != nil {
			slog.Error("auth: register notify existing account", "error", err)
		}
		httputil.WriteJSON(w, http.StatusCreated, map[string]string{
			"message": "Check your email to verify your account.",
		})
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
		 VALUES ($1, $2, 'learner')`,
		h.cfg.DefaultOrgID, userID,
	); err != nil {
		slog.Error("auth: register insert org_member", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	// Records consent to both documents at once, since the registration form
	// has a single "I agree to the Terms and Privacy Policy" checkbox.
	// Version literals must match legal.CurrentVersion(legal.DocTerms) /
	// (legal.DocPrivacy) — duplicated here rather than imported to avoid an
	// auth<->legal import cycle (legal's handler imports auth for RequireClaims).
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO legal_acceptances (user_id, doc_type, version, ip)
		 VALUES ($1, 'terms', $2, $3), ($1, 'privacy', $2, $3)`,
		userID, registrationLegalVersion, firstThreeOctets(r.RemoteAddr),
	); err != nil {
		slog.Error("auth: register insert legal_acceptances", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Registration failed.")
		return
	}

	expires := time.Now().Add(h.cfg.EmailVerificationTTL)
	if _, err := tx.Exec(r.Context(),
		`INSERT INTO auth_tokens (purpose, token_hash, user_id, expires_at)
		 VALUES ('email_verify', $1, $2, $3)`,
		emailTokenHash, userID, expires,
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

	// The queued email.send job (handled by EmailHandler's "auth_verify" case)
	// itself decides between SMTP and a stdout log based on the environment.
	// The token is never returned in the response body: it used to be echoed
	// as "dev_token" outside production, which meant a mis-set ENV handed
	// anyone a verification token for an address they do not own — i.e.
	// account takeover by registering as someone else. On a local stack the
	// token is in the server log, which is where a developer already looks.
	if err := h.enqueueAuthEmail(r.Context(), "auth_verify", req.Email, emailToken, "auth_verify:"+emailTokenHash); err != nil {
		slog.Error("auth: register enqueue verification email", "error", err)
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]string{
		"message": "Check your email to verify your account.",
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

	if h.limitByAccount(w, r, "login", req.Email) {
		return
	}

	type userRow struct {
		ID             string
		Name           string
		Email          string
		AvatarURL      *string
		PasswordHash   *string
		EmailVerified  bool
		SessionVersion int
		Status         string
	}

	var u userRow
	err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, password_hash, email_verified, session_version, status
		 FROM users WHERE email = $1`,
		req.Email,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.PasswordHash, &u.EmailVerified, &u.SessionVersion, &u.Status)

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

	// Checked only after the password matched: an unauthenticated caller must
	// not be able to probe which addresses are locked.
	if msg := accountLockedMessage(u.Status); msg != "" {
		httputil.WriteError(w, http.StatusForbidden, msg)
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
		orgRole = "learner"
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

	// Claim the token and rotate it in a single statement. Splitting this into a
	// SELECT that checks rotated_at/revoked_at followed by a later UPDATE let two
	// concurrent refreshes both pass the check and both rotate; the loser then
	// issued a token descending from an already-rotated parent, whose next use
	// tripped the theft detection below and revoked the entire family — signing
	// the user out of everything. That race is not theoretical: the Next.js edge
	// middleware fires this endpoint on any protected navigation with an expired
	// access token, and parallel navigations and prefetches overlap by design.
	//
	// Because the UPDATE carries the predicates, only one caller can ever match.
	// It runs in the same transaction as the replacement INSERT so that a failure
	// to issue the new token rolls the rotation back, rather than burning the
	// user's only refresh token; a concurrent caller blocks on the row lock and
	// then matches zero rows, which is exactly the intended outcome.
	rawRefresh, refreshHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: refresh create refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	rotateTx, err := h.pool.Begin(r.Context())
	if err != nil {
		slog.Error("auth: refresh begin tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}
	defer rotateTx.Rollback(r.Context()) //nolint:errcheck

	var tok struct {
		ID         string
		UserID     string
		FamilyID   string
		DeviceHint *string
		IP         *string
	}
	err = rotateTx.QueryRow(r.Context(),
		`UPDATE refresh_tokens
		 SET rotated_at = now(), revoked_at = now()
		 WHERE token_hash = $1
		   AND rotated_at IS NULL
		   AND revoked_at IS NULL
		   AND expires_at > now()
		 RETURNING id, user_id, family_id, device_hint, ip`,
		tokenHash,
	).Scan(&tok.ID, &tok.UserID, &tok.FamilyID, &tok.DeviceHint, &tok.IP)
	if err != nil {
		// No row claimed. Either the token never existed or simply aged out —
		// both unremarkable — or it was already consumed, which is the theft
		// signal. Only the consumed case may revoke the family; letting a
		// naturally expired token trigger revocation would punish a user who
		// left a tab open past REFRESH_TOKEN_TTL.
		var familyID string
		if lookupErr := h.pool.QueryRow(r.Context(),
			`SELECT family_id FROM refresh_tokens
			 WHERE token_hash = $1 AND (rotated_at IS NOT NULL OR revoked_at IS NOT NULL)`,
			tokenHash,
		).Scan(&familyID); lookupErr != nil {
			httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired refresh token.")
			return
		}

		// Theft detection: a token that has already been rotated or revoked must
		// never be accepted again. Any reuse means the token was captured —
		// revoke the whole family so neither the legitimate user nor the attacker
		// keeps a live session.
		if _, revokeErr := h.pool.Exec(r.Context(),
			`UPDATE refresh_tokens SET revoked_at = now()
			 WHERE family_id = $1 AND revoked_at IS NULL`,
			familyID,
		); revokeErr != nil {
			slog.Error("auth: refresh revoke family", "error", revokeErr)
		}
		clearCookies(w, h.cfg)
		httputil.WriteError(w, http.StatusUnauthorized, "Session reuse detected. All sessions revoked.")
		return
	}

	// The replacement token inherits the family and the device/network hints of
	// the token it succeeds, so a family stays traceable to where it started.
	if _, err := rotateTx.Exec(r.Context(),
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, family_id, device_hint, ip)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		tok.UserID, refreshHash, time.Now().Add(h.cfg.RefreshTokenTTL),
		tok.FamilyID, tok.DeviceHint, tok.IP,
	); err != nil {
		slog.Error("auth: refresh insert new token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	if err := rotateTx.Commit(r.Context()); err != nil {
		slog.Error("auth: refresh commit tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Refresh failed.")
		return
	}

	type userRow struct {
		ID             string
		Name           string
		Email          string
		AvatarURL      *string
		SessionVersion int
		Status         string
	}
	var u userRow
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, session_version, status FROM users WHERE id = $1`,
		tok.UserID,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.SessionVersion, &u.Status); err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "User not found.")
		return
	}

	// A locked account must not be able to extend its session. The status
	// writer also bumps session_version, so live access tokens are already
	// dead; this closes the refresh path behind them.
	if msg := accountLockedMessage(u.Status); msg != "" {
		clearCookies(w, h.cfg)
		httputil.WriteError(w, http.StatusForbidden, msg)
		return
	}

	var orgRole string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT role FROM org_members WHERE org_id = $1 AND user_id = $2`,
		h.cfg.DefaultOrgID, u.ID,
	).Scan(&orgRole); err != nil {
		orgRole = "learner"
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

	clearCookies(w, h.cfg)
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
	clearCookies(w, h.cfg)
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
		`SELECT id, user_id FROM auth_tokens
		 WHERE purpose = 'email_verify' AND token_hash = $1 AND consumed_at IS NULL AND expires_at > now()`,
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
		`UPDATE auth_tokens SET consumed_at = now() WHERE id = $1`, evID,
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

	// Account-scoped so this endpoint cannot be used to mail-bomb one address,
	// nor to keep re-issuing verification links for an account someone else
	// registered under a victim's address.
	if h.limitByAccount(w, r, "resend-verification", req.Email) {
		return
	}

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
		`INSERT INTO auth_tokens (purpose, token_hash, user_id, expires_at)
		 VALUES ('email_verify', $1, $2, $3)`,
		emailTokenHash, userID, expires,
	); err != nil {
		slog.Error("auth: resend-verification insert token", "error", err)
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	// The queued job already logs instead of mailing on a local stack; a
	// duplicate branch here would log the token a second time and, more to
	// the point, decide that with its own copy of the environment check.
	if err := h.enqueueAuthEmail(r.Context(), "auth_verify", req.Email, emailToken, "auth_verify:"+emailTokenHash); err != nil {
		slog.Error("auth: resend-verification enqueue email", "error", err)
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

	const msg = "If that email exists, a reset link was sent."

	// Account-scoped so one address cannot be mail-bombed with reset links.
	if h.limitByAccount(w, r, "forgot-password", req.Email) {
		return
	}

	// Burn a fixed bcrypt's worth of time on every path so the response time does
	// not distinguish a known address from an unknown one. This was previously a
	// deferred call, which ran *after* the response had already been written and
	// so equalized nothing.
	_ = bcrypt.CompareHashAndPassword([]byte(dummyBcryptHash), []byte("dummy"))

	var userID string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id FROM users WHERE email = $1`, req.Email,
	).Scan(&userID); err != nil {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	// Supersede any reset token still outstanding for this account. Without
	// this, every unused link ever requested stays live until it ages out, so a
	// link that leaked from an inbox or a proxy log keeps working even after the
	// user has requested a fresh one.
	if _, err := h.pool.Exec(r.Context(),
		`UPDATE auth_tokens SET consumed_at = now()
		 WHERE purpose = 'password_reset' AND user_id = $1 AND consumed_at IS NULL`,
		userID,
	); err != nil {
		slog.Error("auth: forgot-password supersede outstanding tokens", "error", err)
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
		`INSERT INTO auth_tokens (purpose, token_hash, user_id, expires_at)
		 VALUES ('password_reset', $1, $2, $3)`,
		tokenHash, userID, expires,
	); err != nil {
		slog.Error("auth: forgot-password insert token", "error", err)
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": msg})
		return
	}

	if err := h.enqueueAuthEmail(r.Context(), "password_reset", req.Email, rawToken, "password_reset:"+tokenHash); err != nil {
		slog.Error("auth: forgot-password enqueue email", "error", err)
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

	var userID, userEmail, userName string
	err := h.pool.QueryRow(r.Context(),
		`SELECT prt.user_id, u.email, u.name
		 FROM auth_tokens prt
		 JOIN users u ON u.id = prt.user_id
		 WHERE prt.purpose = 'password_reset' AND prt.token_hash = $1 AND prt.consumed_at IS NULL AND prt.expires_at > now()`,
		tokenHash,
	).Scan(&userID, &userEmail, &userName)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid or expired reset token.")
		return
	}

	// The same policy registration applies — a reset must not be a way around it.
	if rej := ValidatePassword(r.Context(), h.cfg, req.NewPassword, userEmail, userName); rej != nil {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"new_password": rej.Reason,
		})
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

	// email_verified is set here too. Following a reset link proves control of
	// the mailbox just as the signup verification link does, so leaving the flag
	// alone stranded anyone who reset before verifying: they held a valid
	// password and still got "Please verify your email" at login, with the
	// verification mail sitting in the same inbox they had just proven they own.
	if _, err := tx.Exec(r.Context(),
		`UPDATE users SET password_hash = $1, updated_at = now(),
		                  session_version = session_version + 1,
		                  email_verified = true
		 WHERE id = $2`,
		string(newHash), userID,
	); err != nil {
		slog.Error("auth: reset-password update user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password reset failed.")
		return
	}

	// Consume every outstanding reset token for the account, not just the one
	// presented, so a second link mailed earlier cannot be redeemed afterwards.
	if _, err := tx.Exec(r.Context(),
		`UPDATE auth_tokens SET consumed_at = now()
		 WHERE purpose = 'password_reset' AND user_id = $1 AND consumed_at IS NULL`, userID,
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
		ID                 string
		Name               string
		Email              string
		AvatarURL          *string
		PlatformRole       string
		DefaultLandingPage *string
	}
	var u userRow
	if err := h.pool.QueryRow(r.Context(),
		`SELECT u.id, u.name, u.email, u.avatar_url, u.platform_role, p.default_landing_page
		 FROM users u
		 LEFT JOIN user_profiles p ON p.user_id = u.id
		 WHERE u.id = $1`,
		claims.UserID,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.PlatformRole, &u.DefaultLandingPage); err != nil {
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
			ID:                 u.ID,
			Name:               u.Name,
			Email:              u.Email,
			AvatarURL:          u.AvatarURL,
			PlatformRole:       u.PlatformRole,
			DefaultLandingPage: u.DefaultLandingPage,
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

// enforceMaxSessions revokes the user's oldest session families until at most
// max_sessions-1 remain, leaving room for the session the caller is about to
// create.
//
// A single statement replaces the previous count-then-revoke pair. The old
// version revoked exactly one family however far over the limit the user was,
// so a count that had drifted above max_sessions — which two concurrent logins
// could cause, since the count and the subsequent insert were not serialised —
// stayed above it forever.
func (h *Handler) enforceMaxSessions(ctx context.Context, userID string) error {
	_, err := h.pool.Exec(ctx,
		`WITH active AS (
		   SELECT family_id, MIN(created_at) AS started_at
		   FROM refresh_tokens
		   WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > now()
		   GROUP BY family_id
		 ), keep AS (
		   SELECT family_id FROM active
		   ORDER BY started_at DESC
		   LIMIT GREATEST((SELECT max_sessions FROM users WHERE id = $1) - 1, 0)
		 )
		 UPDATE refresh_tokens SET revoked_at = now()
		 WHERE user_id = $1
		   AND revoked_at IS NULL
		   AND family_id IN (SELECT family_id FROM active EXCEPT SELECT family_id FROM keep)`,
		userID,
	)
	return err
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

// Cookie lifetimes derive from the configured token TTLs rather than being
// written out as literals. They used to be hardcoded at 15m and 30d, so raising
// ACCESS_TOKEN_TTL left the browser discarding a cookie whose JWT was still
// valid, and lowering it left the browser sending a JWT that had already
// expired — the two only agreed at their default values.
func setAccessCookie(w http.ResponseWriter, cfg *config.Config, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "access_token",
		Value:    token,
		Path:     "/",
		MaxAge:   int(cfg.AccessTokenTTL.Seconds()),
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
		MaxAge:   int(cfg.RefreshTokenTTL.Seconds()),
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   cfg.IsProd(),
	})
}

// setCSRFCookie sets a readable (non-HttpOnly) cookie so the browser can read
// the value and echo it back via the X-CSRF-Token header on each mutation.
//
// It is scoped to the refresh TTL, not the access TTL: /api/auth/refresh now
// requires a CSRF token, and that call happens precisely when the access token
// has expired. A CSRF cookie that died alongside the access token would make
// every silent refresh fail and force a fresh login every ACCESS_TOKEN_TTL.
// The value is a signed random nonce, not a credential — its lifetime carries
// no secrecy requirement of its own.
func setCSRFCookie(w http.ResponseWriter, cfg *config.Config, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "csrf_token",
		Value:    token,
		Path:     "/",
		MaxAge:   int(cfg.RefreshTokenTTL.Seconds()),
		HttpOnly: false,
		SameSite: http.SameSiteLaxMode,
		Secure:   cfg.IsProd(),
	})
}

// clearCookies expires all three auth cookies. Secure must match the attribute
// they were set with: browsers key a cookie on (name, domain, path) and ignore
// Secure when matching, so deletion worked either way, but an intermediary that
// does inspect the attribute should see a consistent pair.
func clearCookies(w http.ResponseWriter, cfg *config.Config) {
	for _, name := range []string{"access_token", "refresh_token", "csrf_token"} {
		http.SetCookie(w, &http.Cookie{
			Name:     name,
			Value:    "",
			Path:     "/",
			MaxAge:   -1,
			HttpOnly: name != "csrf_token",
			SameSite: http.SameSiteLaxMode,
			Secure:   cfg.IsProd(),
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

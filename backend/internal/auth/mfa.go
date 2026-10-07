package auth

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/authevents"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
)

// TOTP MFA (M-01). Password and social sign-in are gated by mfaGate: accounts
// with MFA enabled, and privileged accounts (platform super_admin, org
// owner/admin) which must have it, receive a short-lived challenge instead of
// a session. Passkeys are exempt: they are already a possession + user
// verification factor.

const (
	mfaChallengeTTL = 5 * time.Minute
	mfaVerifyMax    = 5
	mfaVerifyWindow = 5 * time.Minute
)

var (
	errMFABadCode        = errors.New("invalid mfa code")
	errMFANoPending      = errors.New("no pending mfa enrolment")
	errMFAAlreadyEnabled = errors.New("mfa already enabled")
)

// mfaChallenge is what a half-authenticated sign-in carries between the first
// factor and the second. Enroll marks privileged accounts that still have to
// enrol before they get a session.
type mfaChallenge struct {
	UserID     string `json:"user_id"`
	Method     string `json:"method"`
	Onboarding *bool  `json:"onboarding,omitempty"`
	Enroll     bool   `json:"enroll"`
}

func challengeKey(token string) string { return "mfa:ch:" + HashToken(token) }

// isPrivileged reports whether the account holds a role for which MFA is mandatory.
func (h *Handler) isPrivileged(ctx context.Context, userID string) (bool, error) {
	var p bool
	err := h.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE id = $1 AND platform_role = 'super_admin')
		     OR EXISTS(SELECT 1 FROM org_members WHERE user_id = $1 AND status = 'active' AND role IN ('owner','admin'))`,
		userID).Scan(&p)
	return p, err
}

func (h *Handler) mfaEnabled(ctx context.Context, userID string) (bool, error) {
	var e bool
	err := h.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM user_mfa WHERE user_id = $1 AND enabled_at IS NOT NULL)`, userID).Scan(&e)
	return e, err
}

// mfaGate returns true when sign-in may proceed straight to a session. Otherwise
// it has written the challenge response (or a 500) and the caller must stop.
func (h *Handler) mfaGate(w http.ResponseWriter, r *http.Request, userID, method string, onboarding *bool) bool {
	enabled, err := h.mfaEnabled(r.Context(), userID)
	if err == nil && !enabled {
		var priv bool
		if priv, err = h.isPrivileged(r.Context(), userID); err == nil && !priv {
			return true
		}
	}
	if err != nil {
		slog.Error("auth: mfa gate lookup", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return false
	}

	token, err := randomHex(32)
	if err == nil {
		var payload []byte
		if payload, err = json.Marshal(mfaChallenge{UserID: userID, Method: method, Onboarding: onboarding, Enroll: !enabled}); err == nil {
			err = h.rdb.Set(r.Context(), challengeKey(token), payload, mfaChallengeTTL).Err()
		}
	}
	if err != nil {
		slog.Error("auth: mfa create challenge", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return false
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"mfa_required":        true,
		"mfa_enroll_required": !enabled,
		"challenge":           token,
	})
	return false
}

// peekChallenge loads a challenge without consuming it.
func (h *Handler) peekChallenge(w http.ResponseWriter, r *http.Request, token string, wantEnroll bool) (mfaChallenge, bool) {
	var ch mfaChallenge
	raw, err := h.rdb.Get(r.Context(), challengeKey(token)).Bytes()
	if err == nil {
		err = json.Unmarshal(raw, &ch)
	}
	if err != nil || ch.Enroll != wantEnroll {
		httputil.WriteError(w, http.StatusUnauthorized, "Sign-in expired. Please sign in again.")
		return ch, false
	}
	return ch, true
}

// consumeChallenge atomically spends the challenge; false means another
// request already did.
func (h *Handler) consumeChallenge(ctx context.Context, token string) bool {
	return h.rdb.GetDel(ctx, challengeKey(token)).Err() == nil
}

// mfaLimited applies the per-account verify limit (shared by every code-checking
// endpoint) and writes the 429 when exceeded.
func (h *Handler) mfaLimited(w http.ResponseWriter, r *http.Request, userID string) bool {
	allowed, retry := h.limiter.Allow(r.Context(), "rl:mfa:"+userID, mfaVerifyMax, mfaVerifyWindow)
	if allowed {
		return false
	}
	w.Header().Set("Retry-After", fmt.Sprintf("%d", ratelimit.RetryAfterSeconds(retry)))
	httputil.WriteError(w, http.StatusTooManyRequests, "Too many attempts. Please try again later.")
	return true
}

// beginMFASetup stores a fresh pending secret (replacing any earlier pending
// one) and returns it with its provisioning URI.
func (h *Handler) beginMFASetup(ctx context.Context, userID, email string) (secret, uri string, err error) {
	raw, err := newTOTPSecret()
	if err != nil {
		return "", "", err
	}
	enc, err := h.vault.Encrypt(raw)
	if err != nil {
		return "", "", fmt.Errorf("encrypt totp secret: %w", err)
	}
	tag, err := h.pool.Exec(ctx,
		`INSERT INTO user_mfa (user_id, secret_enc) VALUES ($1, $2)
		 ON CONFLICT (user_id) DO UPDATE SET secret_enc = EXCLUDED.secret_enc, last_step = 0
		 WHERE user_mfa.enabled_at IS NULL`, userID, enc)
	if err != nil {
		return "", "", fmt.Errorf("store totp secret: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return "", "", errMFAAlreadyEnabled
	}
	return base32NoPad.EncodeToString(raw), totpURI(raw, email), nil
}

// confirmMFA activates the pending secret when code is valid and issues a fresh
// set of recovery codes (returned once, stored hashed).
func (h *Handler) confirmMFA(ctx context.Context, userID, code string) ([]string, error) {
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var enc []byte
	var last int64
	if err := tx.QueryRow(ctx,
		`SELECT secret_enc, last_step FROM user_mfa WHERE user_id = $1 AND enabled_at IS NULL FOR UPDATE`, userID,
	).Scan(&enc, &last); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errMFANoPending
		}
		return nil, fmt.Errorf("load pending secret: %w", err)
	}
	secret, err := h.vault.Decrypt(enc)
	if err != nil {
		return nil, fmt.Errorf("decrypt totp secret: %w", err)
	}
	step, ok := verifyTOTP(secret, code, time.Now(), last)
	if !ok {
		return nil, errMFABadCode
	}
	plain, hashes, err := newRecoveryCodes()
	if err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx,
		`UPDATE user_mfa SET enabled_at = now(), last_step = $2 WHERE user_id = $1`, userID, step); err != nil {
		return nil, fmt.Errorf("enable mfa: %w", err)
	}
	if err := insertRecoveryCodes(ctx, tx, userID, hashes); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}
	return plain, nil
}

func insertRecoveryCodes(ctx context.Context, tx pgx.Tx, userID string, hashes []string) error {
	for _, hash := range hashes {
		if _, err := tx.Exec(ctx,
			`INSERT INTO user_mfa_recovery_codes (user_id, code_hash) VALUES ($1, $2)`, userID, hash); err != nil {
			return fmt.Errorf("insert recovery code: %w", err)
		}
	}
	return nil
}

// regenerateRecoveryCodes replaces every recovery code (used or not) with a
// fresh set once a current TOTP code proves possession of the authenticator.
// A recovery code is deliberately not accepted: a leaked code must not be able
// to mint its own replacements.
func (h *Handler) regenerateRecoveryCodes(ctx context.Context, userID, code string) ([]string, error) {
	if !looksLikeTOTP(code) {
		return nil, errMFABadCode
	}
	if _, err := h.checkSecondFactor(ctx, userID, code); err != nil {
		return nil, err
	}
	plain, hashes, err := newRecoveryCodes()
	if err != nil {
		return nil, err
	}
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck
	if _, err := tx.Exec(ctx, `DELETE FROM user_mfa_recovery_codes WHERE user_id = $1`, userID); err != nil {
		return nil, fmt.Errorf("delete old recovery codes: %w", err)
	}
	if err := insertRecoveryCodes(ctx, tx, userID, hashes); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}
	return plain, nil
}

// checkSecondFactor validates a TOTP or recovery code for an MFA-enabled user.
// recovery reports which kind was spent.
func (h *Handler) checkSecondFactor(ctx context.Context, userID, code string) (recovery bool, err error) {
	if !looksLikeTOTP(code) {
		tag, err := h.pool.Exec(ctx,
			`UPDATE user_mfa_recovery_codes SET used_at = now()
			 WHERE user_id = $1 AND code_hash = $2 AND used_at IS NULL`, userID, hashRecoveryCode(code))
		if err != nil {
			return true, fmt.Errorf("spend recovery code: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return true, errMFABadCode
		}
		return true, nil
	}
	var enc []byte
	var last int64
	if err := h.pool.QueryRow(ctx,
		`SELECT secret_enc, last_step FROM user_mfa WHERE user_id = $1 AND enabled_at IS NOT NULL`, userID,
	).Scan(&enc, &last); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, errMFABadCode
		}
		return false, fmt.Errorf("load totp secret: %w", err)
	}
	secret, err := h.vault.Decrypt(enc)
	if err != nil {
		return false, fmt.Errorf("decrypt totp secret: %w", err)
	}
	step, ok := verifyTOTP(secret, code, time.Now(), last)
	if !ok {
		return false, errMFABadCode
	}
	// Guarded on last_step so two concurrent requests cannot both spend one code.
	tag, err := h.pool.Exec(ctx,
		`UPDATE user_mfa SET last_step = $2 WHERE user_id = $1 AND last_step < $2`, userID, step)
	if err != nil {
		return false, fmt.Errorf("advance totp step: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return false, errMFABadCode
	}
	return false, nil
}

// secondFactorFailed maps a checkSecondFactor error to a response.
func secondFactorFailed(w http.ResponseWriter, err error, op string) {
	if errors.Is(err, errMFABadCode) {
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid code.")
		return
	}
	slog.Error("auth: "+op, "error", err)
	httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
}

// finishChallengeLogin spends the challenge and mints the session it was guarding.
func (h *Handler) finishChallengeLogin(w http.ResponseWriter, r *http.Request, token string, ch mfaChallenge) (sessionBody, bool) {
	if !h.consumeChallenge(r.Context(), token) {
		httputil.WriteError(w, http.StatusUnauthorized, "Sign-in expired. Please sign in again.")
		return sessionBody{}, false
	}
	var u sessionSubject
	var status string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, session_version, status FROM users WHERE id = $1`, ch.UserID,
	).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.SessionVersion, &status); err != nil {
		slog.Error("auth: mfa load user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return sessionBody{}, false
	}
	if msg := accountLockedMessage(status); msg != "" {
		httputil.WriteError(w, http.StatusForbidden, msg)
		return sessionBody{}, false
	}
	return h.mintSession(w, r, u, ch.Method, "mfa", "Sign-in failed.", ch.Onboarding)
}

type challengeCodeRequest struct {
	Challenge string `json:"challenge"`
	Code      string `json:"code"`
}

// HandleMFAVerify completes sign-in for an MFA-enabled account.
func (h *Handler) HandleMFAVerify(w http.ResponseWriter, r *http.Request) {
	var req challengeCodeRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	ch, ok := h.peekChallenge(w, r, req.Challenge, false)
	if !ok || h.mfaLimited(w, r, ch.UserID) {
		return
	}
	recovery, err := h.checkSecondFactor(r.Context(), ch.UserID, req.Code)
	if err != nil {
		if errors.Is(err, errMFABadCode) {
			authevents.Emit(r.Context(), h.pool, r, ch.UserID, authevents.MFAFailed)
		}
		secondFactorFailed(w, err, "mfa verify")
		return
	}
	event := authevents.MFAVerified
	if recovery {
		event = authevents.MFARecoveryUsed
	}
	authevents.Emit(r.Context(), h.pool, r, ch.UserID, event)
	body, ok := h.finishChallengeLogin(w, r, req.Challenge, ch)
	if !ok {
		return
	}
	httputil.WriteJSON(w, http.StatusOK, body)
}

// HandleMFAEnrollBegin starts mandatory enrolment for a privileged account
// that signed in with its first factor.
func (h *Handler) HandleMFAEnrollBegin(w http.ResponseWriter, r *http.Request) {
	var req challengeCodeRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	ch, ok := h.peekChallenge(w, r, req.Challenge, true)
	if !ok {
		return
	}
	h.writeSetup(w, r, ch.UserID)
}

// HandleMFAEnrollFinish confirms the first code, returns the recovery codes
// and completes the sign-in.
func (h *Handler) HandleMFAEnrollFinish(w http.ResponseWriter, r *http.Request) {
	var req challengeCodeRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	ch, ok := h.peekChallenge(w, r, req.Challenge, true)
	if !ok || h.mfaLimited(w, r, ch.UserID) {
		return
	}
	codes, err := h.confirmMFA(r.Context(), ch.UserID, req.Code)
	if err != nil {
		h.enrolFailed(w, r, ch.UserID, err)
		return
	}
	authevents.Emit(r.Context(), h.pool, r, ch.UserID, authevents.MFAEnabled)
	body, ok := h.finishChallengeLogin(w, r, req.Challenge, ch)
	if !ok {
		return
	}
	httputil.WriteJSON(w, http.StatusOK, struct {
		sessionBody
		RecoveryCodes []string `json:"recovery_codes"`
	}{body, codes})
}

func (h *Handler) enrolFailed(w http.ResponseWriter, r *http.Request, userID string, err error) {
	switch {
	case errors.Is(err, errMFABadCode):
		authevents.Emit(r.Context(), h.pool, r, userID, authevents.MFAFailed)
		httputil.WriteError(w, http.StatusUnauthorized, "Invalid code.")
	case errors.Is(err, errMFANoPending):
		httputil.WriteError(w, http.StatusConflict, "Start setup again.")
	default:
		slog.Error("auth: mfa confirm", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Setup failed.")
	}
}

func (h *Handler) writeSetup(w http.ResponseWriter, r *http.Request, userID string) {
	var email string
	if err := h.pool.QueryRow(r.Context(), `SELECT email FROM users WHERE id = $1`, userID).Scan(&email); err != nil {
		slog.Error("auth: mfa setup load user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Setup failed.")
		return
	}
	secret, uri, err := h.beginMFASetup(r.Context(), userID, email)
	if errors.Is(err, errMFAAlreadyEnabled) {
		httputil.WriteError(w, http.StatusConflict, "Two-factor authentication is already enabled.")
		return
	}
	if err != nil {
		slog.Error("auth: mfa begin setup", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Setup failed.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"secret": secret, "uri": uri})
}

// ─── authenticated management ────────────────────────────────────────────────

// HandleMFAStatus reports the caller's MFA state for the Settings card.
func (h *Handler) HandleMFAStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}
	var enabled bool
	var remaining int
	err := h.pool.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM user_mfa WHERE user_id = $1 AND enabled_at IS NOT NULL),
		        (SELECT count(*) FROM user_mfa_recovery_codes WHERE user_id = $1 AND used_at IS NULL)`,
		claims.UserID).Scan(&enabled, &remaining)
	if err == nil {
		var required bool
		if required, err = h.isPrivileged(r.Context(), claims.UserID); err == nil {
			httputil.WriteJSON(w, http.StatusOK, map[string]any{
				"enabled": enabled, "required": required, "recovery_codes_remaining": remaining,
			})
			return
		}
	}
	slog.Error("auth: mfa status", "error", err)
	httputil.WriteError(w, http.StatusInternalServerError, "Failed to load status.")
}

func (h *Handler) HandleMFASetup(w http.ResponseWriter, r *http.Request) {
	if claims, ok := RequireClaims(w, r); ok {
		h.writeSetup(w, r, claims.UserID)
	}
}

type codeRequest struct {
	Code string `json:"code"`
}

func (h *Handler) HandleMFAEnable(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}
	var req codeRequest
	if !httputil.DecodeJSON(w, r, &req) || h.mfaLimited(w, r, claims.UserID) {
		return
	}
	codes, err := h.confirmMFA(r.Context(), claims.UserID, req.Code)
	if err != nil {
		h.enrolFailed(w, r, claims.UserID, err)
		return
	}
	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.MFAEnabled)
	h.notifyUserSecurityChange(r.Context(), claims.UserID, "two-factor authentication was enabled")
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"recovery_codes": codes})
}

// HandleMFADisable removes MFA after a valid code. Privileged accounts cannot
// disable it: it is required for their role.
func (h *Handler) HandleMFADisable(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}
	var req codeRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	priv, err := h.isPrivileged(r.Context(), claims.UserID)
	if err != nil {
		slog.Error("auth: mfa disable role check", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to disable.")
		return
	}
	if priv {
		httputil.WriteError(w, http.StatusForbidden, "Two-factor authentication is required for your role.")
		return
	}
	if h.mfaLimited(w, r, claims.UserID) {
		return
	}
	if _, err := h.checkSecondFactor(r.Context(), claims.UserID, strings.TrimSpace(req.Code)); err != nil {
		if errors.Is(err, errMFABadCode) {
			authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.MFAFailed)
		}
		secondFactorFailed(w, err, "mfa disable verify")
		return
	}
	// Recovery codes cascade with the user_mfa row.
	if _, err := h.pool.Exec(r.Context(), `DELETE FROM user_mfa WHERE user_id = $1`, claims.UserID); err != nil {
		slog.Error("auth: mfa disable", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to disable.")
		return
	}
	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.MFADisabled)
	h.notifyUserSecurityChange(r.Context(), claims.UserID, "two-factor authentication was disabled")
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Two-factor authentication disabled."})
}

// HandleMFARecoveryRegenerate issues a new set of recovery codes, invalidating
// the old ones. Requires a current authenticator code and shares the MFA
// verify rate limit.
func (h *Handler) HandleMFARecoveryRegenerate(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}
	var req codeRequest
	if !httputil.DecodeJSON(w, r, &req) || h.mfaLimited(w, r, claims.UserID) {
		return
	}
	codes, err := h.regenerateRecoveryCodes(r.Context(), claims.UserID, strings.TrimSpace(req.Code))
	if err != nil {
		if errors.Is(err, errMFABadCode) {
			authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.MFAFailed)
		}
		secondFactorFailed(w, err, "mfa recovery regenerate")
		return
	}
	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.MFARecoveryRegenerated)
	h.notifyUserSecurityChange(r.Context(), claims.UserID, "your two-factor recovery codes were regenerated")
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"recovery_codes": codes})
}

package auth

import (
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/mindforge/backend/internal/httputil"
)

// StepUp is the re-verification a signed-in user must pass before a sensitive
// self-service action (data export, account deletion): the account's password
// when it has one, plus a current TOTP/recovery code when MFA is enabled.
// Social/passkey-only accounts without MFA have no factor to re-prove, so the
// session itself is the boundary. Failures share the per-account MFA rate
// limit and answer 403, so the frontend doesn't treat them as a dead session.
type StepUp func(w http.ResponseWriter, r *http.Request, userID, password, code string) bool

// VerifyStepUp implements StepUp; it writes the error response and returns
// false when verification fails.
func (h *Handler) VerifyStepUp(w http.ResponseWriter, r *http.Request, userID, password, code string) bool {
	var hash *string
	if err := h.pool.QueryRow(r.Context(), `SELECT password_hash FROM users WHERE id = $1`, userID).Scan(&hash); err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			slog.Error("auth: step-up password lookup", "error", err)
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
		return false
	}
	mfa, err := h.mfaEnabled(r.Context(), userID)
	if err != nil {
		slog.Error("auth: step-up mfa lookup", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
		return false
	}
	hasPassword := hash != nil && *hash != ""
	if !hasPassword && !mfa {
		return true
	}
	if h.mfaLimited(w, r, userID) {
		return false
	}
	if hasPassword && bcrypt.CompareHashAndPassword([]byte(*hash), []byte(password)) != nil {
		httputil.WriteError(w, http.StatusForbidden, "Incorrect password.")
		return false
	}
	if mfa {
		if _, err := h.checkSecondFactor(r.Context(), userID, strings.TrimSpace(code)); err != nil {
			if errors.Is(err, errMFABadCode) {
				httputil.WriteError(w, http.StatusForbidden, "Invalid two-factor code.")
				return false
			}
			slog.Error("auth: step-up second factor", "error", err)
			httputil.WriteError(w, http.StatusInternalServerError, "Verification failed.")
			return false
		}
	}
	return true
}

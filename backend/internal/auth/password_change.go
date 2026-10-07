package auth

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/mindforge/backend/internal/authevents"
	"github.com/mindforge/backend/internal/httputil"
	"golang.org/x/crypto/bcrypt"
)

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

// HandleChangePassword lets a signed-in user replace their password. Every other
// session is revoked and the caller gets a fresh one, so a stolen session does
// not survive the change.
func (h *Handler) HandleChangePassword(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}
	var req changePasswordRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if len(req.NewPassword) < 8 || len(req.NewPassword) > 72 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"new_password": "Password must be between 8 and 72 characters.",
		})
		return
	}
	// Guards current-password guessing from a hijacked session.
	if h.limitByAccount(w, r, "change-password", claims.UserID) {
		return
	}

	var u struct {
		Name, Email string
		Hash        *string
		AvatarURL   *string
	}
	if err := h.pool.QueryRow(r.Context(),
		`SELECT name, email, password_hash, avatar_url FROM users WHERE id = $1`, claims.UserID,
	).Scan(&u.Name, &u.Email, &u.Hash, &u.AvatarURL); err != nil {
		slog.Error("auth: change-password load user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password change failed.")
		return
	}
	if u.Hash == nil {
		httputil.WriteError(w, http.StatusBadRequest, "This account has no password. Use \"Forgot password\" to set one.")
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(*u.Hash), []byte(req.CurrentPassword)) != nil {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"current_password": "Current password is incorrect.",
		})
		return
	}
	if req.NewPassword == req.CurrentPassword {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"new_password": "New password must differ from the current one.",
		})
		return
	}
	if rej := ValidatePassword(r.Context(), h.cfg, req.NewPassword, u.Email, u.Name); rej != nil {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{"new_password": rej.Reason})
		return
	}
	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		slog.Error("auth: change-password bcrypt", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password change failed.")
		return
	}

	version, err := h.applyPasswordChange(r.Context(), claims.UserID, string(newHash))
	if err != nil {
		slog.Error("auth: change-password apply", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Password change failed.")
		return
	}

	h.cache.InvalidateVersionCache(r.Context(), claims.UserID)
	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.PasswordChanged)
	h.notifySecurityChange(u.Email, "your password was changed")

	// The version bump invalidated the caller's own tokens too; re-issue them.
	body, ok := h.mintSession(w, r, sessionSubject{
		ID: claims.UserID, Name: u.Name, Email: u.Email, AvatarURL: u.AvatarURL, SessionVersion: version,
	}, claims.AuthMethod, "change password", "Password changed, but re-signing in failed. Please sign in again.", nil)
	if !ok {
		return
	}
	httputil.WriteJSON(w, http.StatusOK, body)
}

// applyPasswordChange stores the new hash, bumps session_version and revokes
// every refresh token in one transaction; it returns the new session version.
func (h *Handler) applyPasswordChange(ctx context.Context, userID, newHash string) (int, error) {
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	var version int
	if err := tx.QueryRow(ctx,
		`UPDATE users SET password_hash = $1, updated_at = now(), session_version = session_version + 1
		 WHERE id = $2 RETURNING session_version`, newHash, userID,
	).Scan(&version); err != nil {
		return 0, fmt.Errorf("update user: %w", err)
	}
	if _, err := tx.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, userID,
	); err != nil {
		return 0, fmt.Errorf("revoke sessions: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit: %w", err)
	}
	return version, nil
}

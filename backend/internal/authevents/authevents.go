// Package authevents is the single emitter for the append-only auth_events
// security trail (DPDP / CERT-In audit requirement). Every sensitive
// account action funnels through Emit so IP truncation, UA hashing and
// failure handling live in one place.
package authevents

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Event names stored in auth_events.event.
const (
	Login                  = "login"
	LoginFailed            = "login_failed"
	PasswordReset          = "password_reset"
	PasswordChanged        = "password_changed"
	PasskeyAdded           = "passkey_added"
	PasskeyRemoved         = "passkey_removed"
	LogoutAll              = "logout_all"
	SessionRevoked         = "session_revoked"
	MCPConnected           = "mcp_connected"
	MCPRevoked             = "mcp_revoked"
	DataExport             = "data_export"
	AccountDeletion        = "account_deletion"
	MFAEnabled             = "mfa_enabled"
	MFADisabled            = "mfa_disabled"
	MFAVerified            = "mfa_verified"
	MFAFailed              = "mfa_failed"
	MFARecoveryUsed        = "mfa_recovery_used"
	MFARecoveryRegenerated = "mfa_recovery_regenerated"
	emitWriteTimeout       = 5 * time.Second
)

// TruncateIP keeps only the first three octets of an IPv4 address, or the /48
// prefix of an IPv6 address, so a stored value cannot pinpoint one device.
func TruncateIP(remoteAddr string) string {
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

// UAHash returns a short stable digest of the User-Agent so sessions can be
// correlated without storing the raw header.
func UAHash(userAgent string) string {
	sum := sha256.Sum256([]byte(userAgent))
	return hex.EncodeToString(sum[:8])
}

// Emit appends one event. userID may be empty (failed login for an unknown
// account). A write failure is logged at error level and never silently
// dropped; it does not fail the caller's request because the action it
// describes has already happened. The write uses a detached context so a
// client disconnect cannot lose the record.
func Emit(ctx context.Context, pool *pgxpool.Pool, r *http.Request, userID, event string) {
	var uid any
	if userID != "" {
		uid = userID
	}
	wctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), emitWriteTimeout)
	defer cancel()
	if _, err := pool.Exec(wctx,
		`INSERT INTO auth_events (user_id, event, ip, ua_hash) VALUES ($1, $2, $3, $4)`,
		uid, event, TruncateIP(r.RemoteAddr), UAHash(r.Header.Get("User-Agent")),
	); err != nil {
		slog.ErrorContext(ctx, "authevents: write failed", "event", event, "user_id", userID, "error", err)
	}
}

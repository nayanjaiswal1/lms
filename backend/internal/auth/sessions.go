package auth

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mindforge/backend/internal/authevents"
	"github.com/mindforge/backend/internal/httputil"
)

// sessionResponse is one signed-in device. ID is the refresh-token family_id:
// it is stable across rotations, which is what makes it addressable.
type sessionResponse struct {
	ID           string    `json:"id"`
	DeviceHint   *string   `json:"device_hint"`
	IP           *string   `json:"ip"`
	StartedAt    time.Time `json:"started_at"`
	LastActiveAt time.Time `json:"last_active_at"`
	Current      bool      `json:"current"`
}

// currentFamilyID returns the family of the request's refresh cookie, or ""
// when the cookie is absent or unknown.
func (h *Handler) currentFamilyID(r *http.Request) string {
	cookie, err := r.Cookie("refresh_token")
	if err != nil {
		return ""
	}
	var familyID string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT family_id::text FROM refresh_tokens WHERE token_hash = $1`,
		HashToken(cookie.Value),
	).Scan(&familyID); err != nil {
		return ""
	}
	return familyID
}

// HandleSessionsList lists the caller's live sessions, newest activity first.
// A family is live while its latest token is unrevoked and unexpired; each
// rotation revokes the previous token, so that row's created_at is the last
// refresh.
func (h *Handler) HandleSessionsList(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}

	rows, err := h.pool.Query(r.Context(),
		`SELECT t.family_id::text, t.device_hint, t.ip, t.created_at,
		        (SELECT MIN(f.created_at) FROM refresh_tokens f WHERE f.family_id = t.family_id)
		 FROM refresh_tokens t
		 WHERE t.user_id = $1 AND t.revoked_at IS NULL AND t.expires_at > now()
		 ORDER BY t.created_at DESC`,
		claims.UserID,
	)
	if err != nil {
		slog.Error("auth: sessions list", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load sessions.")
		return
	}
	defer rows.Close()

	current := h.currentFamilyID(r)
	sessions := []sessionResponse{}
	for rows.Next() {
		var s sessionResponse
		if err := rows.Scan(&s.ID, &s.DeviceHint, &s.IP, &s.LastActiveAt, &s.StartedAt); err != nil {
			slog.Error("auth: sessions scan", "error", err)
			httputil.WriteError(w, http.StatusInternalServerError, "Could not load sessions.")
			return
		}
		s.Current = s.ID == current
		sessions = append(sessions, s)
	}
	if err := rows.Err(); err != nil {
		slog.Error("auth: sessions rows", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load sessions.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"sessions": sessions})
}

// HandleSessionRevoke signs out one device. Access tokens carry no family, so
// the revoked device keeps working until its access token expires
// (AccessTokenTTL) but can no longer refresh. Revoking the caller's own
// session behaves like logout.
func (h *Handler) HandleSessionRevoke(w http.ResponseWriter, r *http.Request) {
	claims, ok := RequireClaims(w, r)
	if !ok {
		return
	}

	familyID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		httputil.WriteError(w, http.StatusNotFound, "Session not found.")
		return
	}

	isCurrent := h.currentFamilyID(r) == familyID.String()

	tag, err := h.pool.Exec(r.Context(),
		`UPDATE refresh_tokens SET revoked_at = now()
		 WHERE family_id = $1 AND user_id = $2 AND revoked_at IS NULL`,
		familyID, claims.UserID,
	)
	if err != nil {
		slog.Error("auth: session revoke", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not revoke session.")
		return
	}
	if tag.RowsAffected() == 0 {
		httputil.WriteError(w, http.StatusNotFound, "Session not found.")
		return
	}

	authevents.Emit(r.Context(), h.pool, r, claims.UserID, authevents.SessionRevoked)

	if isCurrent {
		h.blockCurrentAccessToken(r, claims)
		clearCookies(w, h.cfg)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"revoked_current": isCurrent})
}

// blockCurrentAccessToken blocklists the caller's access-token JTI, the same
// way HandleLogout does, so signing out the current device is immediate.
func (h *Handler) blockCurrentAccessToken(r *http.Request, claims *Claims) {
	exp := claims.ExpiresAt.Time
	h.cache.BlockJTI(r.Context(), claims.ID, exp)
	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO jti_blocklist (jti, user_id, expires_at, reason)
		 VALUES ($1, $2, $3, 'session_revoked')
		 ON CONFLICT DO NOTHING`,
		claims.ID, claims.UserID, exp,
	); err != nil {
		slog.Error("auth: session revoke blocklist jti", "error", err)
	}
}

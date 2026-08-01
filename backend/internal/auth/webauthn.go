package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/httputil"
)

const webAuthnSessionTTL = 5 * time.Minute

// ─── webauthn.User adapter ────────────────────────────────────────────────────

// webAuthnUser adapts a MindForge user + their registered passkeys to the
// interface go-webauthn needs to run a registration or login ceremony. The
// WebAuthn user handle is the user's UUID, raw 16 bytes (not the 36-char
// string) — it must round-trip through an authenticator's storage, so it stays
// as small and stable as possible.
type webAuthnUser struct {
	userID string
	id     []byte
	email  string
	name   string
	creds  []webauthn.Credential
}

func (u *webAuthnUser) WebAuthnID() []byte                        { return u.id }
func (u *webAuthnUser) WebAuthnName() string                      { return u.email }
func (u *webAuthnUser) WebAuthnDisplayName() string                { return u.name }
func (u *webAuthnUser) WebAuthnCredentials() []webauthn.Credential { return u.creds }

// loadWebAuthnUser loads a user and their registered passkeys into the shape
// go-webauthn needs. Returns an error if the user does not exist — callers
// that must not reveal account existence (login/begin) check that themselves
// before calling this.
func (h *Handler) loadWebAuthnUser(ctx context.Context, userID string) (*webAuthnUser, error) {
	parsedID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("auth: webauthn parse user id: %w", err)
	}

	var name, email string
	if err := h.pool.QueryRow(ctx,
		`SELECT name, email FROM users WHERE id = $1`, userID,
	).Scan(&name, &email); err != nil {
		return nil, fmt.Errorf("auth: webauthn load user: %w", err)
	}

	rows, err := h.pool.Query(ctx,
		`SELECT credential_id, public_key, attestation_type, transports, aaguid,
		        sign_count, backup_eligible, backup_state
		 FROM webauthn_credentials WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("auth: webauthn load credentials: %w", err)
	}
	defer rows.Close()

	var creds []webauthn.Credential
	for rows.Next() {
		var (
			c          webauthn.Credential
			transports []string
		)
		if err := rows.Scan(&c.ID, &c.PublicKey, &c.AttestationType, &transports,
			&c.Authenticator.AAGUID, &c.Authenticator.SignCount,
			&c.Flags.BackupEligible, &c.Flags.BackupState,
		); err != nil {
			return nil, fmt.Errorf("auth: webauthn scan credential: %w", err)
		}
		for _, t := range transports {
			c.Transport = append(c.Transport, protocol.AuthenticatorTransport(t))
		}
		creds = append(creds, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("auth: webauthn credentials rows: %w", err)
	}

	return &webAuthnUser{
		userID: userID,
		id:     parsedID[:],
		email:  email,
		name:   name,
		creds:  creds,
	}, nil
}

// parseWebAuthnUserID recovers the MindForge user UUID string from a raw
// WebAuthn user handle (the bytes an authenticator hands back at login).
func parseWebAuthnUserID(raw []byte) (string, error) {
	id, err := uuid.FromBytes(raw)
	if err != nil {
		return "", fmt.Errorf("auth: parse webauthn user handle: %w", err)
	}
	return id.String(), nil
}

// ─── in-flight challenge storage (Redis, one-time, 5 min TTL) ────────────────
//
// go-webauthn's SessionData carries the ceremony challenge between the
// begin/finish calls. It must never be trusted from the client, so it is
// stashed server-side under an opaque handle and consumed exactly once.

func (h *Handler) saveWebAuthnSession(ctx context.Context, prefix string, session *webauthn.SessionData) (string, error) {
	handle, err := randomHex(16)
	if err != nil {
		return "", fmt.Errorf("auth: webauthn generate session handle: %w", err)
	}

	data, err := json.Marshal(session)
	if err != nil {
		return "", fmt.Errorf("auth: webauthn marshal session: %w", err)
	}

	if err := h.rdb.Set(ctx, "webauthn:"+prefix+":"+handle, data, webAuthnSessionTTL).Err(); err != nil {
		return "", fmt.Errorf("auth: webauthn save session: %w", err)
	}
	return handle, nil
}

func (h *Handler) takeWebAuthnSession(ctx context.Context, prefix, handle string) (*webauthn.SessionData, error) {
	if handle == "" {
		return nil, fmt.Errorf("auth: webauthn empty session handle")
	}

	data, err := h.rdb.GetDel(ctx, "webauthn:"+prefix+":"+handle).Bytes()
	if err != nil {
		return nil, fmt.Errorf("auth: webauthn session not found or expired: %w", err)
	}

	var session webauthn.SessionData
	if err := json.Unmarshal(data, &session); err != nil {
		return nil, fmt.Errorf("auth: webauthn unmarshal session: %w", err)
	}
	return &session, nil
}

// requireWebAuthn reports whether passkey ceremonies are usable, writing a 503
// and returning false otherwise. wa is only nil when WebAuthnRPID failed
// config validation at startup (see NewHandler) — practically unreachable
// since it derives from the already-validated FrontendURL, but the endpoints
// degrade cleanly instead of panicking on a nil *webauthn.WebAuthn.
func (h *Handler) requireWebAuthn(w http.ResponseWriter) bool {
	if h.wa == nil {
		httputil.WriteError(w, http.StatusServiceUnavailable, "Passkey sign-in is not available.")
		return false
	}
	return true
}

// ─── HandleWebAuthnRegisterBegin / Finish ─────────────────────────────────────
// Enrollment for an already-authenticated user adding a passkey to their
// account. This is never how a MindForge account is created — the user must
// already have signed up with a password or OAuth.

func (h *Handler) HandleWebAuthnRegisterBegin(w http.ResponseWriter, r *http.Request) {
	if !h.requireWebAuthn(w) {
		return
	}

	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	user, err := h.loadWebAuthnUser(r.Context(), claims.UserID)
	if err != nil {
		slog.Error("auth: webauthn register begin load user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not start passkey registration.")
		return
	}

	exclude := make([]protocol.CredentialDescriptor, len(user.creds))
	for i, c := range user.creds {
		exclude[i] = c.Descriptor()
	}

	requireResidentKey := true
	creation, session, err := h.wa.BeginRegistration(user,
		webauthn.WithExclusions(exclude),
		webauthn.WithConveyancePreference(protocol.PreferNoAttestation),
		webauthn.WithAuthenticatorSelection(protocol.AuthenticatorSelection{
			ResidentKey:         protocol.ResidentKeyRequirementRequired,
			RequireResidentKey:  &requireResidentKey,
			UserVerification:    protocol.VerificationPreferred,
		}),
	)
	if err != nil {
		slog.Error("auth: webauthn register begin", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not start passkey registration.")
		return
	}

	handle, err := h.saveWebAuthnSession(r.Context(), "reg", session)
	if err != nil {
		slog.Error("auth: webauthn register begin save session", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not start passkey registration.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"handle":  handle,
		"options": creation,
	})
}

type webauthnRegisterFinishRequest struct {
	Handle   string          `json:"handle"`
	Nickname string          `json:"nickname"`
	Response json.RawMessage `json:"response"`
}

func (h *Handler) HandleWebAuthnRegisterFinish(w http.ResponseWriter, r *http.Request) {
	if !h.requireWebAuthn(w) {
		return
	}

	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	var req webauthnRegisterFinishRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Handle == "" || len(req.Response) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	session, err := h.takeWebAuthnSession(r.Context(), "reg", req.Handle)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Passkey registration expired. Please try again.")
		return
	}

	user, err := h.loadWebAuthnUser(r.Context(), claims.UserID)
	if err != nil {
		slog.Error("auth: webauthn register finish load user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not complete passkey registration.")
		return
	}

	parsedResponse, err := protocol.ParseCredentialCreationResponseBytes(req.Response)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid passkey response.")
		return
	}

	credential, err := h.wa.CreateCredential(user, *session, parsedResponse)
	if err != nil {
		slog.Error("auth: webauthn register finish create credential", "error", err)
		httputil.WriteError(w, http.StatusBadRequest, "Could not verify passkey.")
		return
	}

	nickname := strings.TrimSpace(req.Nickname)
	if nickname == "" {
		nickname = "Passkey"
	}
	if len(nickname) > 80 {
		nickname = nickname[:80]
	}

	transports := make([]string, len(credential.Transport))
	for i, t := range credential.Transport {
		transports[i] = string(t)
	}

	var credID string
	if err := h.pool.QueryRow(r.Context(),
		`INSERT INTO webauthn_credentials
		   (user_id, credential_id, public_key, attestation_type, transports, aaguid,
		    sign_count, backup_eligible, backup_state, nickname)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 RETURNING id`,
		claims.UserID, credential.ID, credential.PublicKey, credential.AttestationType,
		transports, credential.Authenticator.AAGUID, credential.Authenticator.SignCount,
		credential.Flags.BackupEligible, credential.Flags.BackupState, nickname,
	).Scan(&credID); err != nil {
		slog.Error("auth: webauthn register finish insert credential", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not save passkey.")
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]any{
		"credential": map[string]any{
			"id":       credID,
			"nickname": nickname,
		},
	})
}

// ─── HandleWebAuthnCredentials{List,Rename,Delete} ────────────────────────────

type webauthnCredentialResponse struct {
	ID          string     `json:"id"`
	Nickname    string     `json:"nickname"`
	CreatedAt   time.Time  `json:"created_at"`
	LastUsedAt  *time.Time `json:"last_used_at"`
	BackupState bool       `json:"backup_state"`
}

func (h *Handler) HandleWebAuthnCredentialsList(w http.ResponseWriter, r *http.Request) {
	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	rows, err := h.pool.Query(r.Context(),
		`SELECT id, nickname, created_at, last_used_at, backup_state
		 FROM webauthn_credentials WHERE user_id = $1 ORDER BY created_at`,
		claims.UserID,
	)
	if err != nil {
		slog.Error("auth: webauthn list credentials", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load passkeys.")
		return
	}
	defer rows.Close()

	creds := []webauthnCredentialResponse{}
	for rows.Next() {
		var c webauthnCredentialResponse
		if err := rows.Scan(&c.ID, &c.Nickname, &c.CreatedAt, &c.LastUsedAt, &c.BackupState); err != nil {
			slog.Error("auth: webauthn scan credential row", "error", err)
			httputil.WriteError(w, http.StatusInternalServerError, "Could not load passkeys.")
			return
		}
		creds = append(creds, c)
	}
	if err := rows.Err(); err != nil {
		slog.Error("auth: webauthn credential rows", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load passkeys.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"credentials": creds})
}

func (h *Handler) HandleWebAuthnCredentialRename(w http.ResponseWriter, r *http.Request) {
	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	id := chi.URLParam(r, "id")

	var req struct {
		Nickname string `json:"nickname"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	nickname := strings.TrimSpace(req.Nickname)
	if nickname == "" || len(nickname) > 80 {
		httputil.WriteFieldErrors(w, http.StatusUnprocessableEntity, map[string]string{
			"nickname": "Nickname must be between 1 and 80 characters.",
		})
		return
	}

	tag, err := h.pool.Exec(r.Context(),
		`UPDATE webauthn_credentials SET nickname = $1 WHERE id = $2 AND user_id = $3`,
		nickname, id, claims.UserID,
	)
	if err != nil {
		slog.Error("auth: webauthn rename credential", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not rename passkey.")
		return
	}
	if tag.RowsAffected() == 0 {
		httputil.WriteError(w, http.StatusNotFound, "Passkey not found.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Passkey renamed."})
}

// HandleWebAuthnCredentialDelete removes a registered passkey. Blocked when
// this is the account's last-standing auth method (no password, no linked
// social account, no other passkey) — otherwise the delete would lock the
// user out with no way back in.
func (h *Handler) HandleWebAuthnCredentialDelete(w http.ResponseWriter, r *http.Request) {
	claims, ok := GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	id := chi.URLParam(r, "id")

	tx, err := h.pool.Begin(r.Context())
	if err != nil {
		slog.Error("auth: webauthn delete credential begin tx", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var exists bool
	if err := tx.QueryRow(r.Context(),
		`SELECT EXISTS(SELECT 1 FROM webauthn_credentials WHERE id = $1 AND user_id = $2)`,
		id, claims.UserID,
	).Scan(&exists); err != nil {
		slog.Error("auth: webauthn delete credential check exists", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}
	if !exists {
		httputil.WriteError(w, http.StatusNotFound, "Passkey not found.")
		return
	}

	var hasPassword bool
	var passkeyCount, socialCount int
	if err := tx.QueryRow(r.Context(),
		`SELECT password_hash IS NOT NULL FROM users WHERE id = $1`, claims.UserID,
	).Scan(&hasPassword); err != nil {
		slog.Error("auth: webauthn delete credential check password", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}
	if err := tx.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM webauthn_credentials WHERE user_id = $1`, claims.UserID,
	).Scan(&passkeyCount); err != nil {
		slog.Error("auth: webauthn delete credential count passkeys", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}
	if err := tx.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM social_accounts WHERE user_id = $1`, claims.UserID,
	).Scan(&socialCount); err != nil {
		slog.Error("auth: webauthn delete credential count social", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}

	if !hasPassword && socialCount == 0 && passkeyCount <= 1 {
		httputil.WriteError(w, http.StatusConflict, "Add another sign-in method before removing your last passkey.")
		return
	}

	if _, err := tx.Exec(r.Context(),
		`DELETE FROM webauthn_credentials WHERE id = $1 AND user_id = $2`, id, claims.UserID,
	); err != nil {
		slog.Error("auth: webauthn delete credential", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		slog.Error("auth: webauthn delete credential commit", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not remove passkey.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]string{"message": "Passkey removed."})
}

// ─── HandleWebAuthnLoginBegin / Finish ────────────────────────────────────────

type webauthnLoginBeginRequest struct {
	Email string `json:"email"`
}

// HandleWebAuthnLoginBegin starts a login ceremony. With no email (or an
// unrecognized one), it falls back to a discoverable challenge — the
// authenticator itself tells the browser which credential to use, so a
// usernameless flow works and unknown emails never leak account existence.
func (h *Handler) HandleWebAuthnLoginBegin(w http.ResponseWriter, r *http.Request) {
	if !h.requireWebAuthn(w) {
		return
	}

	var req webauthnLoginBeginRequest
	_ = json.NewDecoder(r.Body).Decode(&req) // an empty body is valid — discoverable login
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	opts := []webauthn.LoginOption{webauthn.WithUserVerification(protocol.VerificationPreferred)}

	var (
		assertion *protocol.CredentialAssertion
		session   *webauthn.SessionData
		err       error
	)

	if req.Email != "" {
		var userID string
		if qerr := h.pool.QueryRow(r.Context(),
			`SELECT id FROM users WHERE email = $1`, req.Email,
		).Scan(&userID); qerr == nil {
			if user, uerr := h.loadWebAuthnUser(r.Context(), userID); uerr == nil && len(user.creds) > 0 {
				assertion, session, err = h.wa.BeginLogin(user, opts...)
			}
		}
	}

	if assertion == nil {
		assertion, session, err = h.wa.BeginDiscoverableLogin(opts...)
	}

	if err != nil {
		slog.Error("auth: webauthn login begin", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not start passkey sign-in.")
		return
	}

	handle, err := h.saveWebAuthnSession(r.Context(), "login", session)
	if err != nil {
		slog.Error("auth: webauthn login begin save session", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not start passkey sign-in.")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"handle":  handle,
		"options": assertion,
	})
}

type webauthnLoginFinishRequest struct {
	Handle   string          `json:"handle"`
	Response json.RawMessage `json:"response"`
}

// HandleWebAuthnLoginFinish verifies the authenticator's response and, on
// success, mints the same session cookies as every other login method. The
// cookie-minting tail is deliberately identical to HandleSocialExchange in
// social.go — same enforceMaxSessions/refresh-family/CSRF/cookie flow — the
// only difference is AuthMethod:"passkey" in the JWT claims.
func (h *Handler) HandleWebAuthnLoginFinish(w http.ResponseWriter, r *http.Request) {
	if !h.requireWebAuthn(w) {
		return
	}

	var req webauthnLoginFinishRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Handle == "" || len(req.Response) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	session, err := h.takeWebAuthnSession(r.Context(), "login", req.Handle)
	if err != nil {
		httputil.WriteError(w, http.StatusUnauthorized, "Passkey sign-in expired. Please try again.")
		return
	}

	parsedResponse, err := protocol.ParseCredentialRequestResponseBytes(req.Response)
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid passkey response.")
		return
	}

	var (
		credential *webauthn.Credential
		u          *webAuthnUser
	)

	if len(session.UserID) > 0 {
		knownUserID, perr := parseWebAuthnUserID(session.UserID)
		if perr != nil {
			httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired passkey session.")
			return
		}
		loaded, lerr := h.loadWebAuthnUser(r.Context(), knownUserID)
		if lerr != nil {
			httputil.WriteError(w, http.StatusUnauthorized, "Invalid or expired passkey session.")
			return
		}
		u = loaded
		credential, err = h.wa.ValidateLogin(u, *session, parsedResponse)
	} else {
		var gotUser webauthn.User
		gotUser, credential, err = h.wa.ValidatePasskeyLogin(func(rawID, userHandle []byte) (webauthn.User, error) {
			discoveredID, herr := parseWebAuthnUserID(userHandle)
			if herr != nil {
				return nil, herr
			}
			return h.loadWebAuthnUser(r.Context(), discoveredID)
		}, *session, parsedResponse)
		if err == nil {
			u, _ = gotUser.(*webAuthnUser)
		}
	}

	if err != nil || u == nil {
		slog.Error("auth: webauthn login finish validate", "error", err)
		httputil.WriteError(w, http.StatusUnauthorized, "Passkey sign-in failed.")
		return
	}

	cloneWarning := credential.Authenticator.CloneWarning
	if _, err := h.pool.Exec(r.Context(),
		`UPDATE webauthn_credentials
		 SET sign_count = GREATEST(sign_count, $1), last_used_at = now(),
		     clone_warning = $2, backup_state = $3
		 WHERE credential_id = $4`,
		credential.Authenticator.SignCount, cloneWarning, credential.Flags.BackupState, credential.ID,
	); err != nil {
		slog.Error("auth: webauthn login finish update credential", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	// Clone detection is advisory, not a block: platform authenticators can
	// report spurious regressions across sync/restore. Mirrors the existing
	// impossible-travel posture (alert + let the session proceed) rather than
	// silently killing a legitimate login.
	if cloneWarning {
		slog.Warn("auth: webauthn clone warning detected", "user_id", u.userID)
		if err := SendPasskeyCloneAlert(h.cfg, u.email); err != nil {
			slog.Error("auth: webauthn clone alert email", "error", err)
		}
	}

	if err := h.enforceMaxSessions(r.Context(), u.userID); err != nil {
		slog.Error("auth: webauthn login finish enforce max sessions", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
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
	var ur userRow
	if err := h.pool.QueryRow(r.Context(),
		`SELECT id, name, email, avatar_url, session_version, status FROM users WHERE id = $1`, u.userID,
	).Scan(&ur.ID, &ur.Name, &ur.Email, &ur.AvatarURL, &ur.SessionVersion, &ur.Status); err != nil {
		slog.Error("auth: webauthn login finish get user", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	// Checked only after the authenticator response verified, so the passkey
	// ceremony cannot be used to probe which accounts are locked.
	if msg := accountLockedMessage(ur.Status); msg != "" {
		httputil.WriteError(w, http.StatusForbidden, msg)
		return
	}

	var orgRole string
	if err := h.pool.QueryRow(r.Context(),
		`SELECT role FROM org_members WHERE org_id = $1 AND user_id = $2`,
		h.cfg.DefaultOrgID, u.userID,
	).Scan(&orgRole); err != nil {
		orgRole = "learner"
	}

	accessToken, err := CreateAccessToken(h.cfg, Claims{
		UserID:         u.userID,
		OrgID:          h.cfg.DefaultOrgID,
		OrgRole:        orgRole,
		AuthMethod:     "passkey",
		SessionVersion: ur.SessionVersion,
	})
	if err != nil {
		slog.Error("auth: webauthn login finish create access token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	rawRefresh, refreshHash, err := CreateRefreshToken()
	if err != nil {
		slog.Error("auth: webauthn login finish create refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	familyID, err := randomHex(16)
	if err != nil {
		slog.Error("auth: webauthn login finish generate family_id", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	if _, err := h.pool.Exec(r.Context(),
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, family_id, device_hint, ip)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		u.userID, refreshHash,
		time.Now().Add(h.cfg.RefreshTokenTTL),
		familyID, truncate(r.Header.Get("User-Agent"), 200), firstThreeOctets(r.RemoteAddr),
	); err != nil {
		slog.Error("auth: webauthn login finish insert refresh token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	csrfToken, err := CreateCSRFToken(h.cfg)
	if err != nil {
		slog.Error("auth: webauthn login finish generate csrf token", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	orgs, err := h.queryUserOrgs(r.Context(), u.userID)
	if err != nil {
		slog.Error("auth: webauthn login finish query orgs", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	onboardingCompleted, err := h.checkOnboardingCompleted(r.Context(), u.userID)
	if err != nil {
		slog.Error("auth: webauthn login finish check onboarding", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Sign-in failed.")
		return
	}

	setAccessCookie(w, h.cfg, accessToken)
	setRefreshCookie(w, h.cfg, rawRefresh)
	setCSRFCookie(w, h.cfg, csrfToken)

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"user": userResponse{
			ID:        ur.ID,
			Name:      ur.Name,
			Email:     ur.Email,
			AvatarURL: ur.AvatarURL,
		},
		"orgs":                 orgs,
		"onboarding_completed": onboardingCompleted,
	})
}

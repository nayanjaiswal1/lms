package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// wsTokenType must match labs.WSTokenType (internal/labs/service.go) — the
// value MintWSToken stamps on every token it issues. Checked in addition to
// Issuer so that a future config accident pointing this process's issuer
// string at the same value the main API's ordinary login tokens use still
// can't be mistaken for a lab WS token: nothing else in the codebase ever
// sets `typ` to this value. Duplicated as a literal instead of imported
// because cmd/labproxy is a separate deploy unit deliberately kept free of
// the main backend's dependency graph (no Docker/K8s client, no business
// logic) — see NewProxyHandler's doc comment.
const wsTokenType = "lab_ws"

// ttydCredentialUser must match labs.TTYDCredentialUser
// (internal/labs/credential.go) — duplicated as a literal for the same
// reason wsTokenType is (see its doc comment above): cmd/labproxy is a
// separate deploy unit deliberately kept free of the main backend's
// dependency graph.
const ttydCredentialUser = "mindforge"

// deriveContainerCredential must stay byte-for-byte identical to
// labs.DeriveContainerCredential (internal/labs/credential.go): both
// processes independently recompute the same per-session ttyd credential
// from the session ID and the shared LABPROXY_JWT_SECRET (= JWT_SECRET),
// never stored in the database or handed to the browser. See that
// function's doc comment for the full rationale (docs/labs.md "Proxy ↔
// Container Channel Security"; docs/debug-labs.md Phase 0).
// containerCredentialDomain prefixes the HMAC input — must match the copy in
// the other process (internal/labs/credential.go ↔ cmd/labproxy/proxy.go).
const containerCredentialDomain = "mindforge/container-credential/v1:"

func deriveContainerCredential(secret, sessionID string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	// Domain-separation prefix: the secret also signs auth JWTs and the
	// student can read their own credential inside the container, so the
	// HMAC input must never be able to coincide with a JWT signing input.
	mac.Write([]byte(containerCredentialDomain + sessionID))
	return hex.EncodeToString(mac.Sum(nil))
}

type wsClaims struct {
	SessionID string `json:"session_id"`
	UserID    string `json:"user_id"`
	Type      string `json:"typ"`
	jwt.RegisteredClaims
}

type labSession struct {
	ID            string
	UserID        string
	Status        string
	ContainerID   *string
	ContainerHost *string
}

// ProxyHandler upgrades browser WebSocket connections and relays them to the
// per-session ttyd container. It tracks live connections via a WaitGroup so
// main.go can wait for a clean drain on shutdown.
type ProxyHandler struct {
	pool          *pgxpool.Pool
	rdb           *redis.Client
	jwtSecret     string
	jwtIssuer     string
	previewDomain string
	upgrader      websocket.Upgrader
	wg            sync.WaitGroup
	draining      atomic.Bool
}

// NewProxyHandler constructs a ProxyHandler with all dependencies injected.
// This process never touches Docker or the Kubernetes API — resuming a
// paused container is the main API's job (labs.Service.MintWSToken), done
// before it ever hands out the token requests here are authenticated with.
// previewDomain is LABPROXY_PREVIEW_DOMAIN — the suffix preview subdomains
// (p<port>-<sessionID>.<previewDomain>) are matched against; see host.go and
// preview_host.go.
func NewProxyHandler(pool *pgxpool.Pool, rdb *redis.Client, jwtSecret, jwtIssuer, previewDomain string) *ProxyHandler {
	return &ProxyHandler{
		pool:          pool,
		rdb:           rdb,
		jwtSecret:     jwtSecret,
		jwtIssuer:     jwtIssuer,
		previewDomain: previewDomain,
		upgrader: websocket.Upgrader{
			HandshakeTimeout: 10 * time.Second,
			CheckOrigin:      func(r *http.Request) bool { return true },
		},
	}
}

// ServeHTTP handles the full lifecycle of a proxied lab session:
// JWT validation → session load → optional unpause → WS upgrade → relay.
func (h *ProxyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if h.draining.Load() {
		writeJSONError(w, http.StatusServiceUnavailable, "service draining")
		return
	}

	tokenStr := r.URL.Query().Get("session_token")
	if tokenStr == "" {
		writeJSONError(w, http.StatusUnauthorized, "missing session_token")
		return
	}

	claims, err := validateWSToken(tokenStr, h.jwtSecret, h.jwtIssuer)
	if err != nil {
		slog.Warn("labproxy: invalid token", "error", err)
		writeJSONError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if !h.tokenIsLive(r.Context(), tokenStr) {
		writeJSONError(w, http.StatusUnauthorized, "token revoked or expired")
		return
	}

	var sess labSession
	err = h.pool.QueryRow(r.Context(),
		`SELECT id, user_id, status, container_id, container_host
		 FROM lab_sessions WHERE id=$1`,
		claims.SessionID,
	).Scan(&sess.ID, &sess.UserID, &sess.Status, &sess.ContainerID, &sess.ContainerHost)
	if err != nil {
		writeJSONError(w, http.StatusNotFound, "session not found")
		return
	}

	// IDOR guard: token's user_id must match the session's owner.
	if sess.UserID != claims.UserID {
		writeJSONError(w, http.StatusForbidden, "forbidden")
		return
	}

	// labproxy has no Docker/Kubernetes API access — resuming a paused
	// container is the main API's job, done synchronously inside
	// labs.Service.MintWSToken before it ever hands out the token this
	// request is authenticated with (see that method's own doc comment).
	// The client always mints a fresh token before connecting, so reaching
	// here with status still "paused" means the token is stale (session got
	// idle-paused again after minting) rather than something this process
	// can fix — reject and let the client re-mint, which resumes it.
	if sess.Status != "running" {
		writeJSONError(w, http.StatusConflict, "session not running — mint a fresh session_token and reconnect")
		return
	}

	if sess.ContainerHost == nil || *sess.ContainerHost == "" {
		writeJSONError(w, http.StatusServiceUnavailable, "container not ready")
		return
	}

	browserConn, upgradeErr := h.upgrader.Upgrade(w, r, nil)
	if upgradeErr != nil {
		// Upgrade writes the HTTP error itself; just return.
		return
	}

	// ttyd only accepts connections that negotiate the "tty" WebSocket
	// subprotocol; without it, it silently accepts the upgrade but never
	// spawns the shell.
	ttydDialer := &websocket.Dialer{Subprotocols: []string{"tty"}}
	// Basic-auth credential (docs/labs.md "Proxy ↔ Container Channel
	// Security"; docs/debug-labs.md Phase 0): recomputed here from the
	// session ID rather than stored anywhere, and presented on every
	// upstream connect. entrypoint.sh (lab-images/shared/entrypoint.sh)
	// starts ttyd with the matching -c user:pass written into the container
	// at claim/start time (labs.writeTTYDCredential) — a co-located
	// container on the shared bridge that reaches this port directly still
	// cannot attach without it.
	cred := deriveContainerCredential(h.jwtSecret, sess.ID)
	authHeader := http.Header{"Authorization": {
		"Basic " + base64.StdEncoding.EncodeToString([]byte(ttydCredentialUser+":"+cred)),
	}}
	containerConn, _, dialErr := ttydDialer.DialContext(
		r.Context(),
		"ws://"+*sess.ContainerHost+"/ws",
		authHeader,
	)
	if dialErr != nil {
		slog.Error("labproxy: dial container",
			"host", *sess.ContainerHost, "session", sess.ID, "error", dialErr)
		_ = browserConn.Close()
		return
	}

	h.wg.Add(1)
	defer h.wg.Done()

	// Debounced last_active_at: update every 5s while the relay is alive.
	stopHeartbeat := make(chan struct{})
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				h.writeHeartbeat(context.Background(), sess.ID)
			case <-stopHeartbeat:
				return
			}
		}
	}()

	// Bidirectional relay: when either side closes, signal done so we can
	// clean up both connections.
	done := make(chan struct{})
	go func() {
		defer close(done)
		relay(browserConn, containerConn)
	}()
	go func() {
		relay(containerConn, browserConn)
	}()

	<-done
	close(stopHeartbeat)
	_ = browserConn.Close()
	_ = containerConn.Close()
}

// relay copies WebSocket messages from src to dst until either connection
// closes or encounters an error. Control frames with a null byte prefix are
// filtered to avoid confusing ttyd.
func relay(src, dst *websocket.Conn) {
	for {
		msgType, msg, err := src.ReadMessage()
		if err != nil {
			return
		}
		if len(msg) > 0 && msg[0] == 0x00 {
			continue
		}
		if err := dst.WriteMessage(msgType, msg); err != nil {
			return
		}
	}
}

// validateWSToken parses and validates a signed HS256 JWT, returning the embedded
// claims on success. Extracted as a standalone function so it can be unit-tested
// without a running HTTP server.
func validateWSToken(tokenStr, secret, issuer string) (*wsClaims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &wsClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("labproxy: unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(secret), nil
	})
	if err != nil {
		return nil, fmt.Errorf("labproxy: parse token: %w", err)
	}
	if !token.Valid {
		return nil, fmt.Errorf("labproxy: token not valid")
	}
	claims, ok := token.Claims.(*wsClaims)
	if !ok {
		return nil, fmt.Errorf("labproxy: unexpected claims type")
	}
	if claims.Issuer != issuer {
		return nil, fmt.Errorf("labproxy: issuer mismatch: got %q, want %q",
			claims.Issuer, issuer)
	}
	if claims.Type != wsTokenType {
		return nil, fmt.Errorf("labproxy: unexpected token type: got %q, want %q",
			claims.Type, wsTokenType)
	}
	return claims, nil
}

// tokenIsLive checks the Redis registry MintWSToken writes every token into
// (labs.Service.MintWSToken's doc comment) — a second factor alongside the
// JWT signature/expiry that lets a specific token be revoked (DEL) without
// needing to end the session it belongs to. Fails OPEN on a Redis error: a
// Redis outage must not lock every student out of every running lab, and the
// JWT's own signature/expiry/issuer/type checks already ran before this is
// reached — this registry is defense-in-depth on top of that, not the sole
// gate.
// previewHeartbeatDebounce bounds how often preview traffic (HTTP passthrough
// and WebSocket upgrades — see previewTarget in preview.go, the single
// choke point every preview request resolves through) is allowed to write
// last_active_at. Matches the terminal relay's own 5s ticker interval
// (ServeHTTP above) so both paths keep a session's idle clock alive at the
// same granularity, without a DB write on literally every preview request —
// a student's app can easily fire many requests per second.
const previewHeartbeatDebounce = 5 * time.Second

// writeHeartbeat unconditionally sets last_active_at=now() for sessionID.
// Called on the terminal relay's own ticker (already interval-bound, so no
// further debounce needed there) and, via heartbeatPreview below, once per
// debounce window for preview traffic. A failed write is logged and
// swallowed — a heartbeat miss costs nothing worse than a session idle-
// pausing a little earlier than ideal, never a failed request.
func (h *ProxyHandler) writeHeartbeat(ctx context.Context, sessionID string) {
	if _, err := h.pool.Exec(ctx,
		`UPDATE lab_sessions SET last_active_at=now() WHERE id=$1`, sessionID,
	); err != nil {
		slog.Warn("labproxy: heartbeat update", "session", sessionID, "error", err)
	}
}

// heartbeatPreview is writeHeartbeat's debounced counterpart for preview
// traffic (docs/debug-labs.md "Pre-existing problems": only the terminal
// relay updated last_active_at, so a student working only in the preview
// pane got idle-paused). Redis SetNX provides the debounce — the same
// primitive VerifyTask's rate limit already uses (service.go) — so at most
// one process across every replica writes the DB per session per window,
// no matter how many preview requests land inside it. Best-effort: a Redis
// error fails open (heartbeat skipped this round, not the request), since
// this must never block or fail the preview response it rides along with.
func (h *ProxyHandler) heartbeatPreview(ctx context.Context, sessionID string) {
	key := "lab:preview-heartbeat:" + sessionID
	set, err := h.rdb.SetNX(ctx, key, 1, previewHeartbeatDebounce).Result()
	if err != nil {
		slog.Warn("labproxy: preview heartbeat debounce check", "session", sessionID, "error", err)
		return
	}
	if !set {
		return
	}
	h.writeHeartbeat(ctx, sessionID)
}

func (h *ProxyHandler) tokenIsLive(ctx context.Context, tokenStr string) bool {
	_, err := h.rdb.Get(ctx, "lab:wstoken:"+tokenStr).Result()
	if err == redis.Nil {
		return false
	}
	if err != nil {
		slog.Warn("labproxy: token registry check failed, failing open", "error", err)
	}
	return true
}

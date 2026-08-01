package main

import (
	"context"
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
	pool      *pgxpool.Pool
	rdb       *redis.Client
	jwtSecret string
	jwtIssuer string
	upgrader  websocket.Upgrader
	wg        sync.WaitGroup
	draining  atomic.Bool
}

// NewProxyHandler constructs a ProxyHandler with all dependencies injected.
// This process never touches Docker or the Kubernetes API — resuming a
// paused container is the main API's job (labs.Service.MintWSToken), done
// before it ever hands out the token requests here are authenticated with.
func NewProxyHandler(pool *pgxpool.Pool, rdb *redis.Client, jwtSecret, jwtIssuer string) *ProxyHandler {
	return &ProxyHandler{
		pool:      pool,
		rdb:       rdb,
		jwtSecret: jwtSecret,
		jwtIssuer: jwtIssuer,
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
		http.Error(w, "service draining", http.StatusServiceUnavailable)
		return
	}

	tokenStr := r.URL.Query().Get("session_token")
	if tokenStr == "" {
		http.Error(w, "missing session_token", http.StatusUnauthorized)
		return
	}

	claims, err := validateWSToken(tokenStr, h.jwtSecret, h.jwtIssuer)
	if err != nil {
		slog.Warn("labproxy: invalid token", "error", err)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	if !h.tokenIsLive(r.Context(), tokenStr) {
		http.Error(w, "token revoked or expired", http.StatusUnauthorized)
		return
	}

	var sess labSession
	err = h.pool.QueryRow(r.Context(),
		`SELECT id, user_id, status, container_id, container_host
		 FROM lab_sessions WHERE id=$1`,
		claims.SessionID,
	).Scan(&sess.ID, &sess.UserID, &sess.Status, &sess.ContainerID, &sess.ContainerHost)
	if err != nil {
		http.Error(w, "session not found", http.StatusNotFound)
		return
	}

	// IDOR guard: token's user_id must match the session's owner.
	if sess.UserID != claims.UserID {
		http.Error(w, "forbidden", http.StatusForbidden)
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
		http.Error(w, "session not running — mint a fresh session_token and reconnect", http.StatusConflict)
		return
	}

	if sess.ContainerHost == nil || *sess.ContainerHost == "" {
		http.Error(w, "container not ready", http.StatusServiceUnavailable)
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
	containerConn, _, dialErr := ttydDialer.DialContext(
		r.Context(),
		"ws://"+*sess.ContainerHost+"/ws",
		nil,
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
				if _, hbErr := h.pool.Exec(context.Background(),
					`UPDATE lab_sessions SET last_active_at=now() WHERE id=$1`,
					sess.ID); hbErr != nil {
					slog.Warn("labproxy: heartbeat update",
						"session", sess.ID, "error", hbErr)
				}
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

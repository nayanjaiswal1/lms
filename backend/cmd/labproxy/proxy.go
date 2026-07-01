package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os/exec"
	"sync"
	"sync/atomic"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type wsClaims struct {
	SessionID string `json:"session_id"`
	UserID    string `json:"user_id"`
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
	rdb       *redis.Client // reserved for heartbeat pub/sub in a future phase
	jwtSecret string
	jwtIssuer string
	upgrader  websocket.Upgrader
	wg        sync.WaitGroup
	draining  atomic.Bool
}

// NewProxyHandler constructs a ProxyHandler with all dependencies injected.
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

	if sess.Status == "paused" {
		if sess.ContainerID != nil && *sess.ContainerID != "" {
			if unpauseErr := exec.CommandContext(r.Context(),
				"docker", "unpause", *sess.ContainerID).Run(); unpauseErr != nil {
				slog.Warn("labproxy: docker unpause failed",
					"container", *sess.ContainerID, "error", unpauseErr)
			}
		}
		if _, execErr := h.pool.Exec(r.Context(),
			`UPDATE lab_sessions SET status='running', last_active_at=now() WHERE id=$1`,
			sess.ID); execErr != nil {
			slog.Error("labproxy: unpause status update", "session", sess.ID, "error", execErr)
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		sess.Status = "running"
	}

	if sess.Status != "running" {
		http.Error(w, "session not running", http.StatusConflict)
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

	containerConn, _, dialErr := websocket.DefaultDialer.DialContext(
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
	return claims, nil
}

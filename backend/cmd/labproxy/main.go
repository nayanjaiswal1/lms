package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	idb "github.com/mindforge/backend/internal/db"
	"github.com/redis/go-redis/v9"
)

func main() {
	port := getEnv("LABPROXY_PORT", "8081")
	dbURL := os.Getenv("LABPROXY_DB_URL")
	redisURL := getEnv("LABPROXY_REDIS_URL", "redis://localhost:6379/0")
	jwtSecret := os.Getenv("LABPROXY_JWT_SECRET")
	jwtIssuer := getEnv("LABPROXY_JWT_ISSUER", "mindforge-labproxy")
	previewDomain := os.Getenv("LABPROXY_PREVIEW_DOMAIN")

	if dbURL == "" {
		fatal("labproxy: LABPROXY_DB_URL is required")
	}
	if jwtSecret == "" {
		fatal("labproxy: LABPROXY_JWT_SECRET is required")
	}
	allowedOrigins := parseAllowedOrigins(os.Getenv("LABPROXY_ALLOWED_ORIGINS"))
	if len(allowedOrigins) == 0 {
		fatal("labproxy: LABPROXY_ALLOWED_ORIGINS is required (comma-separated app origins)")
	}
	if previewDomain == "" {
		fatal("labproxy: LABPROXY_PREVIEW_DOMAIN is required")
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	pool, err := idb.Connect(ctx, dbURL)
	if err != nil {
		fatal("labproxy: connect postgres", "error", err)
	}
	defer pool.Close()
	slog.Info("labproxy: postgres connected")

	redisOpts, err := redis.ParseURL(redisURL)
	if err != nil {
		fatal("labproxy: invalid LABPROXY_REDIS_URL", "error", err)
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()

	handler := NewProxyHandler(pool, rdb, jwtSecret, jwtIssuer, previewDomain, allowedOrigins)

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: newRootHandler(handler, previewDomain),
	}

	go func() {
		slog.Info("labproxy: listening", "port", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fatal("labproxy: serve", "error", err)
		}
	}()

	<-ctx.Done()
	slog.Info("labproxy: signal received, draining connections")
	drain(handler, srv)
	os.Exit(0)
}

// fatal logs and exits non-zero; used for startup and listener failures.
func fatal(msg string, args ...any) {
	slog.Error(msg, args...)
	os.Exit(1)
}

// newRootHandler sends preview-subdomain Hosts to the preview handlers and every
// other Host to the ordinary mux.
func newRootHandler(handler *ProxyHandler, previewDomain string) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/ws", handler)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "ok")
	})
	// Live app preview entry point: validates the token and 302s to the
	// preview subdomain (see preview.go's ServePreview doc comment). Once
	// there, every request is dispatched by the host-based router below —
	// this mux never sees them.
	mux.HandleFunc("/preview/", handler.ServePreview)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		previewPort, sessionID, ok := splitPreviewHost(r.Host, previewDomain)
		if !ok {
			mux.ServeHTTP(w, r)
			return
		}
		if r.URL.Path == "/__mf/preview-auth" {
			handler.ServePreviewAuth(w, r, previewPort, sessionID)
			return
		}
		handler.ServePreviewPassthrough(w, r, previewPort, sessionID)
	})
}

// drain refuses new requests, waits up to 90s for live relays, then shuts down srv.
func drain(handler *ProxyHandler, srv *http.Server) {
	handler.draining.Store(true)

	drainDone := make(chan struct{})
	go func() {
		handler.wg.Wait()
		close(drainDone)
	}()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	select {
	case <-drainDone:
		slog.Info("labproxy: all connections closed cleanly")
	case <-shutdownCtx.Done():
		slog.Warn("labproxy: drain timeout reached, forcing exit")
	}

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Warn("labproxy: http shutdown", "error", err)
	}
}

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

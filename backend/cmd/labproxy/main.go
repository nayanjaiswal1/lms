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
		slog.Error("labproxy: LABPROXY_DB_URL is required")
		os.Exit(1)
	}
	if jwtSecret == "" {
		slog.Error("labproxy: LABPROXY_JWT_SECRET is required")
		os.Exit(1)
	}
	if previewDomain == "" {
		slog.Error("labproxy: LABPROXY_PREVIEW_DOMAIN is required")
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	pool, err := idb.Connect(ctx, dbURL)
	if err != nil {
		slog.Error("labproxy: connect postgres", "error", err)
		os.Exit(1)
	}
	defer pool.Close()
	slog.Info("labproxy: postgres connected")

	redisOpts, err := redis.ParseURL(redisURL)
	if err != nil {
		slog.Error("labproxy: invalid LABPROXY_REDIS_URL", "error", err)
		os.Exit(1)
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()

	handler := NewProxyHandler(pool, rdb, jwtSecret, jwtIssuer, previewDomain)

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

	// Host-based routing for preview subdomains
	// (p<port>-<sessionID>.<previewDomain>) — checked ahead of the ordinary
	// mux above so every path on a matching Host goes to the preview
	// handlers regardless of what it looks like, and every other Host falls
	// through to /ws, /health, /preview/ unchanged.
	root := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: root,
	}

	go func() {
		slog.Info("labproxy: listening", "port", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("labproxy: serve", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	slog.Info("labproxy: signal received, draining connections")
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

	_ = srv.Shutdown(shutdownCtx)
	os.Exit(0)
}

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

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

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

func main() {
	port := getEnv("LABPROXY_PORT", "8081")
	dbURL := os.Getenv("LABPROXY_DB_URL")
	redisURL := getEnv("LABPROXY_REDIS_URL", "redis://localhost:6379/0")
	jwtSecret := os.Getenv("LABPROXY_JWT_SECRET")
	jwtIssuer := getEnv("LABPROXY_JWT_ISSUER", "mindforge-labproxy")

	if dbURL == "" {
		slog.Error("labproxy: LABPROXY_DB_URL is required")
		os.Exit(1)
	}
	if jwtSecret == "" {
		slog.Error("labproxy: LABPROXY_JWT_SECRET is required")
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		slog.Error("labproxy: connect postgres", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		slog.Error("labproxy: ping postgres", "error", err)
		os.Exit(1)
	}
	slog.Info("labproxy: postgres connected")

	redisOpts, err := redis.ParseURL(redisURL)
	if err != nil {
		slog.Error("labproxy: invalid LABPROXY_REDIS_URL", "error", err)
		os.Exit(1)
	}
	rdb := redis.NewClient(redisOpts)
	defer rdb.Close()

	handler := NewProxyHandler(pool, rdb, jwtSecret, jwtIssuer)

	mux := http.NewServeMux()
	mux.Handle("/ws", handler)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "ok")
	})

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
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

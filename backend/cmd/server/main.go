package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"
	"github.com/mindforge/backend/db"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/api"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/config"
	idb "github.com/mindforge/backend/internal/db"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/jobs/handlers"
	"github.com/mindforge/backend/internal/session"
	"github.com/mindforge/backend/internal/storage"
	"github.com/redis/go-redis/v9"
)

func main() {
	// Load .env in development; silently skip if the file is absent (production).
	_ = godotenv.Load()

	cfg := config.Load()

	// ─── Database ────────────────────────────────────────────────────────────
	ctx := context.Background()
	pool, err := idb.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()
	slog.Info("database connected")

	if err := db.RunMigrations(ctx, pool); err != nil {
		slog.Error("migrations failed", "error", err)
		os.Exit(1)
	}
	slog.Info("migrations up to date")

	if !cfg.IsProd() {
		if err := db.SeedDev(ctx, pool); err != nil {
			slog.Warn("dev seed failed (non-fatal)", "error", err)
		} else {
			slog.Info("dev seed applied")
		}
	}

	// ─── Redis ───────────────────────────────────────────────────────────────
	// REDIS_URL is a full URL (redis://host:port/db, or rediss:// for TLS), so it
	// must be parsed into Options — passing it as Addr (host:port) fails with
	// "too many colons in address".
	redisOpts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		slog.Error("invalid REDIS_URL", "error", err)
		os.Exit(1)
	}
	rdb := redis.NewClient(redisOpts)
	if err := rdb.Ping(ctx).Err(); err != nil {
		slog.Error("failed to connect to redis", "error", err)
		os.Exit(1)
	}
	defer rdb.Close()
	slog.Info("redis connected")

	cache := session.NewCache(rdb, pool)

	// ─── Storage (MinIO) ──────────────────────────────────────────────────────
	storageClient, err := storage.NewMinioClient(cfg)
	if err != nil {
		slog.Error("minio: init failed", "error", err)
		os.Exit(1)
	}
	if err := storageClient.EnsureBucket(context.Background()); err != nil {
		slog.Error("minio: ensure bucket failed", "error", err)
		os.Exit(1)
	}
	slog.Info("minio storage ready")

	// ─── AI Provider ─────────────────────────────────────────────────────────
	aiProvider := ai.NewProvider(cfg.LLMProvider, cfg.LLMAPIKey, cfg.LLMModel, cfg.LLMBaseURL)
	slog.Info("ai provider configured", "provider", cfg.LLMProvider, "available", aiProvider.Available())

	// ─── Instance ID ─────────────────────────────────────────────────────────
	instanceID := os.Getenv("INSTANCE_ID")
	if instanceID == "" {
		h, err := os.Hostname()
		if err != nil {
			instanceID = "unknown"
		} else {
			instanceID = h
		}
	}

	// ─── Job Management System ────────────────────────────────────────────────
	assessmentRepo := assessment.NewRepo(pool)

	jobsRegistry := jobs.NewRegistry()
	jobsRegistry.Register(handlers.HandlerEvalSubjective, handlers.NewEvalHandler(assessmentRepo, aiProvider, cfg, pool))
	jobsRegistry.Register(handlers.HandlerEmailSend, handlers.NewEmailHandler(cfg))
	jobsRegistry.Register(handlers.HandlerBulkInvite, handlers.NewInviteHandler(pool, cfg))
	jobsRegistry.Register(handlers.HandlerLLM, handlers.NewLLMHandler(pool, aiProvider, cfg))
	jobsRegistry.Register(handlers.HandlerSRSReminder, handlers.NewSRSHandler(pool, cfg))
	jobsRegistry.Register(handlers.HandlerAnalytics, handlers.NewAnalyticsHandler(pool))

	cronDefs := []jobs.CronJobDef{
		{Handler: handlers.HandlerSRSReminder, Schedule: "0 8 * * *", Priority: jobs.PriorityBackground, TimeoutMS: 120000},
		{Handler: handlers.HandlerAnalytics, Schedule: "0 2 * * *", Priority: jobs.PriorityBackground, TimeoutMS: 300000},
		{Handler: handlers.HandlerAnalytics, Schedule: "0 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 60000},
	}

	workerCtx, workerCancel := context.WithCancel(ctx)
	defer workerCancel()

	workerPool := jobs.NewWorkerPool(pool, rdb, jobsRegistry, cfg, instanceID)
	scheduler := jobs.NewScheduler(pool, rdb, cfg, jobsRegistry, instanceID, cronDefs)

	go workerPool.Start(workerCtx)
	go scheduler.Start(workerCtx)

	// ─── Router ──────────────────────────────────────────────────────────────
	router := api.NewRouter(cfg, pool, cache, rdb, storageClient, aiProvider, jobsRegistry)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// ─── Graceful shutdown ────────────────────────────────────────────────────
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)

	go func() {
		slog.Info("server starting", "port", cfg.Port, "env", cfg.Env)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	<-quit
	slog.Info("shutdown signal received, draining connections...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}

	slog.Info("server stopped cleanly")
}

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
	"github.com/mindforge/backend/internal/courses"
	idb "github.com/mindforge/backend/internal/db"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/jobs/handlers"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/mailer"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/rewards"
	"github.com/mindforge/backend/internal/secrets"
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

	// ─── Lab Sandbox Runtime ───────────────────────────────────────────────────
	// Built once and shared by the labs HTTP handler (api.NewRouter) and the
	// reaper job handlers below, so a Kubernetes deploy constructs exactly one
	// in-cluster client rather than one per consumer.
	//
	// labsImageProfileCatalog is the small in-code catalog of named
	// ImageProfiles LABS_IMAGE_PROFILES entries resolve against — today just
	// "nested-docker" (see labs.ImageProfileNestedDocker / docs/labs.md
	// "Nested Docker labs"). Adding a second real profile means adding one
	// more entry here.
	labsImageProfileCatalog := map[string]labs.ImageProfile{
		labs.ImageProfileNestedDocker: {
			Name:                 labs.ImageProfileNestedDocker,
			CPU:                  labs.NestedContainerCPU,
			MemoryMB:             labs.NestedContainerMemoryMB,
			Network:              labs.NestedLabNetwork,
			SkipPreWarm:          true,
			RequiresOrgAllowlist: true,
			DockerMechanism: func() string {
				if cfg.LabsNestedDockerRuntime == "sysbox-runc" {
					return "sysbox-runc"
				}
				return "rootless-dind"
			}(),
			K8sRuntimeClass:      cfg.LabsNestedDockerRuntimeClass,
			K8sExtraVolume:       true,
			K8sExtraVolumeSizeGB: labs.NestedContainerDiskGB,
		},
	}
	labsImageProfiles := make(map[string]labs.ImageProfile, len(cfg.LabsImageProfiles))
	for image, profileName := range cfg.LabsImageProfiles {
		profile, ok := labsImageProfileCatalog[profileName]
		if !ok {
			slog.Error("labs: LABS_IMAGE_PROFILES references unknown profile name", "image", image, "profile", profileName)
			os.Exit(1)
		}
		labsImageProfiles[image] = profile
	}

	var labsRuntime labs.ContainerRuntime
	switch cfg.LabsRuntime {
	case "kubernetes":
		labsRuntime, err = labs.NewKubernetesContainerService(cfg.LabsK8sNamespace, labsImageProfiles, cfg.LabsImageRegistry)
		if err != nil {
			slog.Error("labs: kubernetes runtime init failed", "error", err)
			os.Exit(1)
		}
		slog.Info("labs: kubernetes runtime ready", "namespace", cfg.LabsK8sNamespace, "image_registry", cfg.LabsImageRegistry)
	default:
		labsRuntime = labs.NewDockerContainerService(labsImageProfiles)
		slog.Info("labs: docker runtime ready")
	}
	if len(labsImageProfiles) > 0 {
		slog.Info("labs: image profiles enabled", "images", cfg.LabsImageProfiles)
	}

	// Fatal rather than "log and carry on": an operator who typo'd an override
	// they set to stop warming a misbehaving image must not be left believing
	// it took effect while the planner keeps warming it.
	labsWarmPoolOverrides, err := labs.ParseWarmPoolOverrides(cfg.LabsWarmPoolOverrides)
	if err != nil {
		slog.Error("labs: invalid LABS_WARM_POOL_OVERRIDES", "error", err)
		os.Exit(1)
	}
	if len(labsWarmPoolOverrides) > 0 {
		slog.Info("labs: warm pool overrides active", "overrides", cfg.LabsWarmPoolOverrides)
	}

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

	// ─── Rewards ──────────────────────────────────────────────────────────────
	rewardsSvc := rewards.NewServiceFromPool(pool, rdb)
	go rewardsSvc.WarmLeaderboards(ctx)

	// ─── Job Management System ────────────────────────────────────────────────
	assessmentRepo := assessment.NewRepo(pool)
	// A standalone courses.Service instance for the eval worker — it holds no
	// in-process state beyond shared pointers (pool, store, ai, rewards), so
	// constructing it separately from api.NewRouter's own instance is safe.
	coursesSvcForJobs := courses.NewService(courses.NewRepo(pool), storageClient, aiProvider, cfg, rewardsSvc)

	jobsRegistry := jobs.NewRegistry()

	// A standalone assessment.Handler for the expire-attempts reaper — like
	// coursesSvcForJobs above, constructed separately from api.NewRouter's own
	// instance since it holds no in-process state beyond shared pointers.
	assessmentHandlerForJobs := assessment.New(pool, cfg, jobsRegistry, rewardsSvc, coursesSvcForJobs, storageClient, labsRuntime)

	// A standalone secrets.Vault + gitlab.Service for the token-refresh job —
	// like assessmentHandlerForJobs above, built separately from
	// api.NewRouter's own instance since a Vault holds no state beyond its
	// derived AES key, so constructing a second one here is safe as long as
	// both derive from the same cfg.EncryptionKey.
	gitlabVault, err := secrets.New(cfg)
	if err != nil {
		slog.Error("gitlab: secrets vault init failed", "error", err)
		os.Exit(1)
	}
	// A standalone notifications.Service for the same reason — it holds no
	// state beyond shared pointers (pool, jobsRegistry), so a second instance
	// alongside api.NewRouter's own is safe. gitlab.ingest_event (registered
	// below) is the job that needs it: Batch 5's checkpoint/peer-review
	// notifications fire from inside webhook ingest, which runs here.
	notificationsSvcForJobs := notifications.NewService(pool, jobsRegistry)
	gitlabSvcForJobs := gitlab.NewService(pool, cfg, gitlabVault, jobsRegistry, notificationsSvcForJobs)

	jobsRegistry.Register(handlers.HandlerEvalSubjective, handlers.NewEvalHandler(assessmentRepo, aiProvider, cfg, pool, rewardsSvc, coursesSvcForJobs))
	// Fires once, exactly when an eval.subjective job permanently dies, instead
	// of a separate cron job polling for the same condition after the fact —
	// see Registry.OnDead / DeadLetterHook.
	jobsRegistry.OnDead(handlers.HandlerEvalSubjective, handlers.NewEvalDeadHook(pool))
	emailSender := mailer.NewSMTPSender(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPass, cfg.EmailFrom)
	jobsRegistry.Register(handlers.HandlerEmailSend, handlers.NewEmailHandler(cfg, emailSender))
	// A dead email.send job used to leave nothing but last_error on the jobs
	// row — nobody was told a user-facing email (e.g. a password reset) will
	// never arrive. This turns that into a structured, alertable log line.
	jobsRegistry.OnDead(handlers.HandlerEmailSend, handlers.NewEmailDeadHook())
	jobsRegistry.Register(handlers.HandlerBulkInvite, handlers.NewInviteHandler(pool, cfg))
	jobsRegistry.OnDead(handlers.HandlerBulkInvite, handlers.NewInviteDeadHook())
	jobsRegistry.Register(handlers.HandlerLLM, handlers.NewLLMHandler(pool, aiProvider, cfg))
	jobsRegistry.Register(handlers.HandlerSRSReminder, handlers.NewSRSHandler(pool, cfg))
	jobsRegistry.Register(handlers.HandlerAnalytics, handlers.NewAnalyticsHandler(pool))
	jobsRegistry.Register(handlers.HandlerLabExpire, handlers.NewLabExpireHandler(pool, labsRuntime, notificationsSvcForJobs))
	jobsRegistry.Register(handlers.HandlerLabCleanup, handlers.NewLabCleanupHandler(pool, labsRuntime))
	jobsRegistry.Register(handlers.HandlerLabWarmPool, handlers.NewLabWarmPoolHandler(pool, labsRuntime, cfg.LabsWarmPoolGlobalMax, labsWarmPoolOverrides))
	jobsRegistry.Register(handlers.HandlerAssessmentExpire, handlers.NewAssessmentExpireHandler(assessmentHandlerForJobs))
	jobsRegistry.Register(handlers.HandlerMentorEscalate, handlers.NewMentorEscalationHandler(pool, cfg))
	jobsRegistry.Register(handlers.HandlerCalendarReminder, handlers.NewCalendarReminderHandler(pool, cfg))
	jobsRegistry.Register(handlers.HandlerBatchImport, handlers.NewBatchImportHandler(pool, cfg))
	jobsRegistry.Register(handlers.HandlerGitlabTokenRefresh, handlers.NewGitlabTokenRefreshHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabProvisionTeam, handlers.NewGitlabProvisionTeamHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabSyncMembers, handlers.NewGitlabSyncMembersHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabIngestEvent, handlers.NewGitlabIngestEventHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabCommitStats, handlers.NewGitlabCommitStatsHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabPollSync, handlers.NewGitlabPollSyncHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabDeadlineSnapshot, handlers.NewGitlabDeadlineSnapshotHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabTemplateSync, handlers.NewGitlabTemplateSyncHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabOriginalityScan, handlers.NewGitlabOriginalityScanHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerGitlabHandoff, handlers.NewGitlabHandoffHandler(gitlabSvcForJobs))
	jobsRegistry.Register(handlers.HandlerDigestNightly, handlers.NewDigestNightlyHandler(pool))
	jobsRegistry.Register(handlers.HandlerDigestUser, handlers.NewDigestUserHandler(pool, aiProvider, cfg, jobsRegistry))

	cronDefs := []jobs.CronJobDef{
		{Handler: handlers.HandlerSRSReminder, Schedule: "0 8 * * *", Priority: jobs.PriorityBackground, TimeoutMS: 120000},
		{Handler: handlers.HandlerAnalytics, Schedule: "0 2 * * *", Priority: jobs.PriorityBackground, TimeoutMS: 300000},
		{Handler: handlers.HandlerAnalytics, Schedule: "0 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 60000},
		{Handler: handlers.HandlerLabExpire, Schedule: "* * * * *", Priority: jobs.PriorityHigh, TimeoutMS: 30000},
		{Handler: handlers.HandlerLabCleanup, Schedule: "*/10 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 60000},
		// TimeoutMS must clear labs.ProvisionTimeoutSeconds (180s): converge's
		// scale-up goroutines give each warm start that same budget a cold-
		// started session gets (a slow image pull or setup_script — e.g. a
		// web-app lab's dev-server cold start — can legitimately need most of
		// it), and Tick's wg.Wait() blocks the whole job until every
		// outstanding goroutine returns. A shorter job timeout than that
		// budget doesn't stop the goroutine (Go has no forced-cancel), but it
		// does make the scheduler log every slow-but-successful warm attempt
		// as a job timeout and can trigger an overlapping next-minute tick.
		// (Nested-Docker images are excluded from the warm pool entirely —
		// ImageProfile.SkipPreWarm — so they are not what this margin is for.)
		{Handler: handlers.HandlerLabWarmPool, Schedule: "* * * * *", Priority: jobs.PriorityHigh, TimeoutMS: 210000},
		{Handler: handlers.HandlerAssessmentExpire, Schedule: "* * * * *", Priority: jobs.PriorityHigh, TimeoutMS: 60000},
		{Handler: handlers.HandlerMentorEscalate, Schedule: "0 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 60000},
		{Handler: handlers.HandlerCalendarReminder, Schedule: "*/5 * * * *", Priority: jobs.PriorityHigh, TimeoutMS: 60000},
		{Handler: handlers.HandlerGitlabTokenRefresh, Schedule: "*/15 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 60000},
		// provision_team is triggered by assignment-publish/team-create, not
		// cron — no entry here for it. sync_members' 30-min sweep is the
		// self-healing reconciliation pass for any roster change a per-team
		// enqueue somehow missed.
		{Handler: handlers.HandlerGitlabSyncMembers, Schedule: "*/30 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 120000},
		// ingest_event is triggered per webhook delivery, not cron — no entry
		// here for it. poll_sync is the self-healing pull for webhook_mode='poll'
		// installs or any team whose hook has gone silent.
		{Handler: handlers.HandlerGitlabPollSync, Schedule: "*/10 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 180000},
		// deadline_snapshot is the only Batch 6 job on a cron: past-due
		// checkpoints need to get their HEAD snapshot without a human
		// triggering it. template_sync/originality_scan/handoff are all
		// instructor/student-triggered actions — no cron entry for them.
		{Handler: handlers.HandlerGitlabDeadlineSnapshot, Schedule: "*/5 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 120000},
		// Hourly, not a fixed daily time: digestSendHourLocal (handlers/
		// digest_nightly.go) is evaluated per-user against their own
		// timezone, so an hourly tick is what actually gives every
		// timezone its own local 21:00 from one cron entry.
		{Handler: handlers.HandlerDigestNightly, Schedule: "0 * * * *", Priority: jobs.PriorityBackground, TimeoutMS: 120000},
	}

	workerCtx, workerCancel := context.WithCancel(ctx)
	defer workerCancel()

	workerPool := jobs.NewWorkerPool(pool, rdb, jobsRegistry, cfg, instanceID)
	scheduler := jobs.NewScheduler(pool, rdb, cfg, jobsRegistry, instanceID, cronDefs)

	go workerPool.Start(workerCtx)
	go scheduler.Start(workerCtx)

	// ─── Router ──────────────────────────────────────────────────────────────
	router := api.NewRouter(cfg, pool, cache, rdb, storageClient, aiProvider, jobsRegistry, rewardsSvc, labsRuntime)

	srv := &http.Server{
		Addr:        ":" + cfg.Port,
		Handler:     router,
		ReadTimeout: 15 * time.Second,
		// No WriteTimeout: it's a hard deadline on the whole response, which
		// kills long-lived SSE streams (labs.Service.WaitForReadiness) after
		// 30s even when the client is still legitimately waiting — every
		// handler that can run long already bounds itself via request context
		// (see ProvisionTimeoutSeconds).
		IdleTimeout: 60 * time.Second,
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

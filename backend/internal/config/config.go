package config

import (
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all validated runtime configuration for the server.
// Fatal exit on startup if any required field is missing or insecure.
type Config struct {
	// Server
	Port string
	Env  string

	// Database / Redis
	DatabaseURL string
	RedisURL    string

	// Secrets — enforced: non-empty, no "change_me" prefix, >= 32 bytes
	JWTSecret     string
	CookieSecret  string
	EncryptionKey string

	// Token TTLs
	AccessTokenTTL       time.Duration
	RefreshTokenTTL      time.Duration
	EmailVerificationTTL time.Duration
	PasswordResetTTL     time.Duration

	// Tenancy
	DefaultOrgID string

	// Frontend / self URL
	FrontendURL string
	BackendURL  string

	// WebAuthn (passkey login) relying-party config — RPID/RPOrigin derive
	// from FrontendURL; only the display name is a real env var.
	WebAuthnRPID          string
	WebAuthnRPOrigin      string
	WebAuthnRPDisplayName string

	// Social OAuth
	GoogleClientID     string
	GoogleClientSecret string
	GitHubClientID     string
	GitHubClientSecret string

	// SMTP
	SMTPHost  string
	SMTPPort  string
	SMTPUser  string
	SMTPPass  string
	EmailFrom string

	// Rate limiting
	AuthRateLimitMax    int
	AuthRateLimitWindow time.Duration

	// Code execution (coding-question auto-grading).
	// Piston takes priority when both are set; Judge0 is the fallback.
	// When neither URL is set the executor is unconfigured and coding answers stay
	// pending until an instructor grades them manually — MCQ grading is unaffected.
	PistonURL     string
	PistonTimeout time.Duration
	Judge0URL     string
	Judge0Token   string
	Judge0Timeout time.Duration

	// Lab sandbox runtime: "docker" (shells out to the Docker CLI against a
	// mounted host socket — VPS/Compose deploys) or "kubernetes" (creates one
	// Pod per lab session via the in-cluster API — K8s deploys). Any other
	// value falls back to "docker".
	LabsRuntime      string
	LabsK8sNamespace string

	// Total warm lab containers allowed across all labs (0 disables warming).
	// Per-lab targets come from the metrics-driven planner, capped by this.
	LabsWarmPoolGlobalMax int

	// Object storage (MinIO / S3-compatible).
	// When MinioAccessKey is empty, avatar upload returns 503; other features unaffected.
	MinioEndpoint  string
	MinioAccessKey string
	MinioSecretKey string
	MinioBucket    string
	MinioUseSSL    bool
	// MinioPublicEndpoint/MinioPublicUseSSL build the URLs handed back to the
	// browser. They default to the internal values but must be overridden
	// whenever MinioEndpoint is a Docker-network-only hostname (e.g. "minio:9000")
	// that isn't resolvable outside the compose network.
	MinioPublicEndpoint string
	MinioPublicUseSSL   bool

	// LLM provider (AI course generation and interview prep).
	// LLMProvider: "anthropic" | "gemini" | "disabled"
	// Fatal on startup if LLMProvider != "disabled" and LLMAPIKey is empty.
	LLMProvider string
	LLMAPIKey   string
	LLMModel    string
	LLMBaseURL  string
	LLMTimeout  time.Duration

	// AI evaluation worker pool (subjective question grading).
	EvalWorkerCount int
	EvalMaxRetries  int
	EvalJobTimeout  time.Duration
	EvalStuckAfter  time.Duration

	// Job management system (worker pool, orphan reaper, distributed leader).
	WorkerPoolSize          int
	WorkerHeartbeatInterval time.Duration
	WorkerDrainTimeout      time.Duration
	OrphanReaperInterval    time.Duration
	OrphanThreshold         time.Duration
	SchedulerLeaderTTL      time.Duration
	SchedulerLeaderRenew    time.Duration

	// Calendar reminder job — how far ahead of an event's starts_at the
	// reminder email fires. No per-event/per-user override yet.
	CalendarReminderLeadMinutes int
}

// Load reads all env vars, validates required/secure fields, and returns Config.
// Calls log.Fatal (via slog + os.Exit(1)) if any required constraint is violated.
func Load() *Config {
	cfg := &Config{
		Port:               getEnvDefault("PORT", "8080"),
		Env:                getEnvDefault("ENV", "development"),
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		RedisURL:           os.Getenv("REDIS_URL"),
		JWTSecret:          os.Getenv("JWT_SECRET"),
		CookieSecret:       os.Getenv("COOKIE_SECRET"),
		EncryptionKey:      os.Getenv("ENCRYPTION_KEY"),
		DefaultOrgID:       os.Getenv("DEFAULT_ORG_ID"),
		FrontendURL:        getEnvDefault("FRONTEND_URL", "http://localhost:3000"),
		BackendURL:         getEnvDefault("BACKEND_URL", "http://localhost:8080"),
		GoogleClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		GitHubClientID:     os.Getenv("GITHUB_CLIENT_ID"),
		GitHubClientSecret: os.Getenv("GITHUB_CLIENT_SECRET"),
		SMTPHost:           getEnvDefault("SMTP_HOST", "localhost"),
		SMTPPort:           getEnvDefault("SMTP_PORT", "1025"),
		SMTPUser:           os.Getenv("SMTP_USER"),
		SMTPPass:           os.Getenv("SMTP_PASS"),
		EmailFrom:          getEnvDefault("EMAIL_FROM", "noreply@mindforge.dev"),
	}

	// Required non-empty string fields
	requireNonEmpty("DATABASE_URL", cfg.DatabaseURL)
	requireNonEmpty("REDIS_URL", cfg.RedisURL)

	// Required secret fields: non-empty, not a change_me placeholder, >= 32 bytes
	requireSecret("JWT_SECRET", cfg.JWTSecret)
	requireSecret("COOKIE_SECRET", cfg.CookieSecret)
	requireSecret("ENCRYPTION_KEY", cfg.EncryptionKey)

	// WebAuthn RP identity derives from FrontendURL: RPID is the bare hostname
	// (no scheme/port — the spec calls this the "effective domain"), RPOrigin
	// is the full origin the browser's navigator.credentials call must match.
	if u, err := url.Parse(cfg.FrontendURL); err != nil || u.Hostname() == "" {
		slog.Error("invalid FRONTEND_URL for WebAuthn relying-party config", "value", cfg.FrontendURL)
		os.Exit(1)
	} else {
		cfg.WebAuthnRPID = u.Hostname()
		cfg.WebAuthnRPOrigin = u.Scheme + "://" + u.Host
	}
	cfg.WebAuthnRPDisplayName = getEnvDefault("WEBAUTHN_RP_DISPLAY_NAME", "MindForge")

	// Parse token TTLs
	cfg.AccessTokenTTL = parseDuration("ACCESS_TOKEN_TTL", "15m")
	cfg.RefreshTokenTTL = parseDuration("REFRESH_TOKEN_TTL", "720h")
	cfg.EmailVerificationTTL = parseDuration("EMAIL_VERIFICATION_TTL", "24h")
	cfg.PasswordResetTTL = parseDuration("PASSWORD_RESET_TTL", "30m")

	// Parse rate limit config
	cfg.AuthRateLimitMax = getEnvInt("AUTH_RATE_LIMIT_MAX", 10)
	cfg.AuthRateLimitWindow = parseDuration("AUTH_RATE_LIMIT_WINDOW", "1m")

	// Code execution (optional — coding grading degrades gracefully when unset)
	cfg.PistonURL = strings.TrimRight(os.Getenv("PISTON_URL"), "/")
	cfg.PistonTimeout = parseDuration("PISTON_TIMEOUT", "30s")
	cfg.Judge0URL = strings.TrimRight(os.Getenv("JUDGE0_URL"), "/")
	cfg.Judge0Token = os.Getenv("JUDGE0_TOKEN")
	cfg.Judge0Timeout = parseDuration("JUDGE0_TIMEOUT", "30s")

	cfg.LabsRuntime = getEnvDefault("LABS_RUNTIME", "docker")
	cfg.LabsK8sNamespace = getEnvDefault("LABS_K8S_NAMESPACE", "mindforge-labs")
	cfg.LabsWarmPoolGlobalMax = getEnvInt("LABS_WARM_POOL_GLOBAL_MAX", 20)

	cfg.MinioEndpoint = getEnvDefault("MINIO_ENDPOINT", "localhost:9000")
	cfg.MinioAccessKey = os.Getenv("MINIO_ACCESS_KEY")
	cfg.MinioSecretKey = os.Getenv("MINIO_SECRET_KEY")
	cfg.MinioBucket = getEnvDefault("MINIO_BUCKET", "mindforge")
	cfg.MinioUseSSL = os.Getenv("MINIO_USE_SSL") == "true"
	cfg.MinioPublicEndpoint = getEnvDefault("MINIO_PUBLIC_ENDPOINT", cfg.MinioEndpoint)
	if v := os.Getenv("MINIO_PUBLIC_USE_SSL"); v != "" {
		cfg.MinioPublicUseSSL = v == "true"
	} else {
		cfg.MinioPublicUseSSL = cfg.MinioUseSSL
	}

	cfg.LLMProvider = getEnvDefault("LLM_PROVIDER", "disabled")
	cfg.LLMAPIKey = os.Getenv("LLM_API_KEY")
	cfg.LLMModel = getEnvDefault("LLM_MODEL", "claude-sonnet-4-6")
	cfg.LLMBaseURL = os.Getenv("LLM_BASE_URL")
	cfg.LLMTimeout = parseDuration("LLM_TIMEOUT", "30s")

	if cfg.LLMProvider != "disabled" && cfg.LLMAPIKey == "" {
		slog.Error("LLM_API_KEY is required when LLM_PROVIDER is not 'disabled'")
		os.Exit(1)
	}

	cfg.EvalWorkerCount = getEnvInt("EVAL_WORKER_COUNT", 3)
	cfg.EvalMaxRetries = getEnvInt("EVAL_MAX_RETRIES", 3)
	cfg.EvalJobTimeout = parseDuration("EVAL_JOB_TIMEOUT", "8m")
	cfg.EvalStuckAfter = parseDuration("EVAL_STUCK_AFTER", "10m")

	cfg.WorkerPoolSize = getEnvInt("WORKER_POOL_SIZE", 10)
	cfg.WorkerHeartbeatInterval = parseDuration("WORKER_HEARTBEAT_INTERVAL", "15s")
	cfg.WorkerDrainTimeout = parseDuration("WORKER_DRAIN_TIMEOUT", "30s")
	cfg.OrphanReaperInterval = parseDuration("ORPHAN_REAPER_INTERVAL", "30s")
	cfg.OrphanThreshold = parseDuration("ORPHAN_THRESHOLD", "60s")
	cfg.SchedulerLeaderTTL = parseDuration("SCHEDULER_LEADER_TTL", "30s")
	cfg.SchedulerLeaderRenew = parseDuration("SCHEDULER_LEADER_RENEW", "10s")

	cfg.CalendarReminderLeadMinutes = getEnvInt("CALENDAR_REMINDER_LEAD_MINUTES", 30)

	return cfg
}

// IsProd returns true when ENV=production.
func (c *Config) IsProd() bool {
	return c.Env == "production"
}

// ─── helpers ──────────────────────────────────────────────────────────────────

func getEnvDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func requireNonEmpty(key, value string) {
	if value == "" {
		slog.Error("required env var is not set", "key", key)
		os.Exit(1)
	}
}

func requireSecret(key, value string) {
	if value == "" {
		slog.Error("required secret env var is not set", "key", key)
		os.Exit(1)
	}
	if strings.HasPrefix(strings.ToLower(value), "change_me") {
		slog.Error("secret env var still has placeholder value — replace before running", "key", key)
		os.Exit(1)
	}
	if len(value) < 32 {
		slog.Error(fmt.Sprintf("secret env var must be at least 32 bytes (got %d)", len(value)), "key", key)
		os.Exit(1)
	}
}

func parseDuration(key, defaultVal string) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		raw = defaultVal
	}
	d, err := time.ParseDuration(raw)
	if err != nil {
		slog.Error("invalid duration env var", "key", key, "value", raw, "error", err)
		os.Exit(1)
	}
	return d
}

func getEnvInt(key string, fallback int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		slog.Error("invalid int env var", "key", key, "value", raw, "error", err)
		os.Exit(1)
	}
	return v
}

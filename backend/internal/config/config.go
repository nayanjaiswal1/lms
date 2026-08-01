package config

import (
	"fmt"
	"log/slog"
	"net"
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

	// TrustedProxyCIDRs lists the networks whose X-Forwarded-For / X-Real-IP
	// headers may be believed. Any other peer's forwarding headers are ignored
	// and RemoteAddr is used instead — otherwise a client could mint an
	// unlimited number of rate-limit buckets just by varying the header.
	TrustedProxyCIDRs []string

	// Database / Redis
	DatabaseURL string
	RedisURL    string

	// Secrets — enforced: non-empty, no "change_me" prefix, >= 32 bytes
	JWTSecret     string
	CookieSecret  string
	EncryptionKey string

	// Password policy. The breach check is a k-anonymity lookup against the
	// Pwned Passwords range API (see auth.checkBreachCorpus) — the password
	// never leaves the process. It fails open, so disabling it only removes a
	// strengthening layer; it is not load-bearing.
	PasswordBreachCheckEnabled bool
	PasswordBreachAPIURL       string
	PasswordBreachTimeout      time.Duration

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

	// MCPPublicURL is the address external MCP clients (Claude, ChatGPT) use to
	// reach this server's OAuth/MCP endpoints — defaults to BackendURL, but can
	// be overridden independently (e.g. a tunnel URL while developing locally)
	// without disturbing BackendURL, which also builds the Google/GitHub OAuth
	// callback URLs already registered exactly with those providers.
	MCPPublicURL string

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

	// LabsImageProfiles maps a lab environment image to the name of the
	// ImageProfile (labs.ImageProfile) it should be classified as — parsed
	// from LABS_IMAGE_PROFILES, a comma-separated "image:profileName" list
	// (e.g. "mindforge/lab-docker:27:nested-docker,mindforge/lab-k8s:1.31:
	// nested-docker" — the image itself may contain its own ":" tag; only
	// the LAST colon in each entry separates the profile name). Unset/empty
	// means no image is classified: every lab runs with the platform's
	// normal --cap-drop ALL, no-new-privileges, no-added-capabilities
	// container; nothing about existing labs changes. Profile names are
	// resolved against a small in-code catalog (main.go) when the runtimes
	// are constructed — an unknown name is a fatal startup error there. Even
	// for a classified image, an elevated profile (e.g. "nested-docker")
	// only takes effect for an org whose lab_org_config.allowed_images
	// explicitly includes that image (see labs.Service.StartSession) —
	// operator config and org-plan gating both have to agree. See
	// docs/labs.md "Nested Docker labs" before mapping any image to the
	// "nested-docker" profile on a host that also runs Postgres/Redis/MinIO/
	// the backend (which already holds docker.sock) — a nested-Docker
	// container must be treated as potentially host-root and belongs on an
	// isolated lab host/node pool.
	LabsImageProfiles map[string]string
	// LabsNestedDockerRuntime, when set to "sysbox-runc", switches the Docker
	// runtime's nested-image containers to `--runtime sysbox-runc` (no added
	// capabilities at all) instead of the rootless-dind capability set. Only
	// takes effect if the host actually has sysbox-runc installed. Empty =
	// rootless-dind flags (the default, host-independent option).
	LabsNestedDockerRuntime string
	// LabsNestedDockerRuntimeClass sets the Kubernetes RuntimeClassName
	// (e.g. "sysbox-runc" or "kata-containers") for nested-image Pods. The
	// Kubernetes runtime has no equivalent of Docker's --cap-add flags, so a
	// nested-image lab on the kubernetes runtime REQUIRES this to be set —
	// KubernetesContainerService.startPod fails the session loudly rather
	// than approximate elevated capabilities on a shared node pool with no
	// RuntimeClass isolation.
	LabsNestedDockerRuntimeClass string

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

	// Payments (course purchases). Each gateway is independently optional —
	// payments.Registry.FromConfig registers only the ones with a secret
	// key set, falling back to payments.StubProvider in non-production when
	// neither is configured. A gateway's webhook secret is required the
	// moment its secret key is set (enforced below) since a checkout that
	// can charge but never confirm is worse than one that's simply absent.
	StripeSecretKey       string
	StripePublishableKey  string
	StripeWebhookSecret   string
	RazorpayKeyID         string
	RazorpayKeySecret     string
	RazorpayWebhookSecret string
	// PaymentsDefaultProvider selects which registered provider StartCheckout
	// uses when a request doesn't name one explicitly. Empty = whichever
	// provider happens to be registered first (fine when only one is
	// configured; set explicitly once both are).
	PaymentsDefaultProvider string
	// PaymentsCurrency is the single platform currency course prices are
	// charged in — course_purchases carries a currency column per row, but
	// nothing today lets a course price a currency other than this.
	PaymentsCurrency string
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

	// ENV is whitelisted rather than free-form. Every production safeguard —
	// the Secure cookie flag, sending real email instead of logging tokens,
	// suppressing account-enumeration detail — keys off IsProd(), so a typo
	// ("prod", "Production") silently ran the server in development mode with
	// verification and reset tokens exposed. Fail at startup instead.
	requireEnum("ENV", cfg.Env, "development", "staging", "production")

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

	cfg.PasswordBreachCheckEnabled = getEnvBool("PASSWORD_BREACH_CHECK_ENABLED", true)
	cfg.PasswordBreachAPIURL = getEnvDefault("PASSWORD_BREACH_API_URL", "https://api.pwnedpasswords.com/range/")
	cfg.PasswordBreachTimeout = parseDuration("PASSWORD_BREACH_TIMEOUT", "3s")

	// Parse rate limit config
	cfg.AuthRateLimitMax = getEnvInt("AUTH_RATE_LIMIT_MAX", 10)
	cfg.AuthRateLimitWindow = parseDuration("AUTH_RATE_LIMIT_WINDOW", "1m")

	// Defaults to the RFC 1918 / loopback ranges, which covers the normal
	// deployment where the Next.js server and an ingress proxy share a private
	// network with this service. Set explicitly when the proxy is elsewhere.
	cfg.TrustedProxyCIDRs = getEnvCIDRs("TRUSTED_PROXY_CIDRS",
		"127.0.0.0/8", "::1/128", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")

	// Code execution (optional — coding grading degrades gracefully when unset)
	cfg.PistonURL = strings.TrimRight(os.Getenv("PISTON_URL"), "/")
	cfg.PistonTimeout = parseDuration("PISTON_TIMEOUT", "30s")
	cfg.Judge0URL = strings.TrimRight(os.Getenv("JUDGE0_URL"), "/")
	cfg.Judge0Token = os.Getenv("JUDGE0_TOKEN")
	cfg.Judge0Timeout = parseDuration("JUDGE0_TIMEOUT", "30s")

	cfg.LabsRuntime = getEnvDefault("LABS_RUNTIME", "docker")
	cfg.LabsK8sNamespace = getEnvDefault("LABS_K8S_NAMESPACE", "mindforge-labs")
	cfg.LabsWarmPoolGlobalMax = getEnvInt("LABS_WARM_POOL_GLOBAL_MAX", 20)
	cfg.LabsImageProfiles = getEnvImageProfiles("LABS_IMAGE_PROFILES")
	cfg.LabsNestedDockerRuntime = os.Getenv("LABS_NESTED_DOCKER_RUNTIME")
	cfg.LabsNestedDockerRuntimeClass = os.Getenv("LABS_NESTED_DOCKER_RUNTIME_CLASS")

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

	cfg.MCPPublicURL = getEnvDefault("MCP_PUBLIC_URL", cfg.BackendURL)

	cfg.StripeSecretKey = os.Getenv("STRIPE_SECRET_KEY")
	cfg.StripePublishableKey = os.Getenv("STRIPE_PUBLISHABLE_KEY")
	cfg.StripeWebhookSecret = os.Getenv("STRIPE_WEBHOOK_SECRET")
	cfg.RazorpayKeyID = os.Getenv("RAZORPAY_KEY_ID")
	cfg.RazorpayKeySecret = os.Getenv("RAZORPAY_KEY_SECRET")
	cfg.RazorpayWebhookSecret = os.Getenv("RAZORPAY_WEBHOOK_SECRET")
	cfg.PaymentsDefaultProvider = os.Getenv("PAYMENTS_DEFAULT_PROVIDER")
	cfg.PaymentsCurrency = getEnvDefault("PAYMENTS_CURRENCY", "USD")

	// A gateway that can take money but never confirm it is worse than one
	// that's simply not configured — fail startup rather than let that ship.
	if cfg.StripeSecretKey != "" && cfg.StripeWebhookSecret == "" {
		slog.Error("STRIPE_WEBHOOK_SECRET is required when STRIPE_SECRET_KEY is set")
		os.Exit(1)
	}
	if cfg.RazorpayKeyID != "" && cfg.RazorpayWebhookSecret == "" {
		slog.Error("RAZORPAY_WEBHOOK_SECRET is required when RAZORPAY_KEY_ID is set")
		os.Exit(1)
	}

	return cfg
}

// IsProd returns true for every deployed environment — that is, anything other
// than a developer's local stack. It is deliberately written as "not
// development" rather than "== production" so that an environment name this
// build does not recognise fails *closed* (secure cookies on, real email, no
// token echoing). Load() already whitelists ENV, so the only way to reach here
// with an unexpected value is a new environment name added without updating
// requireEnum — and that must not silently disable the production safeguards.
func (c *Config) IsProd() bool {
	return c.Env != "development"
}

// IsLocalDev reports whether this is a local developer stack, where auth tokens
// may be logged to stdout in place of sending mail. Distinct from !IsProd() so
// the two concerns cannot drift apart again.
func (c *Config) IsLocalDev() bool {
	return c.Env == "development"
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

// getEnvCIDRs parses a comma-separated CIDR list, falling back to defaults when
// unset. Fatal on a malformed entry so a typo cannot silently shrink the set of
// proxies whose forwarding headers are trusted.
func getEnvCIDRs(key string, defaults ...string) []string {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return defaults
	}
	var out []string
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if _, _, err := net.ParseCIDR(part); err != nil {
			slog.Error("invalid CIDR in env var", "key", key, "entry", part, "error", err)
			os.Exit(1)
		}
		out = append(out, part)
	}
	return out
}

func getEnvBool(key string, fallback bool) bool {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		slog.Error("invalid bool env var", "key", key, "value", raw, "error", err)
		os.Exit(1)
	}
	return v
}

func requireEnum(key, value string, allowed ...string) {
	for _, a := range allowed {
		if value == a {
			return
		}
	}
	slog.Error("env var has an unrecognised value",
		"key", key, "value", value, "allowed", strings.Join(allowed, ", "))
	os.Exit(1)
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

// getEnvImageProfiles parses a comma-separated "image:profileName" list
// (LABS_IMAGE_PROFILES) into image -> profile name. Each entry is split on
// its LAST colon, not the first, since the image itself commonly contains
// its own ":" tag (e.g. "mindforge/lab-docker:27:nested-docker" splits into
// image "mindforge/lab-docker:27" and profile name "nested-docker"). Unset
// or empty returns nil — callers that check len(...) > 0 to gate a feature
// behave identically either way, but nil more honestly represents "not
// configured". Fatal on a malformed entry (no colon, or a colon at either
// edge) so a typo'd env var fails loudly at startup instead of silently
// leaving an image unclassified.
func getEnvImageProfiles(key string) map[string]string {
	raw := os.Getenv(key)
	if raw == "" {
		return nil
	}
	out := make(map[string]string)
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		i := strings.LastIndex(part, ":")
		if i <= 0 || i == len(part)-1 {
			slog.Error("invalid entry in env var — expected image:profileName", "key", key, "entry", part)
			os.Exit(1)
		}
		out[part[:i]] = part[i+1:]
	}
	return out
}

package api

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/jobs"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/messaging"
	"github.com/mindforge/backend/internal/onboarding"
	"github.com/mindforge/backend/internal/orgs"
	"github.com/mindforge/backend/internal/practice"
	"github.com/mindforge/backend/internal/profile"
	"github.com/mindforge/backend/internal/session"
	"github.com/mindforge/backend/internal/srs"
	"github.com/mindforge/backend/internal/storage"
	"github.com/redis/go-redis/v9"
)

// NewRouter builds and returns the chi Router with all middleware and routes wired.
func NewRouter(cfg *config.Config, pool *pgxpool.Pool, cache *session.Cache, rdb *redis.Client, store storage.StorageClient, aiProvider ai.LLMProvider, jobsRegistry *jobs.Registry) http.Handler {
	r := chi.NewRouter()

	// ─── Global middleware ────────────────────────────────────────────────────
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Timeout(30 * time.Second))
	r.Use(corsMiddleware(cfg))

	// ─── Health check ─────────────────────────────────────────────────────────
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		httputil.WriteJSON(w, http.StatusOK, "ok")
	})

	// ─── Handlers ─────────────────────────────────────────────────────────────
	authHandler := auth.NewHandler(cfg, pool, cache)
	onboardingHandler := onboarding.NewHandler(pool)
	assessmentHandler := assessment.New(pool, cfg, jobsRegistry)
	profileHandler := profile.New(pool, cfg, store)
	coursesRouter := courses.New(pool, cfg, store, aiProvider)
	messagingRouter := messaging.New(pool)
	practiceRouter := practice.New(pool, aiProvider)
	orgsHandler := orgs.NewHandler(cfg, pool)
	srsRouter := srs.New(pool)
	authzHandler := authz.New(pool, rdb)

	// Public auth routes — no auth, no CSRF. Rate-limited per client IP to blunt
	// credential stuffing, token brute force, and email-trigger abuse.
	r.Route("/api/auth", func(r chi.Router) {
		r.Use(apimiddleware.RateLimit(rdb, cfg.AuthRateLimitMax, cfg.AuthRateLimitWindow))

		r.Post("/register", authHandler.HandleRegister)
		r.Post("/login", authHandler.HandleLogin)
		r.Post("/refresh", authHandler.HandleRefresh)
		r.Post("/logout", authHandler.HandleLogout)
		r.Post("/verify-email", authHandler.HandleVerifyEmail)
		r.Post("/resend-verification", authHandler.HandleResendVerification)
		r.Post("/forgot-password", authHandler.HandleForgotPassword)
		r.Post("/reset-password", authHandler.HandleResetPassword)

		// CSRF token endpoint — issues a token for unauthenticated page loads
		r.Get("/csrf-token", authHandler.HandleCSRFToken)

		// Social / OAuth — browser-redirect flow, no JSON body, no CSRF needed
		r.Get("/google", authHandler.HandleOAuthRedirect("google"))
		r.Get("/google/callback", authHandler.HandleOAuthCallback("google"))
		r.Get("/github", authHandler.HandleOAuthRedirect("github"))
		r.Get("/github/callback", authHandler.HandleOAuthCallback("github"))
		r.Post("/social/exchange", authHandler.HandleSocialExchange)
	})

	// Public invitation preview — no auth required
	assessmentHandler.RegisterPublicRoutes(r)

	// Public profile routes — no auth required (public profile pages).
	profileHandler.RegisterPublicRoutes(r)

	// Protected routes — RequireAuth + RequireCSRF on all mutations
	requireAuth := apimiddleware.RequireAuth(cfg, cache)

	r.Group(func(r chi.Router) {
		r.Use(requireAuth)
		r.Use(apimiddleware.RequireCSRF(cfg))

		r.Get("/api/auth/me", authHandler.HandleMe)
		r.Post("/api/auth/logout-all", authHandler.HandleLogoutAll)

		r.Post("/api/user/onboarding", onboardingHandler.HandleSave)
		r.Get("/api/user/onboarding", onboardingHandler.HandleGet)

		// Assessment & Evaluation Management System — question bank, assessments,
		// batches, assignment, attempts, anti-cheat, and analytics. Role guards are
		// applied per sub-group inside RegisterRoutes.
		assessmentHandler.RegisterRoutes(r)

		// Profile — authenticated routes (me, skills, avatar, admin user lookup).
		profileHandler.RegisterRoutes(r)

		// Courses — course CRUD, sections, modules, enrollment, progress, AI outline.
		coursesRouter.RegisterRoutes(r)

		// Messaging — batch messages, reactions, FAQ management.
		messagingRouter.RegisterRoutes(r)

		// Practice — AI interview prep sessions and answer review.
		practiceRouter.RegisterRoutes(r)

		// Orgs — multi-tenant org management, members, invites, domains, onboarding.
		orgsHandler.RegisterRoutes(r)

		// SRS — spaced-repetition cards, daily review queue, SM-2 scheduling.
		srsRouter.RegisterRoutes(r)

		// RBAC — permission catalogue, role CRUD, user-role assignment, audit log.
		authzHandler.RegisterRoutes(r)

		// Job Management System — org job list/cancel/retry, admin stats, worker view.
		jobsHandler := jobs.NewHTTPHandler(pool, rdb, cfg, jobsRegistry)
		jobsHandler.RegisterRoutes(r)
	})

	return r
}

// corsMiddleware sets CORS headers allowing the configured FRONTEND_URL origin
// with credentials.  X-CSRF-Token is explicitly listed so browser JS can send it.
func corsMiddleware(cfg *config.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin == cfg.FrontendURL {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-CSRF-Token")
				w.Header().Set("Vary", "Origin")
			}
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

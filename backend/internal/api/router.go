package api

import (
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/experience"
	"github.com/mindforge/backend/internal/features"
	"github.com/mindforge/backend/internal/feedback"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/highlights"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/interviewexp"
	"github.com/mindforge/backend/internal/interviewprep"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/mcpconnect"
	"github.com/mindforge/backend/internal/mentoring"
	"github.com/mindforge/backend/internal/messaging"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/mistakes"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/onboarding"
	"github.com/mindforge/backend/internal/orgs"
	"github.com/mindforge/backend/internal/payments"
	"github.com/mindforge/backend/internal/practice"
	"github.com/mindforge/backend/internal/profile"
	"github.com/mindforge/backend/internal/revisionplan"
	"github.com/mindforge/backend/internal/rewards"
	"github.com/mindforge/backend/internal/roadmap"
	"github.com/mindforge/backend/internal/secrets"
	"github.com/mindforge/backend/internal/session"
	"github.com/mindforge/backend/internal/sheets"
	"github.com/mindforge/backend/internal/srs"
	"github.com/mindforge/backend/internal/storage"
	"github.com/mindforge/backend/internal/systemdesign"
	"github.com/mindforge/backend/internal/whatnow"
	"github.com/redis/go-redis/v9"
)

// NewRouter builds and returns the chi Router with all middleware and routes wired.
func NewRouter(cfg *config.Config, pool *pgxpool.Pool, cache *session.Cache, rdb *redis.Client, store storage.StorageClient, aiProvider ai.LLMProvider, jobsRegistry *jobs.Registry, rewardsSvc *rewards.Service, labsRuntime labs.ContainerRuntime) http.Handler {
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
	authHandler := auth.NewHandler(cfg, pool, cache, rdb)
	onboardingHandler := onboarding.NewHandler(pool)
	// Built early (before certificatesRouter below) purely so the public
	// profile can list a learner's certificates — same *pool-backed Repo
	// shape certificatesRouter constructs internally for its own routes.
	profileCertsRepo := certificates.NewRepo(pool)
	profileHandler := profile.New(pool, cfg, store, profileCertsRepo)

	// Courses service is built explicitly (rather than via courses.New) so its
	// *courses.Service can be shared with the assessment and labs handlers below —
	// they call it to complete a course module when a lab/assessment finishes,
	// which is the only path allowed to mark those module types "completed".
	coursesRepo := courses.NewRepo(pool)
	coursesSvc := courses.NewService(coursesRepo, store, aiProvider, cfg, rewardsSvc)

	// authz is built before mentoring so its *authz.Service can back the
	// mentoring.assign_tickets / mentoring.manage_reports permission guards.
	authzHandler := authz.New(pool, rdb)

	// mentoring is built before the courses handler so mentoringRouter.Service
	// (satisfying courses.MentorTicketOpener) can be injected into it. mentoring
	// only needs *courses.Repo (for CreateEnrollmentTx), not the courses
	// handler, so there is no import cycle: mentoring -> courses, courses ->
	// (local interface only, no mentoring import).
	mentoringRouter := mentoring.New(pool, payments.NewStubProvider(), coursesRepo, authzHandler.Service())

	coursesRouter := courses.NewHandler(coursesRepo, coursesSvc, mentoringRouter.Service)

	assessmentHandler := assessment.New(pool, cfg, jobsRegistry, rewardsSvc, coursesSvc, store, labsRuntime)
	rewardsHandler := rewards.New(pool, rdb)
	messagingRouter := messaging.New(pool)
	feedbackRouter := feedback.New(pool, mentoringRouter.Service)
	experienceRouter := experience.New(pool)
	practiceRouter := practice.New(pool, aiProvider)
	interviewPrepRouter := interviewprep.New(pool, cfg, aiProvider, practiceRouter.Service)
	orgsHandler := orgs.NewHandler(cfg, pool, jobsRegistry)
	srsRouter := srs.New(pool)
	// A second *srs.Repo wrapping the same pool (NewRepo holds no state of its
	// own beyond the pool reference) so mistakes.Service and mcpconnect can
	// reach GetDueCardsBySource/ReviewCard without srsRouter needing to expose
	// its unexported repo field.
	srsRepo := srs.NewRepo(pool)
	mistakesRepo := mistakes.NewRepo(pool)
	mistakesSvc := mistakes.NewService(mistakesRepo, pool)
	mistakesRouter := mistakes.NewHandler(mistakesRepo, mistakesSvc)
	sheetsRouter := sheets.New(pool)
	interviewExpRouter := interviewexp.New(pool)
	highlightsRouter := highlights.New(pool, aiProvider)
	systemDesignRouter := systemdesign.New(pool, coursesRepo, aiProvider)
	// mentoringRouter.Service backs both the mentor-manual-issue authorization
	// check (MentorAuthChecker) and the paid-course threshold-auto-issue check
	// (PurchaseChecker) — it already sits above coursesRepo, so no new import
	// cycle is introduced.
	certificatesRouter := certificates.New(pool, coursesRepo, assessment.NewExecutor(cfg), mentoringRouter.Service, mentoringRouter.Service)
	calendarRouter := calendar.New(pool, authzHandler.Service(), cfg)
	whatnowRouter := whatnow.New(pool)
	featuresRouter := features.New(pool)
	roadmapRouter := roadmap.New(pool, jobsRegistry)
	revisionPlanRouter := revisionplan.New(pool, jobsRegistry)

	// AI Connector (MCP) — lets a student connect their own Claude/ChatGPT to
	// their account via OAuth 2.1+PKCE. Built with coursesRepo/coursesSvc (not
	// a fresh *courses.Repo) and interviewPrepRouter.Service so its tools
	// share the exact same enrollment/authorization rules and daily plan
	// rate limit as the student-facing API.
	mcpConnectRouter := mcpconnect.New(cfg, pool, coursesRepo, coursesSvc, calendarRouter.Service, mistakesRepo, mistakesSvc, srsRepo, interviewPrepRouter.Service)

	// Notifications — generic, dependency-free in-app notification domain
	// (Batch 5). Built before gitlabRouter below so its *notifications.Service
	// can be passed into gitlab.New's peer-review/CI-alert notification calls
	// (service_checkpoint.go, service_webhook.go).
	notificationsRouter := notifications.NewRouter(pool, jobsRegistry)

	// GitLab integration — org-level installation (PAT or OAuth service
	// account) plus per-user OAuth+PKCE connections (Batch 1). The vault is
	// built once here and passed to gitlab.New; cmd/server/main.go builds its
	// own separate instance for the token-refresh job the same way it builds
	// a standalone assessment.Handler for the expire-attempts reaper.
	gitlabVault, err := secrets.New(cfg)
	if err != nil {
		panic(fmt.Errorf("api: gitlab secrets vault init failed: %w", err))
	}
	gitlabRouter := gitlab.New(pool, cfg, gitlabVault, jobsRegistry, notificationsRouter.Service)

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

		// Passkey (WebAuthn) login — unauthenticated ceremony, identity is
		// established by the authenticator response itself.
		r.Post("/webauthn/login/begin", authHandler.HandleWebAuthnLoginBegin)
		r.Post("/webauthn/login/finish", authHandler.HandleWebAuthnLoginFinish)
	})

	// Public invitation preview — no auth required
	assessmentHandler.RegisterPublicRoutes(r)

	// Public profile routes — no auth required (public profile pages).
	profileHandler.RegisterPublicRoutes(r)

	// Public calendar routes — invite-accept link and personal ICS feed are
	// both authorized by their own token, not a session cookie.
	calendarRouter.RegisterPublicRoutes(r)

	// Public course catalog — anonymous marketplace listing for the landing page.
	coursesRouter.RegisterPublicRoutes(r)

	// AI Connector (MCP) — discovery, dynamic client registration, the
	// authorize/token endpoints, and /mcp itself. None of these are
	// cookie-authenticated (see RegisterPublicRoutes' own comment).
	mcpConnectRouter.RegisterPublicRoutes(r)

	// GitLab OAuth callback — authenticated via the gitlab_oauth_states row
	// matched by the state param, not a session cookie, since PKCE's
	// verifier must survive a cross-site top-level redirect back from the
	// GitLab instance.
	gitlabRouter.RegisterPublicRoutes(r)

	// Public certificate verification — no auth, proof of access is the
	// cert_uuid itself.
	certificatesRouter.RegisterPublicRoutes(r)

	// Protected routes — RequireAuth + RequireCSRF on all mutations
	requireAuth := apimiddleware.RequireAuth(cfg, cache)

	r.Group(func(r chi.Router) {
		r.Use(requireAuth)
		r.Use(apimiddleware.RequireCSRF(cfg))

		r.Get("/api/auth/me", authHandler.HandleMe)
		r.Post("/api/auth/logout-all", authHandler.HandleLogoutAll)

		// Passkey (WebAuthn) enrollment/management — the account must already
		// exist (created via password or OAuth) before a passkey can be added.
		r.Post("/api/auth/webauthn/register/begin", authHandler.HandleWebAuthnRegisterBegin)
		r.Post("/api/auth/webauthn/register/finish", authHandler.HandleWebAuthnRegisterFinish)
		r.Get("/api/auth/webauthn/credentials", authHandler.HandleWebAuthnCredentialsList)
		r.Patch("/api/auth/webauthn/credentials/{id}", authHandler.HandleWebAuthnCredentialRename)
		r.Delete("/api/auth/webauthn/credentials/{id}", authHandler.HandleWebAuthnCredentialDelete)

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

		// Feedback — post-completion ratings/comments for courses, assessments, labs, mentors.
		feedbackRouter.RegisterRoutes(r)

		// Experience reports — post-assessment "did anything go wrong" issue/complaint capture.
		experienceRouter.RegisterRoutes(r)

		// Mentoring — mentor tickets (claim/assign/close), mentor directory, mentor reports.
		mentoringRouter.RegisterRoutes(r)

		// Practice — AI interview prep sessions and answer review.
		practiceRouter.RegisterRoutes(r)

		// Interview Prep — paste a job title/JD, get a scored multi-round mock
		// test (conceptual round via practice, coding round self-contained).
		interviewPrepRouter.RegisterRoutes(r)

		// Orgs — multi-tenant org management, members, invites, domains, onboarding.
		orgsHandler.RegisterRoutes(r)

		// SRS — spaced-repetition cards, daily review queue, SM-2 scheduling.
		srsRouter.RegisterRoutes(r)

		// Mistakes — the Mistake & Progress Ledger: timestamped mistake events,
		// per-category trend summary, resolve. Spaced revision for these rides
		// the SRS engine above (source_type="mistake"), not a separate queue.
		mistakesRouter.RegisterRoutes(r)

		// Sheets — curated problem-list tracker: create/start a sheet, track
		// per-problem progress (todo/done/revisit).
		sheetsRouter.RegisterRoutes(r)

		// Interview Experiences — crowd-sourced company/position-tagged Q&A
		// board: multi-user continuation, nested discussion, voting. Unlike
		// every other domain, reads are platform-wide, not org-scoped.
		interviewExpRouter.RegisterRoutes(r, authzHandler.Service())

		// What Now? — deterministic task-triage: capture, pick-now scoring,
		// plan-today, breakdown, stuck resolution, weekly recap.
		whatnowRouter.RegisterRoutes(r)

		// Feature flags — resolves org-enabled features + per-user entitlements
		// for the current session (frontend's <AccessGate>/<FeatureFlagProvider>).
		featuresRouter.RegisterRoutes(r)

		// RBAC — permission catalogue, role CRUD, user-role assignment, audit log.
		authzHandler.RegisterRoutes(r)

		// Job Management System — org job list/cancel/retry, admin stats, worker view.
		jobsHandler := jobs.NewHTTPHandler(pool, rdb, cfg, jobsRegistry)
		jobsHandler.RegisterRoutes(r)

		// Rewards — XP, badges, leaderboard.
		rewardsHandler.RegisterRoutes(r)

		// Highlights — in-content text selection, AI explain, revision saves, analytics.
		highlightsRouter.RegisterRoutes(r)

		// System Design — per-question Excalidraw whiteboard attempts, AI
		// clarifying-question chat, and AI feedback on course modules of
		// type='system_design'.
		systemDesignRouter.RegisterRoutes(r, authzHandler.Service())

		// Certificates — course final test (MCQ + coding), grading, and
		// certificate issuance/verification.
		certificatesRouter.RegisterRoutes(r, authzHandler.Service())

		// Labs — interactive sandboxed lab environments (terminal, code, guided, playground).
		// gitlabRouter.Service() is labs.New's Batch 3 RepoPreparer slot — built
		// above (before this call, same reasoning as the router.go's own
		// pre-existing gitlabRouter-before-labsHandler ordering) so a fresh
		// terminal auto-clones its team's repo when GitLab is configured; it's
		// never nil here since gitlab.Service always exists once an org has an
		// installation; it's still a nil-safe optional dependency to labs
		// itself (empty script -> skip) when no installation/connection exists.
		labsHandler := labs.New(pool, rdb, cfg.JWTSecret, "mindforge-labproxy", cfg.PistonURL, cfg.PistonTimeout, coursesSvc, labsRuntime, gitlabRouter.Service())
		labsHandler.RegisterRoutes(r)
		labsHandler.RegisterAdminRoutes(r, authzHandler.Service())

		// Calendar — events, RSVPs, recurring series, external invites, personal ICS feed.
		calendarRouter.RegisterRoutes(r)

		// Roadmap — AI personalized learning paths: state a goal, get an AI
		// generated phase -> milestone -> module roadmap linked into the real
		// course/lab/question catalog where possible.
		roadmapRouter.RegisterRoutes(r)

		// Revision plan — AI-ranked weak topics built from a learner's actual
		// knowledge-check accuracy and lesson reflections in a completed course.
		revisionPlanRouter.RegisterRoutes(r)

		// AI Connector (MCP) — consent screen (details/approve/deny) and the
		// settings-page connection list/revoke, all called by our own frontend.
		mcpConnectRouter.RegisterRoutes(r)

		// GitLab integration — installation management (admin-only) and
		// per-user connect/status/disconnect (any org member).
		gitlabRouter.RegisterRoutes(r)

		// Notifications — generic in-app notifications: list, unread count,
		// mark read/read-all. Any authenticated member, row-scoped to their
		// own notifications.
		notificationsRouter.RegisterRoutes(r)
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

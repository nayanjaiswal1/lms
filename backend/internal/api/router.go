package api

import (
	"fmt"
	"net/http"
	"slices"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/activity"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/coupons"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/diary"
	"github.com/mindforge/backend/internal/entitlements"
	"github.com/mindforge/backend/internal/features"
	"github.com/mindforge/backend/internal/feedback"
	"github.com/mindforge/backend/internal/focuswall"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/habit"
	"github.com/mindforge/backend/internal/highlights"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/interviewexp"
	"github.com/mindforge/backend/internal/interviewprep"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/journal"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/learnhub"
	"github.com/mindforge/backend/internal/legal"
	"github.com/mindforge/backend/internal/mcpconnect"
	"github.com/mindforge/backend/internal/mentoring"
	"github.com/mindforge/backend/internal/messaging"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
	"github.com/mindforge/backend/internal/mistakes"
	"github.com/mindforge/backend/internal/moderation"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/onboarding"
	"github.com/mindforge/backend/internal/orgs"
	"github.com/mindforge/backend/internal/payments"
	"github.com/mindforge/backend/internal/practice"
	"github.com/mindforge/backend/internal/pricing"
	"github.com/mindforge/backend/internal/privacy"
	"github.com/mindforge/backend/internal/profile"
	"github.com/mindforge/backend/internal/project"
	"github.com/mindforge/backend/internal/projectmarket"
	"github.com/mindforge/backend/internal/revisionplan"
	"github.com/mindforge/backend/internal/rewards"
	"github.com/mindforge/backend/internal/roadmap"
	"github.com/mindforge/backend/internal/secrets"
	"github.com/mindforge/backend/internal/session"
	"github.com/mindforge/backend/internal/sessions"
	"github.com/mindforge/backend/internal/sheets"
	"github.com/mindforge/backend/internal/srs"
	"github.com/mindforge/backend/internal/storage"
	"github.com/mindforge/backend/internal/systemdesign"
	"github.com/mindforge/backend/internal/tickets"
	"github.com/mindforge/backend/internal/useroverview"
	"github.com/mindforge/backend/internal/whatnow"
	"github.com/mindforge/backend/internal/wiki"
	"github.com/redis/go-redis/v9"
)

// NewRouter builds and returns the chi Router with all middleware and routes wired.
func NewRouter(cfg *config.Config, pool *pgxpool.Pool, cache *session.Cache, rdb *redis.Client, store storage.StorageClient, aiProvider ai.LLMProvider, jobsRegistry *jobs.Registry, rewardsSvc *rewards.Service, labsRuntime labs.ContainerRuntime) http.Handler {
	r := chi.NewRouter()

	// ─── Global middleware ────────────────────────────────────────────────────
	r.Use(chimiddleware.Recoverer)
	// Not chimiddleware.RealIP: that one believes X-Forwarded-For from any
	// caller, which lets a client directly reaching this service forge a fresh
	// rate-limit bucket per request. Ours honours forwarding headers only from
	// TRUSTED_PROXY_CIDRS.
	r.Use(apimiddleware.RealIP(cfg))
	r.Use(chimiddleware.Logger)
	// No global chimiddleware.Timeout: it force-writes a 504 the instant its
	// deadline passes (see its own doc comment), which cut off
	// labs.Service.WaitForReadiness's SSE stream every 30s even while the lab
	// was still legitimately provisioning (nested-Docker labs need up to
	// ProvisionTimeoutSeconds=90s). Slow operations already bound themselves
	// with their own context timeout (LLMTimeout, EvalJobTimeout, this
	// package's per-request deadlines) — a blanket HTTP-layer timeout is
	// redundant for those and actively wrong for the one long-lived endpoint.
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
	authzHandler := authz.New(pool, rdb, cache)

	// coupons is a leaf package (no dependency on courses or mentoring) —
	// built before both so its *coupons.Service can be handed to each
	// directly, no interface indirection needed on this edge.
	couponsRouter := coupons.New(pool)

	// paymentProviders registers whichever gateways have credentials
	// configured (Stripe/Razorpay), falling back to the local stub outside
	// production — see payments.FromConfig.
	paymentProviders := payments.FromConfig(cfg)

	// calendar is built before sessions (below) because a booked mentor
	// session is projected onto the org calendar through this exact
	// *calendar.Service instance — same sharing rule its own Router doc
	// comment describes for mcpconnect.
	calendarRouter := calendar.New(pool, authzHandler.Service(), cfg)

	// sessions is built before mentoring so sessionsRouter.Service (satisfying
	// mentoring.PackConfirmer) can be injected into it: mentoring owns the one
	// payment-webhook endpoint and fans a delivery out to whichever product it
	// belongs to. The dependency is one-way — sessions imports calendar,
	// payments, and authz, never mentoring.
	sessionsRouter := sessions.New(pool, calendarRouter.Service, paymentProviders, cfg)

	// tickets owns the shared conversations/messages CRUD backing both
	// general support tickets (kind=support) and mentor-assignment tickets
	// (kind=mentorship) — built before mentoring so mentoringRouter can be
	// handed its repo and build mentorship-ticket creation on top of it
	// instead of duplicating the CRUD.
	ticketsRouter := tickets.New(pool, authzHandler.Service(), cfg)

	// mentoring is built before the courses handler so mentoringRouter.Service
	// (satisfying courses.CoursePurchaser) can be injected into it. mentoring
	// only needs *courses.Repo (for CreateEnrollmentTx), not the courses
	// handler, so there is no import cycle: mentoring -> courses, courses ->
	// (local interface only, no mentoring import).
	mentoringRouter := mentoring.New(pool, ticketsRouter.Repo, paymentProviders, couponsRouter.Service, coursesRepo, sessionsRouter.Service, authzHandler.Service(), cfg)

	coursesRouter := courses.NewHandler(coursesRepo, coursesSvc, mentoringRouter.Service, couponsRouter.Service, rdb, cfg, authzHandler.Service())

	assessmentHandler := assessment.New(pool, cfg, jobsRegistry, rewardsSvc, coursesSvc, store, labsRuntime)
	rewardsHandler := rewards.New(pool, rdb)
	messagingRouter := messaging.New(pool)
	feedbackRouter := feedback.New(pool, mentoringRouter.Service)
	practiceRouter := practice.New(pool, aiProvider)
	interviewPrepRouter := interviewprep.New(pool, cfg, aiProvider, practiceRouter.Service)

	// Secrets vault — created once and shared by both gitlab (credentials encryption)
	// and orgs (OIDC client secret encryption). cmd/server/main.go builds its own
	// separate instance for background jobs the same way.
	secretsVault, err := secrets.New(cfg)
	if err != nil {
		panic(fmt.Errorf("api: secrets vault init failed: %w", err))
	}

	orgsHandler := orgs.NewHandler(cfg, pool, cache, secretsVault, jobsRegistry)
	srsRouter := srs.New(pool)
	// A second *srs.Repo wrapping the same pool (NewRepo holds no state of its
	// own beyond the pool reference) so mistakes.Service and mcpconnect can
	// reach GetDueCardsBySource/ReviewCard without srsRouter needing to expose
	// its unexported repo field.
	srsRepo := srs.NewRepo(pool)
	mistakesRepo := mistakes.NewRepo(pool)
	mistakesSvc := mistakes.NewService(mistakesRepo, pool, jobsRegistry)
	mistakesRouter := mistakes.NewHandler(mistakesRepo, mistakesSvc)
	sheetsRouter := sheets.New(pool)
	journalRouter := journal.New(pool, aiProvider)
	// Digital Diary — one free-form prose entry per day; AI analysis writes
	// detected habit/task mentions into the existing habit/whatnow domains
	// rather than owning duplicate data (see internal/diary/service.go).
	diaryRouter := diary.New(pool, aiProvider)
	interviewExpRouter := interviewexp.New(pool)
	// Wiki — shares coursesRepo (read-only) with systemDesignRouter/wiki.New's
	// other callers, to validate course_id on space create and check
	// enrollment on course-linked spaces without a second query path.
	wikiRouter := wiki.New(pool, coursesRepo)
	highlightsRouter := highlights.New(pool, aiProvider)
	focusWallRouter := focuswall.New(pool)
	habitRouter := habit.New(pool)
	systemDesignRouter := systemdesign.New(pool, coursesRepo, aiProvider)
	// mentoringRouter.Service backs both the mentor-manual-issue authorization
	// check (MentorAuthChecker) and the paid-course threshold-auto-issue check
	// (PurchaseChecker) — it already sits above coursesRepo, so no new import
	// cycle is introduced.
	certificatesRouter := certificates.New(pool, coursesRepo, assessment.NewExecutor(cfg), mentoringRouter.Service, mentoringRouter.Service)
	whatnowRouter := whatnow.New(pool)
	projectRouter := project.New(pool)
	activityRouter := activity.New(pool)
	learnHubHandler := learnhub.New(pool)
	entitlementsRouter := entitlements.New(pool, cfg.DefaultOrgID)
	featuresRouter := features.New(pool, entitlementsRouter.Service)
	pricingRouter := pricing.New(pool)
	roadmapRouter := roadmap.New(pool, jobsRegistry)
	revisionPlanRouter := revisionplan.New(pool, jobsRegistry)

	// Legal — Terms/Privacy consent tracking, no permission gating (every
	// authenticated user manages only their own acceptance record).
	legalRouter := legal.New(pool)

	// Moderation — content-report queue, gated on content.moderate for the
	// staff side (authzHandler already built above).
	moderationRouter := moderation.New(pool, authzHandler.Service())

	// Privacy — self-service data export/account deletion. Constructs its own
	// authz.AdminRepo (stateless over pool) rather than threading authzHandler's
	// private one through, since account deletion calls AdminRepo.SetUserStatus
	// directly (bypassing AdminService's self-action guard — see
	// internal/privacy/service.go).
	privacyRouter := privacy.New(pool, authz.NewAdminRepo(pool))

	// AI Connector (MCP) — lets a student connect their own Claude/ChatGPT to
	// their account via OAuth 2.1+PKCE. Built with coursesRepo/coursesSvc (not
	// a fresh *courses.Repo) and interviewPrepRouter.Service/
	// systemDesignRouter.Service so its tools share the exact same
	// enrollment/authorization rules and daily plan rate limit as the
	// student-facing API.
	mcpConnectRouter := mcpconnect.New(cfg, pool, coursesRepo, coursesSvc, calendarRouter.Service, mistakesRepo, mistakesSvc, srsRepo, interviewPrepRouter.Service, systemDesignRouter.Service)

	// Notifications — generic, dependency-free in-app notification domain
	// (Batch 5). Built before gitlabRouter below so its *notifications.Service
	// can be passed into gitlab.New's peer-review/CI-alert notification calls
	// (service_checkpoint.go, service_webhook.go).
	notificationsRouter := notifications.NewRouter(pool, jobsRegistry)

	// GitLab integration — org-level installation (PAT or OAuth service
	// account) plus per-user OAuth+PKCE connections (Batch 1). Uses the same
	// secrets vault created above for orgs.
	gitlabRouter := gitlab.New(pool, cfg, secretsVault, jobsRegistry, notificationsRouter.Service, aiProvider)

	// Project marketplace — staff post a requirement, students browse the
	// open board and apply, staff reviews and shortlists/selects, AI ranks
	// applicants, and a one-click action turns a selection into a real team
	// (Phase A of docs/project-marketplace.md, now complete). profile.NewRepo
	// is a second, independent *profile.Repo instance over the same pool —
	// cheap (Repo wraps nothing but the pool) and avoids needing profileHandler's
	// internals, matching how gitlabRouter.Service() is shared as a plain
	// accessor rather than a bigger dependency.
	projectmarketRouter := projectmarket.New(pool, profile.NewRepo(pool), aiProvider, jobsRegistry, gitlabRouter.Service(), notificationsRouter.Service)

	// Public auth routes — no auth, no CSRF. Rate-limited per client IP to blunt
	// credential stuffing, token brute force, and email-trigger abuse.
	r.Route("/api/auth", func(r chi.Router) {
		r.Use(apimiddleware.RateLimit(rdb, cfg.AuthRateLimitMax, cfg.AuthRateLimitWindow))

		r.Post("/register", authHandler.HandleRegister)
		r.Post("/login", authHandler.HandleLogin)

		// /refresh and /logout act on an existing session identified purely by
		// cookie, so they are exactly the shape a cross-site request forgery
		// targets — one to force a token rotation, the other to sign the user
		// out. SameSite=Lax already blocks the cross-site POST, but that leaves
		// the whole defence resting on a single cookie attribute; the CSRF token
		// makes it explicit. They stay outside the RequireAuth group because
		// both must work with an access token that has already expired.
		csrf := apimiddleware.RequireCSRF(cfg)
		r.With(csrf).Post("/refresh", authHandler.HandleRefresh)
		r.With(csrf).Post("/logout", authHandler.HandleLogout)

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

	// Public pricing — the / and /org landing pages' pricing sections, editable
	// by a platform admin at /platform/pricing without a redeploy.
	pricingRouter.RegisterPublicRoutes(r)

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

	// Payment gateway webhooks — the gateway itself is the caller,
	// authenticated by its own signature scheme (see mentoring/handler_webhook.go),
	// never a session cookie.
	mentoringRouter.RegisterPublicRoutes(r)

	// Payments config — the currency every *_cents amount is denominated in.
	// Public: the anonymous catalog renders prices before any session exists.
	payments.RegisterPublicRoutes(r, cfg)

	// Public roadmap Discover gallery — anonymous browse of roadmaps their
	// owners marked is_public, same pattern as the public course catalog.
	roadmapRouter.RegisterPublicRoutes(r)

	// GET /api/roadmaps/:id works both signed in and anonymous — an owner's
	// full editable roadmap, or anyone's is_public roadmap read-only, from
	// the same URL (no separate "public" path). See RegisterOptionalAuthRoutes.
	roadmapRouter.RegisterOptionalAuthRoutes(r, apimiddleware.OptionalAuth(cfg, cache))

	// Protected routes — RequireAuth + RequireCSRF on all mutations
	requireAuth := apimiddleware.RequireAuth(cfg, cache, pool)

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

		// Feedback — post-completion ratings/comments for courses, assessments, labs, mentors,
		// plus experience reports (post-activity "did anything go wrong" capture).
		feedbackRouter.RegisterRoutes(r)

		// Tickets — shared support/mentorship ticket CRUD and messaging
		// (/api/tickets*); mount before mentoring's own routes since both
		// build on the same conversations/messages tables.
		ticketsRouter.RegisterRoutes(r)

		// Mentoring — mentor-ticket lifecycle (request/claim/assign/close/
		// change-request), mentor directory, mentor reports.
		mentoringRouter.RegisterRoutes(r)

		// Coupons — admin CRUD, gated by payments.manage_coupons.
		couponsRouter.RegisterRoutes(r, authzHandler.Service())

		// Practice — AI interview prep sessions and answer review.
		practiceRouter.RegisterRoutes(r, authzHandler.Service())

		// Interview Prep — paste a job title/JD, get a scored multi-round mock
		// test (conceptual round via practice, coding round self-contained).
		interviewPrepRouter.RegisterRoutes(r)

		// Orgs — multi-tenant org management, members, invites, domains, onboarding.
		orgsHandler.RegisterRoutes(r, authzHandler.Service())

		// SRS — spaced-repetition cards, daily review queue, SM-2 scheduling.
		srsRouter.RegisterRoutes(r, authzHandler.Service())

		// Mistakes — the Mistake & Progress Ledger: timestamped mistake events,
		// per-category trend summary, resolve. Spaced revision for these rides
		// the SRS engine above (source_type="mistake"), not a separate queue.
		mistakesRouter.RegisterRoutes(r)

		// Sheets — curated problem-list tracker: create/start a sheet, track
		// per-problem progress (todo/done/revisit).
		sheetsRouter.RegisterRoutes(r, authzHandler.Service())

		// Learning Journal — personal day-by-day log of what the user
		// learned, under a free-typed category.
		journalRouter.RegisterRoutes(r, authzHandler.Service())

		// Digital Diary — one free-form "Today" prose entry per day, with
		// AI-detected habit/task mentions and an on-demand Fix English
		// grammar review.
		diaryRouter.RegisterRoutes(r, authzHandler.Service())

		// Interview Experiences — crowd-sourced company/position-tagged Q&A
		// board: multi-user continuation, nested discussion, voting. Unlike
		// every other domain, reads are platform-wide, not org-scoped.
		interviewExpRouter.RegisterRoutes(r, authzHandler.Service())

		// Wiki — spaces, pages, TipTap-editor content, versioning, comments,
		// templates, search. Gated on content.wiki; space delete additionally
		// requires the org admin role.
		wikiRouter.RegisterRoutes(r, authzHandler.Service())

		// What Now? — deterministic task-triage: capture, pick-now scoring,
		// plan-today, breakdown, stuck resolution, weekly recap. Also backs
		// the Linked Task Board (board/links/templates routes).
		whatnowRouter.RegisterRoutes(r)

		// Project — lightweight personal project list, used as a task_links
		// target on the Linked Task Board. Not projectmarket (org marketplace).
		projectRouter.RegisterRoutes(r)

		// Activity — read-only cross-domain timeline (module/course
		// completions, quiz attempts, MCP reflections, sheet problems solved,
		// lab completions, SM-2 card reviews) for the dashboard widget and
		// the /activity page.
		activityRouter.RegisterRoutes(r)

		// Learn hub — one cheap count per hub card (enrollments, roadmap
		// progress, prep plans, pending assessments, saved highlights, due
		// SRS cards, sheet progress, wiki spaces, interview-exp posts),
		// replacing 9 separate full-list fetches the /learn page used to make.
		learnHubHandler.RegisterRoutes(r)

		// Feature flags — resolves org-enabled features + per-user entitlements
		// for the current session (frontend's <AccessGate>/<FeatureFlagProvider>).
		featuresRouter.RegisterRoutes(r)
		// Org admin (owner/admin org role) grants/revokes a feature for one
		// member; platform admin (super_admin) turns a feature on/off for a
		// whole org.
		featuresRouter.RegisterOrgAdminRoutes(r)
		featuresRouter.RegisterPlatformRoutes(r)

		// Entitlements — current account's quota usage (My Plan page), plus
		// the platform admin's plan-limits editor and tier-assignment
		// endpoints. The gate half of plan_limits is consumed inside
		// featuresRouter's Resolve, not exposed as its own read endpoint.
		entitlementsRouter.RegisterRoutes(r)
		entitlementsRouter.RegisterPlatformRoutes(r)

		// Pricing — platform admin (super_admin) edits the marketing pricing
		// tiers shown on the / and /org landing pages.
		pricingRouter.RegisterPlatformRoutes(r)

		// RBAC — permission catalogue, role CRUD, user-role assignment, audit log.
		authzHandler.RegisterRoutes(r)

		// User overview — cross-domain progress data (courses/activity/sheets/
		// mistakes/habits/journal) for the admin user detail page. Reuses the
		// coursesRepo/mistakesRepo already built above and authzHandler's
		// *authz.Service for its permission gate; see internal/useroverview's
		// package doc for why this couldn't live inside internal/authz itself
		// (courses and journal both import authz, so authz importing them back
		// would be a cycle).
		useroverview.New(pool, authzHandler.Service(), coursesRepo, mistakesRepo).RegisterRoutes(r)

		// Job Management System — org job list/cancel/retry, admin stats, worker view.
		jobsHandler := jobs.NewHTTPHandler(pool, rdb, cfg, jobsRegistry)
		jobsHandler.RegisterRoutes(r)

		// Rewards — XP, badges, leaderboard.
		rewardsHandler.RegisterRoutes(r)

		// Highlights — in-content text selection, AI explain, revision saves, analytics.
		highlightsRouter.RegisterRoutes(r)

		// Focus Wall — personal sticky-note corkboard.
		focusWallRouter.RegisterRoutes(r)

		// Habit Tracker — personal daily/weekly/monthly habits and check-offs.
		habitRouter.RegisterRoutes(r)

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
		labsHandler := labs.New(pool, rdb, cfg.JWTSecret, "mindforge-labproxy", cfg.PistonURL, cfg.PistonTimeout, coursesSvc, labsRuntime, gitlabRouter.Service(), notificationsRouter.Service, entitlementsRouter.Service)
		labsHandler.RegisterRoutes(r)
		labsHandler.RegisterAdminRoutes(r, authzHandler.Service())

		// Calendar — events, RSVPs, recurring series, external invites, personal ICS feed.
		calendarRouter.RegisterRoutes(r)

		// Mentor session booking — mentor availability, the bookable slot
		// grid, booking/cancel/reschedule with credit accounting, post-session
		// feedback and mentor notes, and the org's booking policy. Only the
		// admin surface is permission-gated; booking your own session is
		// authorized per-row inside the service.
		sessionsRouter.RegisterRoutes(r, authzHandler.Service())

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

		// Project marketplace — requirement CRUD/board/applications (staff +
		// any org member, row-scoped — see internal/projectmarket/routes.go).
		projectmarketRouter.RegisterRoutes(r)

		// Notifications — generic in-app notifications: list, unread count,
		// mark read/read-all. Any authenticated member, row-scoped to their
		// own notifications.
		notificationsRouter.RegisterRoutes(r)

		// Legal — check/record Terms/Privacy consent.
		legalRouter.RegisterRoutes(r)

		// Privacy — export/delete-account.
		privacyRouter.RegisterRoutes(r)

		// Moderation — file/list/resolve content reports.
		moderationRouter.RegisterRoutes(r)
	})

	return r
}

// corsMiddleware sets CORS headers allowing the configured FRONTEND_URL origin
// (plus any CORS_EXTRA_ORIGINS) with credentials.  X-CSRF-Token is explicitly
// listed so browser JS can send it.
func corsMiddleware(cfg *config.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin == cfg.FrontendURL || slices.Contains(cfg.CORSExtraOrigins, origin) {
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

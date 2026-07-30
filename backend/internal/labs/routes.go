package labs

import (
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/courses"
	"github.com/redis/go-redis/v9"
)

// New wires the full labs dependency graph and returns the HTTP handler.
// coursesSvc completes the course module wrapping a lab once its session
// finishes. container is the lab sandbox runtime (Docker or Kubernetes) —
// selected once by the caller (internal/api/router.go) based on
// config.LabsRuntime, so both the HTTP handler and the reaper job handlers
// (internal/jobs/handlers/labs.go) share one runtime instance. repoPreparer
// is the Batch 3 lab-container auto-clone hook's optional dependency — pass
// nil when GitLab isn't configured (see RepoPreparer's own doc comment in
// service.go); internal/api/router.go passes gitlabRouter.Service() here.
func New(pool *pgxpool.Pool, rdb *redis.Client, jwtSecret, jwtIssuer, pistonURL string, pistonTimeout time.Duration, coursesSvc *courses.Service, container ContainerRuntime, repoPreparer RepoPreparer) *Handler {
	repo := NewRepo(pool)
	piston := newLabPiston(pistonURL, pistonTimeout)
	service := NewService(repo, container, rdb, pool, piston, coursesSvc, repoPreparer)
	return NewHandler(repo, service, pool, rdb, jwtSecret, jwtIssuer, piston)
}

// RegisterRoutes mounts all student-facing lab endpoints onto the given router.
// The caller is responsible for applying RequireAuth and RequireCSRF middleware
// before this; session ownership (IDOR) is enforced inside each handler.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/labs/{labId}", h.HandleGetLab)
	r.Get("/api/modules/{moduleId}/lab", h.HandleGetLabByModule)
	r.Post("/api/labs/{labId}/sessions", h.HandleStartSession)
	r.Get("/api/labs/sessions/active", h.HandleListActiveSessions)
	r.Get("/api/labs/sessions/{sessionId}", h.HandleGetSession)
	r.Get("/api/labs/sessions/{sessionId}/events", h.HandleSessionEvents)
	r.Post("/api/labs/sessions/{sessionId}/ws-token", h.HandleMintWSToken)
	r.Post("/api/labs/sessions/{sessionId}/reset", h.HandleResetSession)
	r.Post("/api/labs/sessions/{sessionId}/end", h.HandleEndSession)
	r.Post("/api/labs/sessions/{sessionId}/tasks/{taskId}/verify", h.HandleVerifyTask)
	r.Post("/api/labs/run", h.HandleRunSnippet)

	r.Get("/api/labs/sessions/{sessionId}/files", h.HandleListFiles)
	r.Get("/api/labs/sessions/{sessionId}/files/read", h.HandleReadFile)
	r.Put("/api/labs/sessions/{sessionId}/files", h.HandleWriteFile)
	r.Post("/api/labs/sessions/{sessionId}/files/mkdir", h.HandleCreateDirectory)
	r.Post("/api/labs/sessions/{sessionId}/files/rename", h.HandleRenameFile)
	r.Delete("/api/labs/sessions/{sessionId}/files", h.HandleDeleteFile)
	r.Post("/api/labs/sessions/{sessionId}/files/validate", h.HandleValidateFile)
	r.Get("/api/labs/sessions/{sessionId}/resources", h.HandleGetResources)

	// Sandbox workspace: port discovery + HackerEarth-style Run/Submit.
	r.Get("/api/labs/sessions/{sessionId}/ports", h.HandleListPorts)
	r.Post("/api/labs/sessions/{sessionId}/run", h.HandleRunScript)
	r.Post("/api/labs/sessions/{sessionId}/submit", h.HandleSubmitAll)
}

// RegisterAdminRoutes mounts the /admin/labs/warm-pools API: the metrics
// matrix (signal inputs + target per lab) and the mode/size override. Gated
// on admin.manage_org, the same permission that already governs org-wide
// operational settings — warm-pool sizing is one more org-scoped operational
// knob, not a distinct permission domain.
func (h *Handler) RegisterAdminRoutes(r chi.Router, authzSvc *authz.Service) {
	r.With(authz.RequirePermission(authzSvc, "admin.manage_org")).Group(func(r chi.Router) {
		r.Get("/api/admin/labs/warm-pools", h.HandleListWarmPools)
		r.Put("/api/admin/labs/{labId}/warm-pool", h.HandleUpdateWarmPoolConfig)
	})
}

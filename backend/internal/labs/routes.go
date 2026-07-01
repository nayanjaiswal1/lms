package labs

import (
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// New wires the full labs dependency graph and returns the HTTP handler.
func New(pool *pgxpool.Pool, rdb *redis.Client, jwtSecret, jwtIssuer, pistonURL string, pistonTimeout time.Duration) *Handler {
	repo := NewRepo(pool)
	container := NewContainerService()
	piston := newLabPiston(pistonURL, pistonTimeout)
	service := NewService(repo, container, rdb, pool, piston)
	return NewHandler(repo, service, pool, rdb, jwtSecret, jwtIssuer, piston)
}

// RegisterRoutes mounts all student-facing lab endpoints onto the given router.
// The caller is responsible for applying RequireAuth and RequireCSRF middleware
// before this; session ownership (IDOR) is enforced inside each handler.
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/api/labs/{labId}", h.HandleGetLab)
	r.Get("/api/modules/{moduleId}/lab", h.HandleGetLabByModule)
	r.Post("/api/labs/{labId}/sessions", h.HandleStartSession)
	r.Get("/api/labs/sessions/{sessionId}", h.HandleGetSession)
	r.Get("/api/labs/sessions/{sessionId}/events", h.HandleSessionEvents)
	r.Post("/api/labs/sessions/{sessionId}/ws-token", h.HandleMintWSToken)
	r.Post("/api/labs/sessions/{sessionId}/reset", h.HandleResetSession)
	r.Post("/api/labs/sessions/{sessionId}/end", h.HandleEndSession)
	r.Post("/api/labs/sessions/{sessionId}/tasks/{taskId}/verify", h.HandleVerifyTask)
}

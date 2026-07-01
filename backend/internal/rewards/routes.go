package rewards

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// New builds the fully-wired rewards handler.
func New(pool *pgxpool.Pool, rdb *redis.Client) *Handler {
	repo := NewRepo(pool, rdb)
	svc := NewService(repo)
	return NewHandler(svc)
}

// NewServiceFromPool creates a Service directly for injection into other services.
func NewServiceFromPool(pool *pgxpool.Pool, rdb *redis.Client) *Service {
	return NewService(NewRepo(pool, rdb))
}

// RegisterRoutes mounts reward endpoints. Caller has already applied RequireAuth + RequireCSRF.
func (h *Handler) RegisterRoutes(r chi.Router) {
	// Public — badge catalog (cache-able).
	r.Get("/api/rewards/definitions", h.ListDefinitions)

	// Authenticated — user profile and leaderboard.
	r.Get("/api/rewards/me", h.GetMyProfile)
	r.Get("/api/rewards/leaderboard", h.GetLeaderboard)
	r.Get("/api/rewards/leaderboard/me", h.GetMyRank)
}

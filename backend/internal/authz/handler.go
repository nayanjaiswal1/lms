package authz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/redis/go-redis/v9"
)

// Handler holds all RBAC sub-services and exposes HTTP handlers.
type Handler struct {
	svc       *Service
	adminSvc  *AdminService
	adminRepo *AdminRepo
	auditRepo *AuditRepo
}

// New wires up the complete RBAC dependency graph from a pool and Redis client.
func New(pool *pgxpool.Pool, rdb *redis.Client) *Handler {
	repo := NewRepo(pool)
	cache := NewCache(rdb)
	svc := NewService(repo, cache)

	adminRepo := NewAdminRepo(pool)
	auditRepo := NewAuditRepo(pool)
	adminSvc := NewAdminService(adminRepo, auditRepo, svc)

	return &Handler{
		svc:       svc,
		adminSvc:  adminSvc,
		adminRepo: adminRepo,
		auditRepo: auditRepo,
	}
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

func (h *Handler) getClaims(r *http.Request) (*auth.Claims, bool) {
	return auth.GetClaims(r.Context())
}

func (h *Handler) decodeJSON(r *http.Request, dst any) error {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		return fmt.Errorf("invalid request body: %w", err)
	}
	return nil
}

func (h *Handler) queryInt(r *http.Request, key string, defaultVal int) int {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return defaultVal
	}
	v, err := strconv.Atoi(raw)
	if err != nil || v < 0 {
		return defaultVal
	}
	return v
}

func (h *Handler) queryString(r *http.Request, key string) string {
	return r.URL.Query().Get(key)
}

func (h *Handler) queryBoolPtr(r *http.Request, key string) *bool {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return nil
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		return nil
	}
	return &v
}

package coupons

import (
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/authz"
)

// Router mounts the coupons admin API. Service is exported so other packages
// (mentoring, courses) can be handed the concrete *Service at construction
// time in backend/internal/api/router.go, the same wiring shape
// mentoring.Router uses for its own Service.
type Router struct {
	handler *Handler
	Service *Service
}

func New(pool *pgxpool.Pool) *Router {
	repo := NewRepo(pool)
	service := NewService(repo)
	return &Router{handler: &Handler{service: service}, Service: service}
}

// RegisterRoutes mounts the coupon admin CRUD API. Caller has already
// applied RequireAuth + RequireCSRF middleware. Every route requires the
// payments.manage_coupons permission (default: tenant_admin only — see
// backend/db/migrations/004_payments_coupons.sql).
func (rt *Router) RegisterRoutes(r chi.Router, authzSvc *authz.Service) {
	manageCoupons := authz.RequirePermission(authzSvc, PermissionManageCoupons)

	r.Group(func(r chi.Router) {
		r.Use(manageCoupons)
		r.Post("/api/coupons", rt.handler.Create)
		r.Get("/api/coupons", rt.handler.List)
		r.Get("/api/coupons/{couponID}", rt.handler.Get)
		r.Patch("/api/coupons/{couponID}", rt.handler.Update)
		r.Delete("/api/coupons/{couponID}", rt.handler.Deactivate)
	})
}

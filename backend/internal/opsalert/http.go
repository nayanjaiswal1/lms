package opsalert

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/httputil"
	apimiddleware "github.com/mindforge/backend/internal/middleware"
)

// HTTPHandler serves the platform-admin alert-rule routes.
type HTTPHandler struct {
	pool *pgxpool.Pool
	svc  *Service
}

// NewHTTPHandler builds the handler.
func NewHTTPHandler(pool *pgxpool.Pool, svc *Service) *HTTPHandler {
	return &HTTPHandler{pool: pool, svc: svc}
}

// RegisterRoutes mounts /api/admin/ops-alert-rules. The parent router must
// already have RequireAuth and RequireCSRF applied.
func (h *HTTPHandler) RegisterRoutes(r chi.Router) {
	r.Route("/api/admin/ops-alert-rules", func(r chi.Router) {
		r.Use(apimiddleware.RequirePlatformRole(h.pool, apimiddleware.PlatformRoleSuperAdmin))
		r.Get("/", h.list)
		r.Put("/", h.put)
	})
}

func (h *HTTPHandler) list(w http.ResponseWriter, r *http.Request) {
	rules, err := h.svc.ListRules(r.Context())
	if err != nil {
		slog.ErrorContext(r.Context(), "opsalert: list rules", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load alert rules.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, rules)
}

func (h *HTTPHandler) put(w http.ResponseWriter, r *http.Request) {
	var rule Rule
	if !httputil.DecodeJSON(w, r, &rule) {
		return
	}
	saved, err := h.svc.UpsertRule(r.Context(), rule)
	if errors.Is(err, ErrInvalidRule) {
		httputil.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "opsalert: upsert rule", "error", err)
		httputil.WriteError(w, http.StatusInternalServerError, "Could not save alert rule.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, saved)
}

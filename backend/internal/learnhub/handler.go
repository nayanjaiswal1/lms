package learnhub

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the Learn hub aggregator over HTTP.
type Handler struct {
	repo *Repo
}

// New constructs the Learn hub aggregator handler from a connection pool.
func New(pool *pgxpool.Pool) *Handler {
	return &Handler{repo: NewRepo(pool)}
}

// GetStats handles GET /api/learn/hub-stats — the single count-per-card
// payload backing the Learn hub page, replacing 9 separate full-list
// fetches across 9 domains with one query.
func (h *Handler) GetStats(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	stats, err := h.repo.GetStats(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load Learn hub stats.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, stats)
}

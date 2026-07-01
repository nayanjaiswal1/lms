package rewards

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes reward endpoints over HTTP.
type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// ─── GET /api/rewards/definitions ────────────────────────────────────────────

func (h *Handler) ListDefinitions(w http.ResponseWriter, r *http.Request) {
	defs, err := h.svc.ListDefinitions(r.Context())
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load badge definitions.")
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=3600")
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"definitions": defs})
}

// ─── GET /api/rewards/me ─────────────────────────────────────────────────────

func (h *Handler) GetMyProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	profile, err := h.svc.GetUserRewardProfile(r.Context(), claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load reward profile.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, profile)
}

// ─── GET /api/rewards/leaderboard ────────────────────────────────────────────
//
// Query params:
//
//	scope        — global | org | batch | course | feature  (default: org)
//	scope_id     — UUID of the org/batch/course (required for non-global scopes)
//	feature_type — problems | quizzes (required when scope=feature)
//	limit        — 1–100 (default 20)
//	offset       — (default 0)

func (h *Handler) GetLeaderboard(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	q := r.URL.Query()
	scope := q.Get("scope")
	if scope == "" {
		scope = "org"
	}
	scopeID := q.Get("scope_id")
	featureType := q.Get("feature_type")
	limit := queryInt(r, "limit", 20)
	offset := queryInt(r, "offset", 0)
	if limit > 100 {
		limit = 100
	}

	key, ok2 := buildLBKey(scope, scopeID, featureType, claims.OrgID)
	if !ok2 {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid leaderboard scope or missing scope_id.")
		return
	}

	entries, err := h.svc.GetLeaderboard(r.Context(), key, limit, offset)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load leaderboard.")
		return
	}

	// Include the caller's own rank.
	rank, xp, _ := h.svc.GetUserRank(r.Context(), key, claims.UserID)

	httputil.WriteJSON(w, http.StatusOK, map[string]any{
		"entries": entries,
		"me": map[string]any{
			"rank": rank,
			"xp":   xp,
		},
	})
}

// ─── GET /api/rewards/leaderboard/me ─────────────────────────────────────────

func (h *Handler) GetMyRank(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	scope := q.Get("scope")
	if scope == "" {
		scope = "org"
	}
	key, ok2 := buildLBKey(scope, q.Get("scope_id"), q.Get("feature_type"), claims.OrgID)
	if !ok2 {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid scope.")
		return
	}
	rank, xp, err := h.svc.GetUserRank(r.Context(), key, claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load rank.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"rank": rank, "xp": xp, "scope": scope})
}

// ─── helpers ──────────────────────────────────────────────────────────────────

func buildLBKey(scope, scopeID, featureType, defaultOrgID string) (string, bool) {
	switch scope {
	case "global":
		return "leaderboard:global", true
	case "org":
		id := scopeID
		if id == "" {
			id = defaultOrgID
		}
		if id == "" {
			return "", false
		}
		return "leaderboard:org:" + id, true
	case "batch":
		if scopeID == "" {
			return "", false
		}
		return "leaderboard:batch:" + scopeID, true
	case "course":
		if scopeID == "" {
			return "", false
		}
		return "leaderboard:course:" + scopeID, true
	case "feature":
		id := scopeID
		if id == "" {
			id = defaultOrgID
		}
		if id == "" || featureType == "" {
			return "", false
		}
		return "leaderboard:feature:org:" + id + ":" + featureType, true
	}
	return "", false
}

func ctxClaims(w http.ResponseWriter, r *http.Request) (*auth.Claims, bool) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return nil, false
	}
	return claims, true
}

func queryInt(r *http.Request, key string, def int) int {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			return n
		}
	}
	return def
}

// ─── unused imports guard ─────────────────────────────────────────────────────

var (
	_ = chi.URLParam
	_ = json.Marshal
	_ = errors.New
)

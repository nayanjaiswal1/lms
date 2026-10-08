package rewards

import (
	"net/http"
	"strconv"

	"github.com/google/uuid"

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
	claims, ok := auth.RequireClaims(w, r)
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
//	scope        — global | org | batch | group | course | feature  (default: org)
//	scope_id     — UUID of the org/batch/cohort_group/course (required for non-global scopes)
//	feature_type — problems | quizzes (required when scope=feature)
//	limit        — 1–100 (default 20)
//	offset       — (default 0)

func (h *Handler) GetLeaderboard(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
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
	limit := httputil.QueryIntNonNegative(r, "limit", 20)
	offset := httputil.QueryIntNonNegative(r, "offset", 0)
	if limit > 100 {
		limit = 100
	}

	key, ok2 := h.resolveLBKey(w, r, scope, scopeID, featureType, claims.OrgID)
	if !ok2 {
		return
	}

	entries, err := h.svc.GetLeaderboard(r.Context(), key, limit, offset)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load leaderboard.")
		return
	}
	if scope == "global" {
		entries = anonymiseGlobal(entries, claims.UserID)
	}

	// Include the caller's own rank.
	rank, xp, err := h.svc.GetUserRank(r.Context(), key, claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load leaderboard.")
		return
	}

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
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	scope := q.Get("scope")
	if scope == "" {
		scope = "org"
	}
	key, ok2 := h.resolveLBKey(w, r, scope, q.Get("scope_id"), q.Get("feature_type"), claims.OrgID)
	if !ok2 {
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

// resolveLBKey builds the Redis key and rejects any scope the caller's org does
// not own. org/feature scopes are pinned to the caller's own org; batch, group
// and course ids must belong to it.
func (h *Handler) resolveLBKey(w http.ResponseWriter, r *http.Request, scope, scopeID, featureType, orgID string) (string, bool) {
	if scope == "org" || scope == "feature" {
		if scopeID != "" && scopeID != orgID {
			httputil.WriteError(w, http.StatusForbidden, "You cannot view this leaderboard.")
			return "", false
		}
		scopeID = orgID
	}
	key, ok := buildLBKey(scope, scopeID, featureType, orgID)
	if !ok {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid leaderboard scope or missing scope_id.")
		return "", false
	}
	if _, ok := scopeTables[scope]; ok {
		if _, err := uuid.Parse(scopeID); err != nil {
			httputil.WriteError(w, http.StatusBadRequest, "Invalid scope_id.")
			return "", false
		}
	}
	owned, err := h.svc.ScopeInOrg(r.Context(), scope, scopeID, orgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not load leaderboard.")
		return "", false
	}
	if !owned {
		httputil.WriteError(w, http.StatusForbidden, "You cannot view this leaderboard.")
		return "", false
	}
	return key, true
}

// anonymiseGlobal hides identity of everyone but the caller on the
// platform-wide board so it cannot be used as a cross-tenant user directory.
func anonymiseGlobal(entries []LeaderboardEntry, callerID string) []LeaderboardEntry {
	for i := range entries {
		if entries[i].UserID == callerID {
			continue
		}
		entries[i].UserID = "anon-" + strconv.Itoa(entries[i].Rank)
		entries[i].Name = "Learner"
		entries[i].AvatarURL = nil
	}
	return entries
}

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
	case "group":
		if scopeID == "" {
			return "", false
		}
		return "leaderboard:group:" + scopeID, true
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

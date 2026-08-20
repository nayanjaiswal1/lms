package entitlements

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

type Handler struct {
	service *Service
}

func newHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// GetMyUsage returns the current account's quota standing for every
// numeric, month-bucketed limit its tier has — concurrent-style limits
// (lab_sessions_concurrent) are live state owned by the domain package
// (labs) and not reported here; a tier with no limit for a key is simply
// omitted (unlimited).
func (h *Handler) GetMyUsage(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}

	accountID, tierID, _, err := h.service.ResolveAccount(r.Context(), claims.UserID, claims.OrgID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not resolve account.")
		return
	}
	tierName, err := h.service.TierName(r.Context(), tierID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Could not resolve account.")
		return
	}

	statuses := []UsageStatus{}
	for _, key := range QuotaKeys {
		limit, period, found, err := h.service.QuotaLimit(r.Context(), tierID, key)
		if err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Could not resolve usage.")
			return
		}
		if !found || period == PeriodConcurrent {
			continue
		}
		usedSeconds, err := h.service.MonthlySecondsUsed(r.Context(), accountID, key)
		if err != nil {
			httputil.WriteError(w, http.StatusInternalServerError, "Could not resolve usage.")
			return
		}
		statuses = append(statuses, UsageStatus{FeatureKey: key, Used: int(usedSeconds / 3600), Limit: limit, Period: period})
	}

	httputil.WriteJSON(w, http.StatusOK, map[string]any{"tier_id": tierID, "tier_name": tierName, "usage": statuses})
}

// ─── Platform admin (super_admin) ───────────────────────────────────────────

// AdminListPlanLimits returns every editable plan_limits row (existing or
// defaulted) for the tier in the {tier_id} URL param.
func (h *Handler) AdminListPlanLimits(w http.ResponseWriter, r *http.Request) {
	tierID := chi.URLParam(r, "tier_id")
	limits, err := h.service.ListPlanLimits(r.Context(), tierID)
	if err != nil {
		writeEntitlementsError(w, err, "Could not list plan limits.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"limits": limits})
}

type upsertPlanLimitRequest struct {
	Kind         Kind    `json:"kind"`
	BoolValue    *bool   `json:"bool_value,omitempty"`
	NumericValue *int    `json:"numeric_value,omitempty"`
	Period       *string `json:"period,omitempty"`
}

// AdminSetPlanLimit writes one gate or quota row for {tier_id}/{key}.
func (h *Handler) AdminSetPlanLimit(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	tierID := chi.URLParam(r, "tier_id")
	key := chi.URLParam(r, "key")

	var req upsertPlanLimitRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	pl := PlanLimit{TierID: tierID, FeatureKey: key, Kind: req.Kind, BoolValue: req.BoolValue, NumericValue: req.NumericValue, Period: req.Period}
	if err := h.service.UpsertPlanLimit(r.Context(), pl, claims.UserID); err != nil {
		writeEntitlementsError(w, err, "Could not update plan limit.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

type setTierRequest struct {
	TierID string `json:"tier_id"`
}

// AdminSetUserTier assigns a pricing tier to the individual account in the
// {id} URL param.
func (h *Handler) AdminSetUserTier(w http.ResponseWriter, r *http.Request) {
	h.adminSetTier(w, r, "user")
}

// AdminSetOrgTier assigns a pricing tier to the org in the {id} URL param.
func (h *Handler) AdminSetOrgTier(w http.ResponseWriter, r *http.Request) {
	h.adminSetTier(w, r, "org")
}

func (h *Handler) adminSetTier(w http.ResponseWriter, r *http.Request, kind string) {
	claims, ok := auth.GetClaims(r.Context())
	if !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "Authentication required.")
		return
	}
	id := chi.URLParam(r, "id")

	var req setTierRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
		return
	}

	if err := h.service.SetAccountTier(r.Context(), kind, id, req.TierID, claims.UserID); err != nil {
		writeEntitlementsError(w, err, "Could not update tier.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func writeEntitlementsError(w http.ResponseWriter, err error, fallback string) {
	switch {
	case errors.Is(err, ErrInvalidTier):
		httputil.WriteError(w, http.StatusBadRequest, "Unknown tier, or tier is for the wrong audience.")
	case errors.Is(err, ErrUnknownFeatureKey):
		httputil.WriteError(w, http.StatusBadRequest, "Unknown or unsupported feature key.")
	default:
		httputil.WriteError(w, http.StatusInternalServerError, fallback)
	}
}

package labs

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// warmPoolMatrixRow is one lab's row in the admin warm-pool metrics matrix:
// current pool state + config, alongside the exact signal snapshot and
// resulting target the most recent reconciler tick computed.
type warmPoolMatrixRow struct {
	WarmPoolLab
	Target    int             `json:"target"`
	DecidedAt *time.Time      `json:"decided_at"`
	Inputs    json.RawMessage `json:"inputs"`
}

// HandleListWarmPools returns the metrics matrix for every warm-pool-eligible
// lab: pool state, config, and the raw signal inputs + target from the most
// recent reconciler tick. This is the data /admin/labs/warm-pools renders —
// a matrix of numbers, not a narrative decision history.
func (h *Handler) HandleListWarmPools(w http.ResponseWriter, r *http.Request) {
	labsList, err := h.repo.ListWarmPoolLabs(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}
	decisions, err := h.repo.LatestWarmPoolDecisions(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}

	rows := make([]warmPoolMatrixRow, 0, len(labsList))
	for _, lab := range labsList {
		row := warmPoolMatrixRow{WarmPoolLab: lab, Inputs: json.RawMessage("{}")}
		if d, ok := decisions[lab.LabID]; ok {
			row.Target = d.Target
			decidedAt := d.DecidedAt
			row.DecidedAt = &decidedAt
			row.Inputs = json.RawMessage(d.Inputs)
		}
		rows = append(rows, row)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"labs": rows})
}

// warmPoolConfigUpdate is the admin override payload for one lab's pool.
type warmPoolConfigUpdate struct {
	Mode      string `json:"mode"`
	FixedSize int    `json:"fixed_size"`
	MaxSize   int    `json:"max_size"`
}

// HandleUpdateWarmPoolConfig lets an admin override a lab's pool mode/sizing;
// the reconciler picks it up on its next tick.
func (h *Handler) HandleUpdateWarmPoolConfig(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	labID := chi.URLParam(r, "labId")

	var req warmPoolConfigUpdate
	if !decodeJSON(w, r, &req) {
		return
	}
	switch req.Mode {
	case "auto", "fixed", "off":
	default:
		httputil.WriteError(w, http.StatusBadRequest, "mode must be auto, fixed, or off.")
		return
	}
	if req.FixedSize < 0 || req.FixedSize > 20 || req.MaxSize < 0 || req.MaxSize > 20 {
		httputil.WriteError(w, http.StatusBadRequest, "fixed_size and max_size must be between 0 and 20.")
		return
	}

	if err := h.repo.UpsertWarmPoolConfig(r.Context(), labID, req.Mode, req.FixedSize, req.MaxSize, claims.UserID); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

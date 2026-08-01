package labs

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// warmPoolMatrixRow is one image's row in the admin warm-pool metrics matrix:
// current pool state and measured warm-start latency, alongside the exact
// signal snapshot and resulting target the most recent reconciler tick
// computed.
type warmPoolMatrixRow struct {
	WarmPoolImage
	Mode      string          `json:"mode"`
	Target    int             `json:"target"`
	Reason    string          `json:"reason"`
	DecidedAt *time.Time      `json:"decided_at"`
	Inputs    json.RawMessage `json:"inputs"`
}

// HandleListWarmPools returns the metrics matrix for every warm-pool-eligible
// IMAGE used by the caller's org: pool state, measured warm-start latency, and
// the raw signal inputs + target + reasoning from the most recent reconciler
// tick.
//
// Read-only by design. The pool is one shared platform resource — the same
// mindforge/lab-k8s containers back every tenant's k8s labs — so there is no
// per-org write that could be correct here; sizing is either automatic (the
// normal case) or an operator's LABS_WARM_POOL_OVERRIDES. What an org admin
// legitimately needs from this page is the answer to "is the platform holding
// sandboxes ready for my students, and if not, why", which is exactly what the
// target + reason columns say.
func (h *Handler) HandleListWarmPools(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	images, err := h.repo.ListWarmPoolImagesForOrg(r.Context(), claims.OrgID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	decisions, err := h.repo.LatestWarmPoolDecisions(r.Context())
	if err != nil {
		writeDomainError(w, err)
		return
	}

	rows := make([]warmPoolMatrixRow, 0, len(images))
	for _, img := range images {
		row := warmPoolMatrixRow{
			WarmPoolImage: img,
			Mode:          WarmPoolModeAuto,
			Inputs:        json.RawMessage("{}"),
		}
		if d, ok := decisions[img.Image]; ok {
			row.Mode = d.Mode
			row.Target = d.Target
			row.Reason = d.Reason
			decidedAt := d.DecidedAt
			row.DecidedAt = &decidedAt
			row.Inputs = json.RawMessage(d.Inputs)
		}
		rows = append(rows, row)
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{"images": rows})
}

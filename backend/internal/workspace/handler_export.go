package workspace

import (
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/ratelimit"
)

// ExportCSV is GET …/export/{kind}.csv (manager+, contract-phase5.md 5d).
// The per-user rate limit is applied here, before any response byte is
// written, the same "check at the handler layer" convention the public
// interest endpoint uses (handler.go's own doc comment) — a mid-stream CSV
// write can't be un-sent once it starts.
func (h *Handler) ExportCSV(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	kind := chi.URLParam(r, "kind")
	if kind != ExportKindItems && kind != ExportKindTimeLogs && kind != ExportKindMembers {
		httputil.WriteError(w, http.StatusBadRequest, "Unknown export kind.")
		return
	}
	if allowed, retryAfter := h.limiter.Allow(r.Context(), "rl:pw:export:"+pc.UserID, h.cfg.Workspace.ExportPerUserHour, time.Hour); !allowed {
		w.Header().Set("Retry-After", strconv.Itoa(ratelimit.RetryAfterSeconds(retryAfter)))
		httputil.WriteError(w, http.StatusTooManyRequests, "Too many requests. Please try again later.")
		return
	}

	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s-%s.csv"`, pc.ProjectID, kind))
	// A failure after this point can only be logged, not turned into a clean
	// HTTP error: the 200 status and any CSV bytes already written to w are
	// unrecoverable once streaming starts (no buffering the whole export in
	// memory first — that's the point of writing straight to w).
	if err := h.service.ExportCSV(r.Context(), pc, kind, w); err != nil {
		slog.ErrorContext(r.Context(), "workspace: export csv failed mid-stream", "project_id", pc.ProjectID, "kind", kind, "error", err)
	}
}

package workspace

import (
	"net/http"
	"time"

	"github.com/mindforge/backend/internal/httputil"
)

// parseDashboardDate parses a "YYYY-MM-DD" query param, zero time on empty
// or malformed input — GetDashboard's own defaulting takes over from there.
func parseDashboardDate(r *http.Request, key string) time.Time {
	v := httputil.QueryStr(r, key)
	if v == "" {
		return time.Time{}
	}
	t, err := time.Parse("2006-01-02", v)
	if err != nil {
		return time.Time{}
	}
	return t
}

// GetDashboard is GET …/dashboard?from=&to=&track=&user=&release= (viewer).
func (h *Handler) GetDashboard(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	f := DashboardFilter{
		From:      parseDashboardDate(r, "from"),
		To:        parseDashboardDate(r, "to"),
		TrackID:   httputil.QueryStr(r, "track"),
		UserID:    httputil.QueryStr(r, "user"),
		ReleaseID: httputil.QueryStr(r, "release"),
	}
	dashboard, err := h.service.GetDashboard(r.Context(), pc, f)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, dashboard)
}

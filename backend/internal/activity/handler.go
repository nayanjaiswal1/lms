package activity

import (
	"net/http"
	"strconv"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/httputil"
)

// Handler exposes the activity feed over HTTP.
type Handler struct {
	repo *Repo
}

// New constructs the activity domain handler.
func New(pool *pgxpool.Pool) *Handler {
	return &Handler{repo: NewRepo(pool)}
}

const (
	defaultLimit = 50
	maxLimit     = 200
	// tzOffsetBoundMin mirrors whatnow's ?tz= convention (UTC offset in
	// minutes east of UTC, clamped to the real range of UTC-14..UTC+14).
	tzOffsetBoundMin = 14 * 60
)

// List handles GET /api/activity — the caller's own cross-domain timeline,
// newest first. Never org-wide: every branch of the underlying query is
// scoped to claims.UserID (see repo.go's org-scoping note).
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.RequireClaims(w, r)
	if !ok {
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > maxLimit {
		limit = defaultLimit
	}

	tzOffsetMin, tzErr := strconv.Atoi(r.URL.Query().Get("tz"))
	if tzErr != nil || tzOffsetMin < -tzOffsetBoundMin || tzOffsetMin > tzOffsetBoundMin {
		tzOffsetMin = 0
	}

	cursorAt, cursorKey, err := DecodeCursor(r.URL.Query().Get("cursor"))
	if err != nil {
		cursorKey = ""
		cursorAt = nil
	}

	entries, err := h.repo.List(r.Context(), claims.UserID, claims.OrgID, tzOffsetMin, cursorAt, cursorKey, limit+1)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch activity.")
		return
	}

	page := Page{Entries: entries}
	if len(entries) > limit {
		page.Entries = entries[:limit]
		last := page.Entries[limit-1]
		page.NextCursor = EncodeCursor(last.OccurredAt, last.Key)
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

package mcpconnect

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/mindforge/backend/internal/httputil"
)

// ActionLogEntry is one row of mcp_action_log — a single MCP tool call and,
// for mutating tools, enough before/after state to revert it. The same type
// serves both directions: logAction populates Args/BeforeState/AfterState
// with the raw Go values a tool call produced (about to be marshaled to
// jsonb), while ListActionLog/GetActionLogEntry populate them by scanning
// jsonb columns back into `any` (Postgres's generic decode, not the original
// typed struct) — see decodeBeforeState for why a Revert closure re-encodes
// before typed-unmarshaling.
type ActionLogEntry struct {
	ID           string     `json:"id"`
	OrgID        string     `json:"-"`
	UserID       string     `json:"-"`
	ConnectionID string     `json:"-"`
	ToolName     string     `json:"tool_name"`
	Args         any        `json:"args"`
	TargetType   string     `json:"target_type,omitempty"`
	TargetID     string     `json:"target_id,omitempty"`
	BeforeState  *any       `json:"before_state,omitempty"`
	AfterState   *any       `json:"after_state,omitempty"`
	Revertible   bool       `json:"revertible"`
	RevertedAt   *time.Time `json:"reverted_at,omitempty"`
	RevertedBy   *string    `json:"reverted_by,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

type ActionLogPage struct {
	Entries    []ActionLogEntry `json:"entries"`
	NextCursor string           `json:"next_cursor,omitempty"`
}

// extractTargetID identifies the row a tool call acted on. For tools whose
// arguments name the target directly (module_id/event_id), that's
// authoritative. Every other mutating tool creates something new with no id
// to pass in — its target only exists in the call's own result, so we fall
// back to that result's own "id" field (every Course/CourseModule/Event/
// CourseContentProposal JSON-tags one). Deliberately does NOT check
// course_id/target_course_id: those args name a *parent* or *destination*
// course, never the thing a revert would actually act on.
func extractTargetID(args map[string]any, result any) string {
	for _, key := range []string{"module_id", "event_id"} {
		if v, ok := args[key].(string); ok && v != "" {
			return v
		}
	}
	b, err := json.Marshal(result)
	if err != nil {
		return ""
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		return ""
	}
	if v, ok := m["id"].(string); ok {
		return v
	}
	return ""
}

// matchedExistingResult is implemented by tool results that resolved to an
// already-existing row instead of creating a new one (see
// courses.SelfCourseCreationResult/SelfCourseModuleResult). logAction checks
// it to force Revertible=false for these — the row's ID lands in TargetID
// same as a real create, but nothing was created, so a later Revert must
// never delete/soft-delete a row that existed before this call.
type matchedExistingResult interface {
	IsMatchedExisting() bool
}

// isRevertible decides whether a completed tool call should be recorded as
// undoable. A tool with no Revert closure never is; one that resolved to an
// already-existing row (see matchedExistingResult) never is either, however
// its Revert closure is not nil — Revert exists for the ordinary "created
// something new" case, and there is nothing for it to safely undo here.
func isRevertible(tool mcpTool, result any) bool {
	if tool.Revert == nil {
		return false
	}
	if m, ok := result.(matchedExistingResult); ok && m.IsMatchedExisting() {
		return false
	}
	return true
}

// logAction records a completed tool call. Fire-and-forget, mirroring
// internal/orgs.writeAuditLog: a logging failure must never fail the tool
// call itself, since the student's AI already got its real result.
func (rt *Router) logAction(ctx context.Context, id mcpIdentity, tool mcpTool, args map[string]any, before, result any) {
	revertible := isRevertible(tool, result)
	var beforePtr *any
	if before != nil {
		beforePtr = &before
	}
	entry := ActionLogEntry{
		OrgID: id.OrgID, UserID: id.UserID, ConnectionID: id.ConnectionID,
		ToolName: tool.Name, Args: args, TargetType: tool.TargetType,
		TargetID: extractTargetID(args, result), BeforeState: beforePtr, AfterState: &result,
		Revertible: revertible,
	}
	if err := rt.repo.InsertActionLog(ctx, entry); err != nil {
		slog.Error("mcpconnect: write action log", "tool", tool.Name, "error", err)
	}
}

// decodeBeforeState re-encodes a jsonb-decoded before_state (scanned into a
// generic `any` — a map/slice, not the original struct) back into dst. The
// log row is always read in a separate request from the one that captured
// it, so there's no way around this round-trip.
func decodeBeforeState(entry ActionLogEntry, dst any) error {
	if entry.BeforeState == nil {
		return fmt.Errorf("mcpconnect: revert %s: no before-state recorded", entry.ToolName)
	}
	b, err := json.Marshal(*entry.BeforeState)
	if err != nil {
		return fmt.Errorf("mcpconnect: revert %s: re-marshal before state: %w", entry.ToolName, err)
	}
	if err := json.Unmarshal(b, dst); err != nil {
		return fmt.Errorf("mcpconnect: revert %s: decode before state: %w", entry.ToolName, err)
	}
	return nil
}

// ─── cursor pagination ─────────────────────────────────────────────────────
// Small, deliberate duplicate of internal/orgs's (created_at, id) cursor —
// that helper is unexported to its own package, and 25 lines of base64
// encode/decode doesn't justify exporting it across an otherwise-unrelated
// package boundary.

func encodeActionLogCursor(createdAt time.Time, id string) string {
	raw := fmt.Sprintf("%d:%s", createdAt.UnixMicro(), id)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func decodeActionLogCursor(cursor string) (time.Time, string, error) {
	if cursor == "" {
		return time.Time{}, "", nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", fmt.Errorf("mcpconnect: decode cursor: base64: %w", err)
	}
	parts := strings.SplitN(string(b), ":", 2)
	if len(parts) != 2 {
		return time.Time{}, "", fmt.Errorf("mcpconnect: decode cursor: invalid format")
	}
	var micro int64
	if _, err := fmt.Sscanf(parts[0], "%d", &micro); err != nil {
		return time.Time{}, "", fmt.Errorf("mcpconnect: decode cursor: parse timestamp: %w", err)
	}
	return time.UnixMicro(micro), parts[1], nil
}

// ─── HTTP handlers ──────────────────────────────────────────────────────────

// ListMyActionLog handles GET /api/mcp-action-log — the activity-log page's
// paginated feed of the caller's own connected AI's tool calls. Never
// org-wide: every query is scoped to claims.UserID, so one user can never
// see another's AI activity.
func (rt *Router) ListMyActionLog(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	cursorCreatedAt, cursorID, err := decodeActionLogCursor(r.URL.Query().Get("cursor"))
	if err != nil {
		cursorID = ""
	}

	entries, err := rt.repo.ListActionLog(r.Context(), claims.UserID, cursorCreatedAt, cursorID, limit+1)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to fetch activity log.")
		return
	}

	page := ActionLogPage{Entries: entries}
	if page.Entries == nil {
		page.Entries = []ActionLogEntry{}
	}
	if len(entries) > limit {
		page.Entries = entries[:limit]
		last := page.Entries[limit-1]
		page.NextCursor = encodeActionLogCursor(last.CreatedAt, last.ID)
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// RevertActionLogEntry handles POST /api/mcp-action-log/{entryID}/revert.
// Scoped to claims.UserID at the fetch step, so an entryID belonging to
// another user 404s rather than confirming it exists. Reconstructs an
// mcpIdentity from the caller's own session claims rather than an actual MCP
// bearer token — this endpoint is only ever called by our own frontend, on
// the connected student's behalf, never by an external MCP client.
func (rt *Router) RevertActionLogEntry(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	entryID := chi.URLParam(r, "entryID")

	entry, err := rt.repo.GetActionLogEntry(r.Context(), claims.UserID, entryID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "Activity log entry not found.")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "Failed to load activity log entry.")
		return
	}
	if !entry.Revertible {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "This action can't be reverted.")
		return
	}
	if entry.RevertedAt != nil {
		httputil.WriteError(w, http.StatusConflict, "This action was already reverted.")
		return
	}

	tool, ok := findTool(entry.ToolName)
	if !ok || tool.Revert == nil {
		httputil.WriteError(w, http.StatusUnprocessableEntity, "This action can't be reverted.")
		return
	}

	id := mcpIdentity{OrgID: claims.OrgID, UserID: claims.UserID, ConnectionID: entry.ConnectionID}
	if err := tool.Revert(r.Context(), rt, id, entry); err != nil {
		httputil.WriteError(w, http.StatusUnprocessableEntity, err.Error())
		return
	}

	reverted, err := rt.repo.MarkReverted(r.Context(), entryID, claims.UserID)
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "Reverted, but failed to record it — refresh to check current state.")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, reverted)
}

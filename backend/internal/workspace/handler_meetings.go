package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ListMeetings is GET …/meetings.
func (h *Handler) ListMeetings(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListMeetings(r.Context(), pc, httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// ScheduleMeeting is POST …/meetings.
func (h *Handler) ScheduleMeeting(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req ScheduleMeetingRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	meeting, err := h.service.ScheduleMeeting(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, meeting)
}

// RecordAttendance is PUT …/meetings/{eventID}/attendance.
func (h *Handler) RecordAttendance(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req RecordAttendanceRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	if err := h.service.RecordAttendance(r.Context(), pc, chi.URLParam(r, "eventID"), req); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]any{})
}

// ConvertActionItem is POST …/meetings/{eventID}/action-items.
func (h *Handler) ConvertActionItem(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req ActionItemRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	result, err := h.service.ConvertActionItem(r.Context(), pc, chi.URLParam(r, "eventID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// ListStandups is GET …/standups.
func (h *Handler) ListStandups(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	standups, err := h.service.ListStandups(r.Context(), pc, httputil.QueryStr(r, "day"))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, standups)
}

// PostStandup is PUT …/standups.
func (h *Handler) PostStandup(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req PostStandupRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	standup, err := h.service.PostStandup(r.Context(), pc, req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, standup)
}

package workspace

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// ListTimeLogs is GET …/time-logs?item=&user=&cursor= (viewer).
func (h *Handler) ListTimeLogs(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	page, err := h.service.ListTimeLogs(r.Context(), pc,
		httputil.QueryStr(r, "item"), httputil.QueryStr(r, "user"),
		httputil.QueryStr(r, "cursor"), httputil.QueryIntPositive(r, "limit", PageSizeDefault))
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, page)
}

// LogTime is POST …/items/{itemID}/time-logs (member, StatusesWork).
func (h *Handler) LogTime(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req TimeLogRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	log, err := h.service.LogTime(r.Context(), pc, chi.URLParam(r, "itemID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusCreated, log)
}

// UpdateTimeLog is PATCH …/time-logs/{logID} (member, StatusesWork).
func (h *Handler) UpdateTimeLog(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	var req TimeLogRequest
	if !httputil.DecodeJSON(w, r, &req) {
		return
	}
	log, err := h.service.UpdateTimeLog(r.Context(), pc, chi.URLParam(r, "logID"), req)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, log)
}

// DeleteTimeLog is DELETE …/time-logs/{logID} (member, StatusesWork).
func (h *Handler) DeleteTimeLog(w http.ResponseWriter, r *http.Request) {
	pc, ok := projectCtxOr500(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteTimeLog(r.Context(), pc, chi.URLParam(r, "logID")); err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

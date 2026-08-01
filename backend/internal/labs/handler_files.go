package labs

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/mindforge/backend/internal/httputil"
)

// HandleListFiles returns every file/directory under the session's workdir.
//
//	GET /api/labs/sessions/{sessionId}/files
//
// Response: {"data": [{"path": "deployment.yaml", "type": "file"}, ...]}
func (h *Handler) HandleListFiles(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	entries, err := h.service.ListFiles(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, entries)
}

// HandleReadFile returns the content of one file.
//
//	GET /api/labs/sessions/{sessionId}/files/read?path=deployment.yaml
//
// Response: {"data": {"content": "..."}}
func (h *Handler) HandleReadFile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")
	path := r.URL.Query().Get("path")

	content, err := h.service.ReadFile(r.Context(), sessionID, claims.UserID, path)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"content": content})
}

// HandleWriteFile creates or overwrites a file.
//
//	PUT /api/labs/sessions/{sessionId}/files
//	Body: {"path": "deployment.yaml", "content": "..."}
//
// Response: {"data": {"ok": true}}
func (h *Handler) HandleWriteFile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	// Bound the request body before it's ever decoded — WriteFile itself
	// rejects content over MaxWriteFileBytes too, but that check only runs
	// after json.Decoder has already buffered the whole body into memory.
	// The +1KB headroom covers the {"path":...,"content":...} JSON envelope
	// around the content itself.
	r.Body = http.MaxBytesReader(w, r.Body, MaxWriteFileBytes+1024)

	var body struct {
		Path    string `json:"path"`
		Content string `json:"content"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	if err := h.service.WriteFile(r.Context(), sessionID, claims.UserID, body.Path, body.Content); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// HandleCreateDirectory creates an empty directory.
//
//	POST /api/labs/sessions/{sessionId}/files/mkdir
//	Body: {"path": "manifests"}
//
// Response: {"data": {"ok": true}}
func (h *Handler) HandleCreateDirectory(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	var body struct {
		Path string `json:"path"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	if err := h.service.CreateDirectory(r.Context(), sessionID, claims.UserID, body.Path); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// HandleRenameFile moves/renames a file.
//
//	POST /api/labs/sessions/{sessionId}/files/rename
//	Body: {"from": "old.yaml", "to": "new.yaml"}
//
// Response: {"data": {"ok": true}}
func (h *Handler) HandleRenameFile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	var body struct {
		From string `json:"from"`
		To   string `json:"to"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	if err := h.service.RenameFile(r.Context(), sessionID, claims.UserID, body.From, body.To); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// HandleDeleteFile removes a file.
//
//	DELETE /api/labs/sessions/{sessionId}/files?path=deployment.yaml
//
// Response: {"data": {"ok": true}}
func (h *Handler) HandleDeleteFile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")
	path := r.URL.Query().Get("path")

	if err := h.service.DeleteFile(r.Context(), sessionID, claims.UserID, path); err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// HandleValidateFile runs `kubectl apply --dry-run=server` against a
// manifest already in the workdir.
//
//	POST /api/labs/sessions/{sessionId}/files/validate
//	Body: {"path": "deployment.yaml"}
//
// Response: {"data": {"valid": bool, "stdout": "...", "stderr": "..."}}
func (h *Handler) HandleValidateFile(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	var body struct {
		Path string `json:"path"`
	}
	if !decodeJSON(w, r, &body) {
		return
	}

	result, err := h.service.ValidateFile(r.Context(), sessionID, claims.UserID, body.Path)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, result)
}

// HandleGetResources runs a broad `kubectl get -A -o json` and returns the
// raw result — refresh-on-demand only, no watch/stream.
//
//	GET /api/labs/sessions/{sessionId}/resources
//
// Response: {"data": <raw kubectl List JSON as returned by the apiserver>}
func (h *Handler) HandleGetResources(w http.ResponseWriter, r *http.Request) {
	claims, ok := ctxClaims(w, r)
	if !ok {
		return
	}
	sessionID := chi.URLParam(r, "sessionId")

	resources, err := h.service.GetResources(r.Context(), sessionID, claims.UserID)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	httputil.WriteJSON(w, http.StatusOK, resources)
}

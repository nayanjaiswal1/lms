package gitlab

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// webhookEnvelope is the minimal subset every GitLab project-hook payload
// shares — enough to resolve which installation/team this delivery belongs
// to before doing anything else. Full dispatch happens later, in
// Service.IngestEvent, against the raw payload stored as-is.
type webhookEnvelope struct {
	Project struct {
		ID int64 `json:"id"`
	} `json:"project"`
}

// maxWebhookBodyBytes caps the request body read — a real GitLab payload
// (even a push with a few hundred commits) is nowhere near this; it exists
// only to bound a malformed/malicious request, not real traffic.
const maxWebhookBodyBytes = 5 << 20 // 5MB

// Webhook handles POST /api/gitlab/webhook — GitLab's per-project activity
// hook (push/merge_request/note/pipeline/issue events), registered by
// service_provision.go's registerTeamWebhook during team provisioning.
// Public route (see RegisterPublicRoutes): authenticated via X-Gitlab-Token,
// not a session, since GitLab itself is the caller, never a logged-in
// browser. Per kind-herding-cookie.md §4, this does only the minimal
// synchronous work — verify token, dedupe-insert, enqueue — and always
// returns fast, since GitLab disables a hook that times out or errors
// repeatedly.
func (h *Handler) Webhook(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, maxWebhookBodyBytes))
	if err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "Could not read request body.")
		return
	}

	var env webhookEnvelope
	if jsonErr := json.Unmarshal(body, &env); jsonErr != nil || env.Project.ID == 0 {
		// A payload we can't parse or attribute to a project is simply
		// nothing to act on — still 2xx so GitLab never disables the hook
		// over it (see doc comment above).
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}

	eventType := r.Header.Get("X-Gitlab-Event")
	eventUUID := r.Header.Get("X-Gitlab-Event-UUID")
	if eventType == "" || eventUUID == "" {
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}
	token := r.Header.Get("X-Gitlab-Token")

	err = h.service.HandleWebhook(r.Context(), env.Project.ID, eventType, eventUUID, token, body)
	if err != nil {
		if errors.Is(err, ErrInvalidWebhookToken) {
			httputil.WriteError(w, http.StatusUnauthorized, "Invalid webhook token.")
			return
		}
		// Any other failure (DB hiccup, etc.) is logged inside HandleWebhook's
		// callers via the job/repo layers; still answered 200 so GitLab
		// doesn't disable the hook over a transient backend issue — the next
		// delivery (or the poll_sync sweep) recovers it.
		httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "error"})
		return
	}
	httputil.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

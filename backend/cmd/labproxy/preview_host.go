package main

import (
	"net/http"
	"strings"
)

// previewTokenCookieName is the __Host-prefixed, per-origin cookie that
// carries the preview token once a browser has completed the handshake on a
// preview subdomain (see ServePreviewAuth). __Host- is browser-enforced:
// Secure, Path=/, and no Domain attribute — so it is genuinely host-only to
// one "p{port}-{sessionID}.{previewDomain}" origin. Two ports (or two
// sessions) previewed simultaneously are two distinct origins with two
// independent cookies — this is the fix for the old design's single shared
// port cookie, which could only resolve one port's absolute-path assets at a
// time (ponytail: "upgrade: subdomain-per-port routing").
const previewTokenCookieName = "__Host-mf_preview_token"

// ServePreviewAuth is the preview subdomain's one-time handshake:
// GET /__mf/preview-auth?t={token}&next={path}, reached only via ServePreview's
// redirect. It re-validates the token and requires the token's own session
// (claims.SessionID) to equal *this subdomain's* embedded session ID — the
// mismatch check lives inside previewTarget — which is exactly what stops a
// token minted for session A being used to mint a cookie on session B's
// preview host: without this check, hitting
// https://pX-B.<domain>/__mf/preview-auth?t=<session-A-token> would happily
// set session A's token as B's cookie. On success it sets the per-origin
// cookie and redirects to next.
func (h *ProxyHandler) ServePreviewAuth(w http.ResponseWriter, r *http.Request, port int, sessionID string) {
	if h.draining.Load() {
		http.Error(w, "service draining", http.StatusServiceUnavailable)
		return
	}

	token := r.URL.Query().Get("t")
	if token == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}
	next := r.URL.Query().Get("next")
	if next == "" || !strings.HasPrefix(next, "/") || strings.HasPrefix(next, "//") {
		http.Error(w, "invalid redirect target", http.StatusBadRequest)
		return
	}

	_, _, _, status, msg := h.previewTarget(r, token, port, sessionID)
	if status != 0 {
		http.Error(w, msg, status)
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     previewTokenCookieName,
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		// Session cookie on purpose: the token inside expires on its own
		// (5-minute JWT); the frontend re-mints and reloads the iframe with
		// a fresh token, which re-runs this whole handshake and re-sets this
		// cookie. Secure:true plus the __Host- name prefix requires a secure
		// context — browsers treat http://localhost and http://*.localhost
		// as secure contexts regardless of scheme, so this also works
		// unmodified against dev's Caddyfile.dev (*.localhost, plain :80).
		// No Domain attribute (the __Host- prefix forbids one) is what makes
		// this cookie host-only to this one preview origin.
	})
	// A previewed app's page could try to leak its full preview URL (which
	// embeds the session token in ServePreviewAuth's query string a moment
	// ago, and always embeds the raw session ID in the Host) via the
	// Referer header on outbound links/requests; no-referrer drops it.
	w.Header().Set("Referrer-Policy", "no-referrer")
	http.Redirect(w, r, next, http.StatusFound)
}

// ServePreviewPassthrough handles every request to a preview subdomain other
// than /__mf/preview-auth: ordinary host-based reverse proxying, cookie
// authenticated, full path passthrough — no path-based port parsing, because
// the port and session already came from the Host header (port, sessionID
// are parsed by splitPreviewHost in main.go's router before either preview
// handler is reached). This is what replaces the old ServePreviewAsset
// catch-all: with one real origin per port+session instead of a shared one,
// ordinary same-origin requests — relative or absolute path, HTML document
// or subresource — just resolve correctly on their own.
func (h *ProxyHandler) ServePreviewPassthrough(w http.ResponseWriter, r *http.Request, port int, sessionID string) {
	if h.draining.Load() {
		http.Error(w, "service draining", http.StatusServiceUnavailable)
		return
	}

	cookie, err := r.Cookie(previewTokenCookieName)
	if err != nil || cookie.Value == "" {
		http.Error(w, "missing preview session — reload the preview", http.StatusUnauthorized)
		return
	}

	target, _, _, status, msg := h.previewTarget(r, cookie.Value, port, sessionID)
	if status != 0 {
		http.Error(w, msg, status)
		return
	}

	h.proxyPreview(w, r, target, r.URL.Path, r.URL.Path == "/")
}

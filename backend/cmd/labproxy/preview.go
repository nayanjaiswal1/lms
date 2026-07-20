package main

import (
	"fmt"
	"html"
	"io"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os/exec"
	"strconv"
	"strings"
)

// previewCookieName carries the preview token for absolute-path subresource
// requests. The lab app inside the container serves absolute URLs
// (/static/app.css, /@vite/client, …) that escape the /preview/{token}/
// prefix; those land on ServePreviewAsset, which resolves the session from
// this cookie instead. SameSite=Lax works because SameSite ignores ports:
// the app on :3000 embedding labproxy on :8081 of the same host is
// same-site, in dev (localhost) and in prod (same registrable domain) alike.
const previewCookieName = "mf_preview_token"

// previewCookiePortName carries the explicit preview port alongside the token
// cookie, so absolute-path subresource requests resolve against the same
// container port their document was served from.
// ponytail: one shared port cookie ⇒ only one port's absolute-path assets
// resolve at a time; upgrade path is subdomain-per-port routing.
const previewCookiePortName = "mf_preview_port"

// ttydPort is the container port labproxy's terminal path already owns; the
// preview proxy must never route HTTP traffic to it.
const ttydPort = 7681

// splitPreviewPort peeks at the path remainder after the token segment: an
// all-digits first segment is an explicit container port (sandbox multi-port
// previews), anything else means "use the lab's configured preview_port".
// Returns the port (0 = not specified) and the path with the port stripped.
// ponytail: a single-port app serving an all-digits top-level path would be
// misread as a port request — acceptable; subdomain-per-port is the upgrade.
func splitPreviewPort(path string) (int, string) {
	seg, rest, _ := strings.Cut(path, "/")
	port, err := strconv.Atoi(seg)
	if err != nil || seg == "" || port <= 0 {
		return 0, path
	}
	return port, rest
}

// validPreviewPort reports whether an explicitly requested port may be
// proxied to: any real TCP port except ttyd's.
func validPreviewPort(port int) bool {
	return port >= 1 && port <= 65535 && port != ttydPort
}

// previewTarget validates a preview token and resolves the container URL the
// request must be proxied to. reqPort > 0 selects an explicit container port
// (validated here); reqPort == 0 falls back to the lab's configured
// preview_port. Returns a non-nil *url.URL on success; otherwise the HTTP
// status and message the caller should write.
func (h *ProxyHandler) previewTarget(r *http.Request, tokenStr string, reqPort int) (*url.URL, int, string) {
	claims, err := validateWSToken(tokenStr, h.jwtSecret, h.jwtIssuer)
	if err != nil {
		return nil, http.StatusUnauthorized, "unauthorized"
	}

	var sess labSession
	var previewPort int
	err = h.pool.QueryRow(r.Context(),
		`SELECT s.id, s.user_id, s.status, s.container_id, s.container_host, l.preview_port
		 FROM lab_sessions s
		 JOIN lab_definitions l ON l.id = s.lab_id
		 WHERE s.id=$1`,
		claims.SessionID,
	).Scan(&sess.ID, &sess.UserID, &sess.Status, &sess.ContainerID, &sess.ContainerHost, &previewPort)
	if err != nil {
		return nil, http.StatusNotFound, "session not found"
	}

	// IDOR guard: token's user_id must match the session's owner.
	if sess.UserID != claims.UserID {
		return nil, http.StatusForbidden, "forbidden"
	}
	port := previewPort
	if reqPort > 0 {
		if !validPreviewPort(reqPort) {
			return nil, http.StatusBadRequest, "invalid preview port"
		}
		port = reqPort
	} else if previewPort <= 0 {
		return nil, http.StatusNotFound, "lab has no app preview"
	}

	// Same unpause-on-access behavior as the terminal WS path.
	if sess.Status == "paused" {
		if h.labsRuntime != "kubernetes" && sess.ContainerID != nil && *sess.ContainerID != "" {
			if unpauseErr := exec.CommandContext(r.Context(),
				"docker", "unpause", *sess.ContainerID).Run(); unpauseErr != nil {
				slog.Warn("labproxy: preview docker unpause failed",
					"container", *sess.ContainerID, "error", unpauseErr)
			}
		}
		if _, execErr := h.pool.Exec(r.Context(),
			`UPDATE lab_sessions SET status='running', last_active_at=now() WHERE id=$1`,
			sess.ID); execErr != nil {
			slog.Error("labproxy: preview unpause status update", "session", sess.ID, "error", execErr)
			return nil, http.StatusInternalServerError, "internal error"
		}
		sess.Status = "running"
	}
	if sess.Status != "running" {
		return nil, http.StatusConflict, "session not running"
	}
	if sess.ContainerHost == nil || *sess.ContainerHost == "" {
		return nil, http.StatusServiceUnavailable, "container not ready"
	}

	// container_host is "{containerID12}:7681" (the ttyd port) — same
	// container, different port for the app.
	host, _, found := strings.Cut(*sess.ContainerHost, ":")
	if !found || host == "" {
		return nil, http.StatusServiceUnavailable, "container host malformed"
	}
	return &url.URL{Scheme: "http", Host: fmt.Sprintf("%s:%d", host, port)}, 0, ""
}

// maxWrappedJSONBytes caps how much of a JSON document response is inlined
// into the wrapper page; larger bodies are truncated with a marker.
const maxWrappedJSONBytes = 1 << 20

// shouldWrapJSONDocument reports whether a proxied response is a JSON
// document being loaded as the preview iframe's page. Chrome cannot display
// raw JSON in a subframe — its JSON viewer is top-level only, so it falls
// back to a file download, which the sandboxed iframe blocks with "This
// content is blocked". isDocRoot is true only for ServePreview requests
// whose remaining path is empty — exactly the URL the frontend puts in the
// iframe/new-tab — so the app's own fetch/XHR responses (absolute paths via
// ServePreviewAsset, relative paths with a non-empty remainder) are never
// rewritten. Sec-Fetch-Dest can't be the signal here: Chrome omits fetch
// metadata on plain-http origins like the dev proxy.
func shouldWrapJSONDocument(isDocRoot bool, contentType string, status int) bool {
	if !isDocRoot {
		return false
	}
	if status < 200 || status >= 300 {
		return false
	}
	return strings.HasPrefix(contentType, "application/json")
}

// proxyPreview reverse-proxies one request to the container's app port.
// httputil.ReverseProxy passes WebSocket upgrades through (Vite HMR).
// When isDocRoot is set (the iframe's document URL), JSON responses are
// wrapped in a minimal HTML page so API labs show their response in the
// preview pane instead of Chrome's blocked-download message, and the
// response is marked no-store so a pre-wrap cache entry can't stick.
func (h *ProxyHandler) proxyPreview(w http.ResponseWriter, r *http.Request, target *url.URL, path string, isDocRoot bool) {
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(target)
			pr.Out.URL.Path = path
			pr.Out.Host = target.Host
		},
		ModifyResponse: func(resp *http.Response) error {
			if isDocRoot {
				resp.Header.Set("Cache-Control", "no-store")
			}
			if !shouldWrapJSONDocument(
				isDocRoot,
				resp.Header.Get("Content-Type"),
				resp.StatusCode,
			) {
				return nil
			}
			body, err := io.ReadAll(io.LimitReader(resp.Body, maxWrappedJSONBytes))
			if err != nil {
				return fmt.Errorf("labproxy: read json document body: %w", err)
			}
			_ = resp.Body.Close()
			text := string(body)
			if len(body) == maxWrappedJSONBytes {
				text += "\n… (truncated)"
			}
			page := `<!doctype html><meta charset="utf-8"><pre style="white-space:pre-wrap;word-break:break-word;font:13px/1.6 monospace;margin:16px">` +
				html.EscapeString(text) + `</pre>`
			resp.Body = io.NopCloser(strings.NewReader(page))
			resp.ContentLength = int64(len(page))
			resp.Header.Set("Content-Length", strconv.Itoa(len(page)))
			resp.Header.Set("Content-Type", "text/html; charset=utf-8")
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			slog.Warn("labproxy: preview upstream error", "target", target.Host, "error", err)
			http.Error(w, "app not reachable — is it still starting?", http.StatusBadGateway)
		},
	}
	proxy.ServeHTTP(w, r)
}

// ServePreview handles /preview/{token}/{path...} — the iframe's document
// URL. It authenticates the token from the path, drops the preview cookie so
// the app's absolute-path subresources can be resolved by ServePreviewAsset,
// and proxies to the container app port.
func (h *ProxyHandler) ServePreview(w http.ResponseWriter, r *http.Request) {
	if h.draining.Load() {
		http.Error(w, "service draining", http.StatusServiceUnavailable)
		return
	}

	rest := strings.TrimPrefix(r.URL.Path, "/preview/")
	token, path, _ := strings.Cut(rest, "/")
	if token == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}
	reqPort, path := splitPreviewPort(path)

	target, status, msg := h.previewTarget(r, token, reqPort)
	if target == nil {
		http.Error(w, msg, status)
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     previewCookieName,
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		// Session cookie on purpose: the token inside expires on its own
		// (5-minute JWT); the frontend re-mints and reloads the iframe with
		// a fresh token, which re-sets this cookie.
	})
	// Port cookie mirrors the document's explicit port (cleared when the lab's
	// configured preview_port is in use) so ServePreviewAsset routes this
	// document's absolute-path subresources to the same container port.
	portValue := ""
	if reqPort > 0 {
		portValue = strconv.Itoa(reqPort)
	}
	http.SetCookie(w, &http.Cookie{
		Name:     previewCookiePortName,
		Value:    portValue,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})

	h.proxyPreview(w, r, target, "/"+path, path == "")
}

// ServePreviewAsset is the catch-all for absolute-path subresource requests
// escaping the /preview/{token}/ prefix (stylesheets, module scripts, HMR
// websockets). The session is resolved from the preview cookie set by
// ServePreview; without it there is nothing to route to.
func (h *ProxyHandler) ServePreviewAsset(w http.ResponseWriter, r *http.Request) {
	if h.draining.Load() {
		http.Error(w, "service draining", http.StatusServiceUnavailable)
		return
	}

	cookie, err := r.Cookie(previewCookieName)
	if err != nil || cookie.Value == "" {
		http.NotFound(w, r)
		return
	}
	reqPort := 0
	if portCookie, pErr := r.Cookie(previewCookiePortName); pErr == nil && portCookie.Value != "" {
		if p, aErr := strconv.Atoi(portCookie.Value); aErr == nil {
			reqPort = p
		}
	}

	target, status, msg := h.previewTarget(r, cookie.Value, reqPort)
	if target == nil {
		http.Error(w, msg, status)
		return
	}

	h.proxyPreview(w, r, target, r.URL.Path, false)
}

package main

import (
	"fmt"
	"html"
	"io"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
)

// ttydPort is the container port labproxy's terminal path already owns; the
// preview proxy must never route HTTP traffic to it.
const ttydPort = 7681

// splitEntryPort peeks at the path remainder after the token segment in the
// one-shot /preview/{token}/{port}/{path} entry URL: an all-digits first
// segment is the frontend's explicit container port (use-lab-preview.ts only
// ever sends one for multi-port labs), anything else is passed straight
// through as the initial path to hand off as ServePreviewAuth's "next".
//
// This used to be ambiguous (ponytail: an all-digits app path segment could
// be misread as a port) because the old design re-entered this same parser
// on every relative link the previewed app followed. That's no longer true:
// ServePreview now redirects to a preview subdomain exactly once per token,
// and every request after that — including the app's own relative-link
// navigation — resolves directly against the subdomain via ordinary
// host-based routing (ServePreviewPassthrough in preview_host.go) and never
// re-enters this function. Subdomain-per-port routing was the named upgrade;
// this is it.
func splitEntryPort(path string) (int, string) {
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
// preview_port. wantSessionID, when non-empty, must equal the token's own
// claims.SessionID or the request is rejected with 403 — this is the guard
// that stops a token minted for one session being replayed against a
// different session's preview subdomain (see preview_host.go). Pass ""
// to skip that check (used only by ServePreview, before any subdomain host
// exists to compare against).
//
// Returns a non-nil *url.URL and the resolved port + session ID on success;
// otherwise a zero URL, the HTTP status, and message the caller should write.
func (h *ProxyHandler) previewTarget(r *http.Request, tokenStr string, reqPort int, wantSessionID string) (target *url.URL, resolvedPort int, sessionID string, status int, msg string) {
	claims, err := validateWSToken(tokenStr, h.jwtSecret, h.jwtIssuer)
	if err != nil {
		return nil, 0, "", http.StatusUnauthorized, "unauthorized"
	}
	if !h.tokenIsLive(r.Context(), tokenStr) {
		return nil, 0, "", http.StatusUnauthorized, "token revoked or expired"
	}
	if wantSessionID != "" && claims.SessionID != wantSessionID {
		return nil, 0, "", http.StatusForbidden, "token session mismatch"
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
		return nil, 0, "", http.StatusNotFound, "session not found"
	}

	// IDOR guard: token's user_id must match the session's owner.
	if sess.UserID != claims.UserID {
		return nil, 0, "", http.StatusForbidden, "forbidden"
	}
	port := previewPort
	if reqPort > 0 {
		if !validPreviewPort(reqPort) {
			return nil, 0, "", http.StatusBadRequest, "invalid preview port"
		}
		port = reqPort
	} else if previewPort <= 0 {
		return nil, 0, "", http.StatusNotFound, "lab has no app preview"
	}

	// Resuming a paused container is the main API's job (labs.Service.
	// MintWSToken, done before this token was ever handed out) — see
	// proxy.go's ServeHTTP for the same reasoning. A still-paused session
	// here means the token is stale; the client re-mints (use-lab-preview.ts
	// always fetches a fresh token before setting the iframe src) rather than
	// this process attempting a resume it has no credentials to perform.
	if sess.Status != "running" {
		return nil, 0, "", http.StatusConflict, "session not running — mint a fresh preview token"
	}
	if sess.ContainerHost == nil || *sess.ContainerHost == "" {
		return nil, 0, "", http.StatusServiceUnavailable, "container not ready"
	}

	// container_host is "{containerID12}:7681" (the ttyd port) — same
	// container, different port for the app.
	host, _, found := strings.Cut(*sess.ContainerHost, ":")
	if !found || host == "" {
		return nil, 0, "", http.StatusServiceUnavailable, "container host malformed"
	}
	return &url.URL{Scheme: "http", Host: fmt.Sprintf("%s:%d", host, port)}, port, claims.SessionID, 0, ""
}

// maxWrappedJSONBytes caps how much of a JSON document response is inlined
// into the wrapper page; larger bodies are truncated with a marker.
const maxWrappedJSONBytes = 1 << 20

// shouldWrapJSONDocument reports whether a proxied response is a JSON
// document being loaded as the preview iframe's page. Chrome cannot display
// raw JSON in a subframe — its JSON viewer is top-level only, so it falls
// back to a file download, which the sandboxed iframe blocks with "This
// content is blocked". isDocRoot is true only when the proxied request path
// is exactly "/" — the preview subdomain's document root, which is what the
// frontend's iframe always navigates to first (use-lab-preview.ts never
// appends a path) — so the app's own fetch/XHR responses (ServePreviewPassthrough
// requests to any other path) are never rewritten. Sec-Fetch-Dest can't be
// the signal here: Chrome omits fetch metadata on plain-http origins like the
// dev proxy.
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
			stripSetCookieDomain(resp)
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

// stripSetCookieDomain removes the Domain attribute from every upstream
// Set-Cookie header before it reaches the browser. Preview subdomains and the
// main app now share a registrable domain (LABPROXY_PREVIEW_DOMAIN is
// documented as a subdomain of DOMAIN, e.g. labs.<DOMAIN>, so SameSite=Lax
// still works for the ServePreview→ServePreviewAuth redirect) — which also
// means a malicious previewed app could otherwise set a cookie with
// Domain=<DOMAIN> and have it ride along to the real app on every request.
// Stripping Domain forces every upstream cookie host-only to the preview
// subdomain that set it, same as previewTokenCookieName's own __Host- cookie.
func stripSetCookieDomain(resp *http.Response) {
	cookies := resp.Header.Values("Set-Cookie")
	if len(cookies) == 0 {
		return
	}
	resp.Header.Del("Set-Cookie")
	for _, raw := range cookies {
		attrs := strings.Split(raw, ";")
		kept := attrs[:1] // name=value always kept
		for _, attr := range attrs[1:] {
			if strings.HasPrefix(strings.ToLower(strings.TrimSpace(attr)), "domain=") {
				continue
			}
			kept = append(kept, attr)
		}
		resp.Header.Add("Set-Cookie", strings.Join(kept, ";"))
	}
}

// ServePreview handles /preview/{token}/{port}/{path...} — the frontend
// iframe's one-shot entry URL (use-lab-preview.ts). It validates the token,
// resolves the preview port (explicit segment, or the lab's configured
// preview_port when the segment is omitted — see splitEntryPort and
// previewTarget), and redirects the browser to that port+session's preview
// subdomain, where ServePreviewAuth (preview_host.go) completes the
// handshake. This replaces the old single-origin design where this handler
// both authenticated *and* served the document; now it only ever issues one
// redirect per token, and never proxies anything itself.
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
	reqPort, path := splitEntryPort(path)

	// wantSessionID is "" here — there is no subdomain host yet to compare
	// the token's session against; that check happens in ServePreviewAuth
	// once the browser lands on the subdomain this redirect points to.
	_, resolvedPort, sessionID, status, msg := h.previewTarget(r, token, reqPort, "")
	if status != 0 {
		http.Error(w, msg, status)
		return
	}

	// Caddy/Traefik terminate the public TLS connection and proxy to
	// labproxy over plain HTTP internally, so r.TLS is never set here even
	// in prod — X-Forwarded-Proto (set by both automatically) is the real
	// signal. Dev's Caddyfile.dev has no TLS at all (LABPROXY_PREVIEW_DOMAIN
	// =localhost, plain :80), so it never sends "https"; prod always does.
	scheme := "https"
	if r.Header.Get("X-Forwarded-Proto") == "http" {
		scheme = "http"
	}

	next := "/" + path
	target := url.URL{
		Scheme: scheme,
		Host:   fmt.Sprintf("p%d-%s.%s", resolvedPort, sessionID, h.previewDomain),
		Path:   "/__mf/preview-auth",
		RawQuery: url.Values{
			"t":    {token},
			"next": {next},
		}.Encode(),
	}
	http.Redirect(w, r, target.String(), http.StatusFound)
}

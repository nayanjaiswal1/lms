package main

import (
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"github.com/google/uuid"
)

// idePathCookiePrefix names the per-session cookie that carries the preview
// token for path-mode IDE requests (ServeIDEPath).
const idePathCookiePrefix = "mf_ide_"

// ServeIDEPath serves the browser IDE (and only the IDE) on the main origin:
// /ide/{sessionID}/{port}/{path...}. It exists for deployments with no
// wildcard DNS/TLS (e.g. a Tailscale hostname), where the per-port preview
// subdomain of ServePreview cannot resolve. openvscode-server uses relative
// URLs, so it works under this prefix.
//
// Auth: a "t" query token (entry URL and cookie-refresh) is validated and
// stored in an HttpOnly cookie; later requests (assets, WebSocket) use the
// cookie. Ports other than the session's ide_port are rejected: arbitrary
// previewed apps must keep their isolated subdomain origin.
func (h *ProxyHandler) ServeIDEPath(w http.ResponseWriter, r *http.Request) {
	if h.rejectIfDraining(w) {
		return
	}
	sidStr, rest, _ := strings.Cut(strings.TrimPrefix(r.URL.Path, "/ide/"), "/")
	portStr, path, _ := strings.Cut(rest, "/")
	sid, err := uuid.Parse(sidStr)
	port, perr := strconv.Atoi(portStr)
	if err != nil || perr != nil || !validPreviewPort(port) {
		writeJSONError(w, http.StatusNotFound, "not found")
		return
	}
	sessionID := sid.String()
	cookieName := idePathCookiePrefix + sessionID

	token := r.URL.Query().Get("t")
	fromQuery := token != ""
	if !fromQuery {
		c, cerr := r.Cookie(cookieName)
		if cerr != nil || c.Value == "" {
			writeJSONError(w, http.StatusUnauthorized, "missing IDE session — reload the IDE")
			return
		}
		token = c.Value
	}

	target, _, _, ideToken, status, msg := h.previewTarget(r, token, port, sessionID)
	if status != 0 {
		writeJSONError(w, status, msg)
		return
	}
	if ideToken == "" {
		writeJSONError(w, http.StatusForbidden, "not the IDE port")
		return
	}

	if fromQuery {
		http.SetCookie(w, &http.Cookie{
			Name:     cookieName,
			Value:    token,
			Path:     "/",
			HttpOnly: true,
			Secure:   true,
			SameSite: http.SameSiteLaxMode,
		})
		if path == "__mf/ok" {
			w.Header().Set("Cache-Control", "no-store")
			w.WriteHeader(http.StatusNoContent)
			return
		}
		q := r.URL.Query()
		q.Del("t")
		r.URL.RawQuery = q.Encode()
	}

	w.Header().Set("Referrer-Policy", "no-referrer")
	// The web-worker extension-host iframe refuses to boot unless it runs on a
	// dedicated hostname (webEndpointUrlTemplate), which path mode cannot give
	// it, and a half-booted one blanks the workbench. Without it the IDE falls
	// back to its in-page host, which works.
	if strings.HasSuffix(path, "/webWorkerExtensionHostIframe.html") {
		writeJSONError(w, http.StatusNotFound, "not available in path mode")
		return
	}
	// Browser-visible base of this IDE; the edge strips only the public prefix
	// (LABPROXY_PUBLIC_PATH_PREFIX, e.g. "/lab-ws"), so labproxy sees /ide/...
	base := h.publicPathPrefix + "/ide/" + sessionID + "/" + portStr
	h.proxyIDE(w, r, target, "/"+path, ideToken, base)
}

// proxyIDE reverse-proxies one request to openvscode-server. Unlike
// proxyPreview it keeps the browser's Host (openvscode derives its remote
// authority from it) and rewrites the workbench HTML so absolute asset paths
// and serverBasePath carry base — openvscode itself believes it is at "/".
func (h *ProxyHandler) proxyIDE(w http.ResponseWriter, r *http.Request, target *url.URL, path, ideToken, base string) {
	isDoc := path == "/"
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			host := pr.In.Host
			pr.SetURL(target)
			pr.Out.URL.Path = path
			pr.Out.Host = host
			injectIDEToken(pr.Out, ideToken)
			if isDoc {
				pr.Out.Header.Del("Accept-Encoding") // body is rewritten below
			}
		},
		ModifyResponse: func(resp *http.Response) error {
			stripSetCookieDomain(resp)
			adaptIDEResponse(resp, http.SameSiteLaxMode)
			if loc := resp.Header.Get("Location"); strings.HasPrefix(loc, "/") && !strings.HasPrefix(loc, "//") {
				resp.Header.Set("Location", base+loc)
			}
			if !isDoc || !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/html") {
				return nil
			}
			body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
			if err != nil {
				return fmt.Errorf("labproxy: read ide document: %w", err)
			}
			_ = resp.Body.Close()
			out := string(body)
			out = strings.ReplaceAll(out, `"/stable-`, `"`+base+`/stable-`)
			out = strings.ReplaceAll(out, `'/stable-`, `'`+base+`/stable-`) // _VSCODE_FILE_ROOT
			out = strings.ReplaceAll(out, `&quot;/stable-`, `&quot;`+base+`/stable-`)
			out = strings.ReplaceAll(out, `&quot;serverBasePath&quot;:&quot;/&quot;`, `&quot;serverBasePath&quot;:&quot;`+base+`&quot;`)
			allowRewrittenInlineScripts(resp.Header, out, base)
			resp.Body = io.NopCloser(strings.NewReader(out))
			resp.ContentLength = int64(len(out))
			resp.Header.Set("Content-Length", strconv.Itoa(len(out)))
			resp.Header.Del("Content-Encoding")
			resp.Header.Set("Cache-Control", "no-store")
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			slog.Warn("labproxy: ide upstream error", "target", target.Host, "error", err)
			writeJSONError(w, http.StatusBadGateway, "IDE not reachable — is it still starting?")
		},
	}
	proxy.ServeHTTP(w, r)
}

var inlineScriptRe = regexp.MustCompile(`(?s)<script>(.*?)</script>`)

// allowRewrittenInlineScripts adds the sha256 of every inline <script> that
// carries base (i.e. was rewritten above) to the CSP script-src: openvscode
// pins its inline scripts by hash, so the edited one is otherwise blocked and
// _VSCODE_FILE_ROOT never gets set.
func allowRewrittenInlineScripts(h http.Header, doc, base string) {
	csp := h.Get("Content-Security-Policy")
	if csp == "" {
		return
	}
	var hashes []string
	for _, m := range inlineScriptRe.FindAllStringSubmatch(doc, -1) {
		if strings.Contains(m[1], base) {
			sum := sha256.Sum256([]byte(m[1]))
			hashes = append(hashes, "'sha256-"+base64.StdEncoding.EncodeToString(sum[:])+"'")
		}
	}
	if len(hashes) > 0 {
		h.Set("Content-Security-Policy", strings.Replace(csp, "script-src ", "script-src "+strings.Join(hashes, " ")+" ", 1))
	}
}

package middleware

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/httputil"
	"github.com/mindforge/backend/internal/netguard"
)

const (
	// CaptchaTokenHeader carries the Cloudflare Turnstile response token.
	CaptchaTokenHeader = "X-Captcha-Token"
	// CaptchaBypassHeader lets the trusted Next.js server (demo login, admin-
	// triggered password reset) call a gated endpoint with no browser widget.
	CaptchaBypassHeader = "X-Captcha-Bypass"

	turnstileVerifyURL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
	turnstileTimeout   = 5 * time.Second
	maxTokenLen        = 2048
)

// TurnstileVerifier validates Turnstile tokens against Cloudflare's siteverify API.
type TurnstileVerifier struct {
	secret    string
	verifyURL string
	client    *http.Client
}

// NewTurnstileVerifier builds a verifier using the SSRF-guarded client.
func NewTurnstileVerifier(secret string) *TurnstileVerifier {
	return &TurnstileVerifier{secret: secret, verifyURL: turnstileVerifyURL, client: netguard.NewHTTPClient(turnstileTimeout)}
}

// Verify reports whether token is a valid, unspent challenge solution. Any
// transport or decoding failure is returned as an error so callers fail closed.
func (v *TurnstileVerifier) Verify(ctx context.Context, token, remoteIP string) (bool, error) {
	form := url.Values{"secret": {v.secret}, "response": {token}}
	if remoteIP != "" {
		form.Set("remoteip", remoteIP)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, v.verifyURL, strings.NewReader(form.Encode()))
	if err != nil {
		return false, fmt.Errorf("turnstile: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := v.client.Do(req)
	if err != nil {
		return false, fmt.Errorf("turnstile: siteverify: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("turnstile: siteverify status %d", resp.StatusCode)
	}
	var out struct {
		Success bool `json:"success"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(nil, resp.Body, 1<<16)).Decode(&out); err != nil {
		return false, fmt.Errorf("turnstile: decode response: %w", err)
	}
	return out.Success, nil
}

// RequireCaptcha gates an unauthenticated, abuse-prone endpoint behind a
// Turnstile challenge. It is a no-op only when TURNSTILE_SECRET_KEY is unset,
// which config.Load permits solely in development. Fails closed: a missing
// token, a rejected token, or an unreachable verifier all refuse the request.
func RequireCaptcha(cfg *config.Config) func(http.Handler) http.Handler {
	return requireCaptcha(cfg, NewTurnstileVerifier(cfg.TurnstileSecretKey))
}

func requireCaptcha(cfg *config.Config, v *TurnstileVerifier) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		if cfg.TurnstileSecretKey == "" {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if b := r.Header.Get(CaptchaBypassHeader); cfg.CaptchaBypassSecret != "" &&
				subtle.ConstantTimeCompare([]byte(b), []byte(cfg.CaptchaBypassSecret)) == 1 {
				next.ServeHTTP(w, r)
				return
			}
			token := r.Header.Get(CaptchaTokenHeader)
			if token == "" || len(token) > maxTokenLen {
				httputil.WriteError(w, http.StatusBadRequest, "Captcha verification required.")
				return
			}
			ok, err := v.Verify(r.Context(), token, hostOnly(r.RemoteAddr))
			if err != nil {
				slog.Error("captcha verification unavailable", "error", err)
				httputil.WriteError(w, http.StatusServiceUnavailable, "Captcha verification unavailable. Please try again.")
				return
			}
			if !ok {
				httputil.WriteError(w, http.StatusBadRequest, "Captcha verification failed. Please try again.")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

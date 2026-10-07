package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/config"
)

func captchaServer(t *testing.T, status int, body string) *TurnstileVerifier {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		if r.PostForm.Get("secret") != "s3cret" || r.PostForm.Get("remoteip") != "203.0.113.9" {
			t.Errorf("unexpected form: %v", r.PostForm)
		}
		if r.PostForm.Get("response") == "bad" {
			_, _ = w.Write([]byte(`{"success":false}`))
			return
		}
		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return &TurnstileVerifier{secret: "s3cret", verifyURL: srv.URL, client: srv.Client()}
}

func TestRequireCaptcha(t *testing.T) {
	cfg := &config.Config{TurnstileSecretKey: "s3cret", CaptchaBypassSecret: "bypass"}
	cases := []struct {
		name    string
		v       *TurnstileVerifier
		headers map[string]string
		want    int
	}{
		{"valid token", captchaServer(t, 200, `{"success":true}`), map[string]string{CaptchaTokenHeader: "ok"}, http.StatusNoContent},
		{"rejected token", captchaServer(t, 200, `{"success":true}`), map[string]string{CaptchaTokenHeader: "bad"}, http.StatusBadRequest},
		{"missing token", captchaServer(t, 200, `{"success":true}`), nil, http.StatusBadRequest},
		{"upstream 500 fails closed", captchaServer(t, 500, `{}`), map[string]string{CaptchaTokenHeader: "ok"}, http.StatusServiceUnavailable},
		{"garbage body fails closed", captchaServer(t, 200, `nope`), map[string]string{CaptchaTokenHeader: "ok"}, http.StatusServiceUnavailable},
		{"bypass secret", captchaServer(t, 500, `{}`), map[string]string{CaptchaBypassHeader: "bypass"}, http.StatusNoContent},
		{"wrong bypass", captchaServer(t, 200, `{"success":true}`), map[string]string{CaptchaBypassHeader: "nope"}, http.StatusBadRequest},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := requireCaptcha(cfg, tc.v)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) }))
			req := httptest.NewRequest(http.MethodPost, "/", nil)
			req.RemoteAddr = "203.0.113.9:4444"
			for k, v := range tc.headers {
				req.Header.Set(k, v)
			}
			rec := httptest.NewRecorder()
			h.ServeHTTP(rec, req)
			if rec.Code != tc.want {
				t.Fatalf("status = %d, want %d", rec.Code, tc.want)
			}
		})
	}
}

func TestRequireCaptchaDisabledWithoutSecret(t *testing.T) {
	h := RequireCaptcha(&config.Config{})(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) }))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/", nil))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d", rec.Code)
	}
}

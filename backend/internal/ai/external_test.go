package ai

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

const (
	aiHangDeadline = 300 * time.Millisecond
	aiHangSlack    = 3 * time.Second
)

// redirectTransport sends every request to target, so the Anthropic provider
// (whose URL is a package constant) can be pointed at an httptest server.
type redirectTransport struct{ target *url.URL }

func (rt redirectTransport) RoundTrip(r *http.Request) (*http.Response, error) {
	r = r.Clone(r.Context())
	r.URL.Scheme, r.URL.Host = rt.target.Scheme, rt.target.Host
	return http.DefaultTransport.RoundTrip(r)
}

type completer interface {
	Complete(context.Context, CompletionRequest) (CompletionResponse, error)
}

func providers(t *testing.T, srv *httptest.Server) map[string]struct {
	p      completer
	prefix string
} {
	t.Helper()
	target, err := url.Parse(srv.URL)
	if err != nil {
		t.Fatalf("parse url: %v", err)
	}
	a := newAnthropicProvider("k", "m")
	a.client = &http.Client{Transport: redirectTransport{target}, Timeout: llmHTTPTimeout}
	return map[string]struct {
		p      completer
		prefix string
	}{
		"anthropic": {a, "ai: anthropic"},
		"gemini":    {newGeminiProvider("k", "m", srv.URL), "ai: gemini"},
	}
}

func TestProvidersErrorOnServerFailure(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "upstream exploded", http.StatusInternalServerError)
	}))
	defer srv.Close()

	for name, tc := range providers(t, srv) {
		t.Run(name, func(t *testing.T) {
			resp, err := tc.p.Complete(context.Background(), CompletionRequest{UserPrompt: "hi"})
			if err == nil {
				t.Fatalf("want error on HTTP 500, got response %+v", resp)
			}
			if !strings.HasPrefix(err.Error(), tc.prefix) {
				t.Fatalf("error %q lacks prefix %q", err, tc.prefix)
			}
			if resp.Content != "" {
				t.Fatalf("content leaked on error: %q", resp.Content)
			}
		})
	}
}

func TestProvidersErrorWhenUpstreamHangs(t *testing.T) {
	release := make(chan struct{})
	srv := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-release:
		}
	}))
	defer srv.Close()
	defer close(release)

	for name, tc := range providers(t, srv) {
		t.Run(name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), aiHangDeadline)
			defer cancel()
			start := time.Now()
			_, err := tc.p.Complete(ctx, CompletionRequest{UserPrompt: "hi"})
			if err == nil {
				t.Fatal("want error when upstream hangs past the deadline")
			}
			if d := time.Since(start); d > aiHangSlack {
				t.Fatalf("returned after %v, want within the context deadline", d)
			}
			if !strings.HasPrefix(err.Error(), tc.prefix+" request") {
				t.Fatalf("error %q lacks wrapped request prefix", err)
			}
		})
	}
}

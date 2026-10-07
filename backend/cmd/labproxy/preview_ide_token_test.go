package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestInjectIDETokenQueryOnlyOnWebSocket(t *testing.T) {
	const token = "derived"
	cases := []struct {
		name      string
		upgrade   string
		wantQuery string
	}{
		{"plain http gets the cookie only", "", ""},
		{"websocket upgrade also gets the query", "websocket", token},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// A client-supplied tkn must never survive.
			req := httptest.NewRequest(http.MethodGet, "/?tkn=student-choice&folder=x", nil)
			req.Header.Set("Cookie", "vscode-tkn=student-choice; other=1")
			if tc.upgrade != "" {
				req.Header.Set("Upgrade", tc.upgrade)
			}
			injectIDEToken(req, token)

			if got := req.URL.Query().Get("tkn"); got != tc.wantQuery {
				t.Errorf("tkn query = %q, want %q", got, tc.wantQuery)
			}
			if got := req.URL.Query().Get("folder"); got != "x" {
				t.Errorf("other query params must be preserved, folder = %q", got)
			}
			cookie, err := req.Cookie("vscode-tkn")
			if err != nil || cookie.Value != token {
				t.Errorf("vscode-tkn cookie = %v (%v), want %q", cookie, err, token)
			}
			if other, err := req.Cookie("other"); err != nil || other.Value != "1" {
				t.Errorf("unrelated cookie lost: %v (%v)", other, err)
			}
		})
	}
}

func TestAdaptIDEResponse(t *testing.T) {
	newResp := func() *http.Response {
		resp := &http.Response{Header: http.Header{}}
		resp.Header.Add("Set-Cookie", "vscode-tkn=abc; Max-Age=604800; SameSite=Lax")
		resp.Header.Add("Set-Cookie", "other=1; SameSite=Lax")
		resp.Header.Set("Location", "/?tkn=abc&folder=x")
		return resp
	}

	lax := newResp()
	adaptIDEResponse(lax, http.SameSiteLaxMode)
	if got := lax.Header.Values("Set-Cookie"); len(got) != 2 || got[0] != "vscode-tkn=abc; Max-Age=604800; SameSite=Lax" {
		t.Errorf("same-site: cookies must pass through untouched, got %v", got)
	}
	if got := lax.Header.Get("Location"); got != "/?folder=x" {
		t.Errorf("Location = %q, want tkn removed", got)
	}

	none := newResp()
	adaptIDEResponse(none, http.SameSiteNoneMode)
	got := none.Header.Values("Set-Cookie")
	if len(got) != 2 || got[0] != "vscode-tkn=abc; Max-Age=604800; SameSite=None; Secure" {
		t.Errorf("cross-site: vscode-tkn must be re-issued SameSite=None; Secure, got %v", got)
	}
	if got[1] != "other=1; SameSite=Lax" {
		t.Errorf("unrelated cookie must be left alone, got %q", got[1])
	}
}

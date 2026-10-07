package main

import (
	"github.com/mindforge/backend/internal/testdomain"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestOriginAllowed(t *testing.T) {
	allowed := parseAllowedOrigins("https://app." + testdomain.Domain + "/, HTTPS://other." + testdomain.Domain)
	check := func(origin string) bool {
		r := httptest.NewRequest("GET", "/ws", nil)
		if origin != "" {
			r.Header.Set("Origin", origin)
		}
		return originAllowed(r, allowed)
	}
	assert.True(t, check(""))
	assert.True(t, check("https://app."+testdomain.Domain))
	assert.True(t, check("https://other."+testdomain.Domain))
	assert.False(t, check("https://evil."+testdomain.Domain))
	assert.False(t, check("http://app."+testdomain.Domain))
	assert.False(t, check("not a url"))

	r := httptest.NewRequest("GET", "/ws", nil)
	r.Header.Set("Origin", "https://app."+testdomain.Domain)
	assert.False(t, originAllowed(r, nil), "empty allowlist fails closed")
}

func TestConnLimiter(t *testing.T) {
	var l connLimiter
	for i := 0; i < maxConnsPerUser; i++ {
		assert.True(t, l.acquire("u"))
	}
	assert.False(t, l.acquire("u"))
	assert.True(t, l.acquire("v"))
	l.release("u")
	assert.True(t, l.acquire("u"))
}

func TestWSTokenFromProtocols(t *testing.T) {
	cases := map[string]string{
		"mf-lab, tok.en-1": "tok.en-1",
		"tok":              "",
		"mf-lab":           "",
		"":                 "",
	}
	for hdr, want := range cases {
		r := httptest.NewRequest("GET", "/ws", nil)
		if hdr != "" {
			r.Header.Set("Sec-WebSocket-Protocol", hdr)
		}
		if got := wsTokenFromProtocols(r); got != want {
			t.Errorf("%q: got %q want %q", hdr, got, want)
		}
	}
}

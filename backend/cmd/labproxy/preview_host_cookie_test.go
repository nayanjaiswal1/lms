package main

import (
	"github.com/mindforge/backend/internal/testdomain"
	"net/http"
	"testing"
)

func TestPreviewCookieSameSite(t *testing.T) {
	cases := map[string]http.SameSite{
		"localhost":                    http.SameSiteNoneMode,
		"preview." + testdomain.Domain: http.SameSiteLaxMode,
	}
	for domain, want := range cases {
		if got := previewCookieSameSite(domain); got != want {
			t.Errorf("previewCookieSameSite(%q) = %v, want %v", domain, got, want)
		}
	}
}

package main

import (
	"net/http"
	"testing"
)

func TestPreviewCookieSameSite(t *testing.T) {
	cases := map[string]http.SameSite{
		"localhost":           http.SameSiteNoneMode,
		"preview.example.com": http.SameSiteLaxMode,
	}
	for domain, want := range cases {
		if got := previewCookieSameSite(domain); got != want {
			t.Errorf("previewCookieSameSite(%q) = %v, want %v", domain, got, want)
		}
	}
}

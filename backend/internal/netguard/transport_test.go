package netguard

import (
	"github.com/mindforge/backend/internal/testdomain"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// An httptest server listens on loopback, i.e. an "internal BaseURL".
func TestNewHTTPClientBlocksInternalHost(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Error("request reached an internal host")
	}))
	defer srv.Close()

	_, err := NewHTTPClient(time.Second).Get(srv.URL)
	if err == nil || !strings.Contains(err.Error(), "denylisted") {
		t.Fatalf("expected denylisted dial error, got %v", err)
	}
}

func TestNewHTTPClientRefusesHTTPSDowngrade(t *testing.T) {
	c := NewHTTPClient(time.Second)
	via := []*http.Request{{URL: mustURL(t, "https://gitlab."+testdomain.Domain+"/a")}}
	if err := c.CheckRedirect(&http.Request{URL: mustURL(t, "http://gitlab."+testdomain.Domain+"/b")}, via); err == nil {
		t.Fatal("expected downgrade to be refused")
	}
}

func mustURL(t *testing.T, raw string) *url.URL {
	t.Helper()
	r, err := http.NewRequest(http.MethodGet, raw, nil)
	if err != nil {
		t.Fatal(err)
	}
	return r.URL
}

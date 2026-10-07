package assessment

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestValidatePublicCandidate(t *testing.T) {
	long := strings.Repeat("a", maxPublicPhoneLen+1)
	cases := []struct {
		name string
		req  startPublicAttemptRequest
		bad  []string
	}{
		{"ok", startPublicAttemptRequest{Name: "Ada", Email: "ada@example.com"}, nil},
		{"missing", startPublicAttemptRequest{}, []string{"name", "email"}},
		{"bad email", startPublicAttemptRequest{Name: "Ada", Email: "not-an-email"}, []string{"email"}},
		{"display-name email", startPublicAttemptRequest{Name: "Ada", Email: "Ada <ada@example.com>"}, []string{"email"}},
		{"long name", startPublicAttemptRequest{Name: strings.Repeat("a", maxPublicNameLen+1), Email: "a@b.co"}, []string{"name"}},
		{"long phone", startPublicAttemptRequest{Name: "Ada", Email: "a@b.co", Phone: &long}, []string{"phone"}},
	}
	for _, c := range cases {
		got := validatePublicCandidate(c.req)
		if len(got) != len(c.bad) {
			t.Errorf("%s: got fields %v, want %v", c.name, got, c.bad)
			continue
		}
		for _, f := range c.bad {
			if _, ok := got[f]; !ok {
				t.Errorf("%s: missing error for %q (got %v)", c.name, f, got)
			}
		}
	}
}

func TestAttemptTokenAndExpiry(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/api/p/abc/result", nil)
	r.Header.Set(attemptTokenHeader, " tok ")
	if got := attemptToken(r); got != "tok" {
		t.Errorf("header token = %q", got)
	}
	if got := attemptToken(httptest.NewRequest(http.MethodGet, "/x", nil)); got != "" {
		t.Errorf("no token = %q", got)
	}
	a := Assessment{DurationMinutes: 60}
	fresh := PublicAttempt{StartedAt: time.Now().Add(-2 * time.Hour)}
	old := PublicAttempt{StartedAt: time.Now().Add(-26 * time.Hour)}
	if tokenExpired(fresh, a) || !tokenExpired(old, a) {
		t.Error("expiry window wrong")
	}
}

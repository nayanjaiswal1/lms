package middleware

import "testing"

func TestRedactedURI(t *testing.T) {
	cases := map[string]string{
		"/api/p/abc/result/SECRET":                  "/api/p/abc/result/REDACTED",
		"/api/p/abc/submit/SECRET":                  "/api/p/abc/submit/REDACTED",
		"/api/calendar/invites/SECRET/accept":       "/api/calendar/invites/REDACTED/accept",
		"/api/calendar/events.ics?token=SECRET&a=1": "/api/calendar/events.ics?a=1&token=REDACTED",
		"/api/p/abc": "/api/p/abc",
	}
	for in, want := range cases {
		if got := RedactedURI(in); got != want {
			t.Errorf("RedactedURI(%q) = %q, want %q", in, got, want)
		}
	}
}

package auth

import (
	"testing"
	"time"
)

func TestWithinReuseGrace(t *testing.T) {
	now := time.Now()
	ago := func(d time.Duration) *time.Time { v := now.Add(-d); return &v }
	grace := 30 * time.Second

	cases := []struct {
		name      string
		rotatedAt *time.Time
		grace     time.Duration
		want      bool
	}{
		{"never rotated", nil, grace, false},
		{"just rotated", ago(time.Second), grace, true},
		{"exactly at the edge", ago(grace), grace, true},
		{"past the window", ago(grace + time.Second), grace, false},
		{"zero grace disables it", ago(time.Millisecond), 0, false},
	}
	for _, c := range cases {
		if got := withinReuseGrace(c.rotatedAt, now, c.grace); got != c.want {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

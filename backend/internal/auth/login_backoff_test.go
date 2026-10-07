package auth

import (
	"testing"
	"time"
)

func TestLoginLockWindow(t *testing.T) {
	base := time.Minute
	cases := []struct {
		failures int
		want     time.Duration
	}{
		{1, base}, {10, base}, {11, 2 * base}, {12, 4 * base}, {100, maxLoginBackoff},
	}
	for _, c := range cases {
		if got := loginLockWindow(base, c.failures, 10); got != c.want {
			t.Errorf("failures=%d: got %v want %v", c.failures, got, c.want)
		}
	}
}

func TestLoginDelayFor(t *testing.T) {
	max := 10
	threshold := max * emailDelayFactor
	cases := []struct {
		failures int
		want     time.Duration
	}{
		{0, 0}, {threshold, 0}, {threshold + 1, emailDelayStep}, {threshold + 4, 4 * emailDelayStep}, {threshold + 1000, emailDelayMax},
	}
	for _, c := range cases {
		if got := loginDelayFor(c.failures, max); got != c.want {
			t.Errorf("failures=%d: got %v want %v", c.failures, got, c.want)
		}
	}
}

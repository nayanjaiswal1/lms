package ratelimit

import (
	"testing"
	"time"
)

func TestInMemorySlidingWindow_RetryAfterReflectsOldestEntry(t *testing.T) {
	s := newInMemorySlidingWindow()
	windowMs := int64(1000)

	if ok, _ := s.allow("k", 1, windowMs); !ok {
		t.Fatal("first request should be allowed")
	}
	ok, wait := s.allow("k", 1, windowMs)
	if ok {
		t.Fatal("second request within the window should be blocked")
	}
	if wait <= 0 || wait > time.Duration(windowMs)*time.Millisecond {
		t.Fatalf("wait %v should be positive and no longer than the window", wait)
	}
}

func TestRetryAfterSeconds(t *testing.T) {
	cases := map[time.Duration]int{
		0:                       1,
		500 * time.Millisecond:  1,
		1500 * time.Millisecond: 2,
		2 * time.Second:         2,
	}
	for wait, want := range cases {
		if got := RetryAfterSeconds(wait); got != want {
			t.Errorf("RetryAfterSeconds(%v) = %d, want %d", wait, got, want)
		}
	}
}

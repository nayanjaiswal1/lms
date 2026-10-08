package mailer

import (
	"context"
	"errors"
	"net/textproto"
	"testing"
	"time"
)

func TestClassifySMTPReplies(t *testing.T) {
	for _, code := range []int{421, 450, 451, 452} {
		err := classify(&textproto.Error{Code: code, Msg: "slow down"})
		if !IsThrottle(err) || IsPermanent(err) {
			t.Fatalf("%d should classify as throttle only, got %v", code, err)
		}
	}
	if err := classify(&textproto.Error{Code: 550, Msg: "no such user"}); !IsPermanent(err) || IsThrottle(err) {
		t.Fatalf("550 should classify as permanent only, got %v", err)
	}
	plain := errors.New("boom")
	if classify(plain) != plain {
		t.Fatal("non-SMTP errors must pass through unchanged")
	}
}

func TestBreakerOpensAndCloses(t *testing.T) {
	ctx := context.Background()
	b := NewBreaker(nil, 3, 50*time.Millisecond)
	throttle := classify(&textproto.Error{Code: 451, Msg: "try later"})

	b.Record(ctx, throttle)
	b.Record(ctx, throttle)
	if b.Remaining(ctx) != 0 {
		t.Fatal("breaker opened before the threshold")
	}
	// A success resets the consecutive-failure run.
	b.Record(ctx, nil)
	b.Record(ctx, throttle)
	b.Record(ctx, throttle)
	if b.Remaining(ctx) != 0 {
		t.Fatal("success must reset the failure run")
	}
	// A permanent (per-message) rejection never counts.
	b.Record(ctx, classify(&textproto.Error{Code: 550, Msg: "bad rcpt"}))
	b.Record(ctx, throttle)
	if b.Remaining(ctx) <= 0 {
		t.Fatal("breaker should be open after 3 consecutive throttles")
	}
	time.Sleep(80 * time.Millisecond)
	if b.Remaining(ctx) != 0 {
		t.Fatal("breaker should close after the cooldown")
	}
}

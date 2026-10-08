package main

import (
	"context"
	"fmt"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/mindforge/backend/internal/ratelimit"
	"github.com/mindforge/backend/internal/testdomain"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

// Needs a live Redis (the cap is global); skipped unless LABPROXY_TEST_REDIS_URL is set.
func TestConnLimiter(t *testing.T) {
	url := os.Getenv("LABPROXY_TEST_REDIS_URL")
	if url == "" {
		t.Skip("LABPROXY_TEST_REDIS_URL not set")
	}
	opts, err := redis.ParseURL(url)
	require.NoError(t, err)
	rdb := redis.NewClient(opts)
	defer rdb.Close()
	// Two limiters model two replicas sharing one cap.
	a, b := newConnLimiter(rdb), newConnLimiter(rdb)
	user := fmt.Sprintf("test-%d", time.Now().UnixNano())
	ctx := context.Background()

	var leases []*ratelimit.Lease
	for i := 0; i < maxConnsPerUser; i++ {
		l := a
		if i%2 == 1 {
			l = b
		}
		lease, err := l.acquire(ctx, user)
		require.NoError(t, err)
		require.NotNil(t, lease)
		leases = append(leases, lease)
	}
	over, err := b.acquire(ctx, user)
	require.NoError(t, err)
	assert.Nil(t, over, "cap is global across replicas")

	other, err := a.acquire(ctx, user+"-other")
	require.NoError(t, err)
	require.NotNil(t, other)
	other.Release()

	leases[0].Release()
	again, err := b.acquire(ctx, user)
	require.NoError(t, err)
	require.NotNil(t, again)
	again.Release()
	for _, l := range leases[1:] {
		l.Release()
	}
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

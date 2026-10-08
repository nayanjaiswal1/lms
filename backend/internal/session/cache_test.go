package session

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// newRedis starts a throwaway Redis container for one test and returns a
// client to it; both are torn down when the test ends.
func newRedis(t *testing.T) *redis.Client {
	t.Helper()
	ctx := context.Background()
	ctr, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: testcontainers.ContainerRequest{
			Image:        "redis:7-alpine",
			ExposedPorts: []string{"6379/tcp"},
			WaitingFor:   wait.ForListeningPort("6379/tcp"),
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("start redis container: %v", err)
	}
	t.Cleanup(func() { _ = ctr.Terminate(context.Background()) })

	host, err := ctr.Host(ctx)
	if err != nil {
		t.Fatalf("redis host: %v", err)
	}
	port, err := ctr.MappedPort(ctx, "6379/tcp")
	if err != nil {
		t.Fatalf("redis port: %v", err)
	}
	rdb := redis.NewClient(&redis.Options{Addr: fmt.Sprintf("%s:%s", host, port.Port())})
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

// Regression (2026-09-25): CheckSession pipelines the JTI-blocklist and
// session-version lookups into one Redis round trip. The pipelined replies
// must still be interpreted correctly: blocked JTI, version mismatch and
// version match from cache, and a cache miss falling back to the DB.
func TestCheckSessionPipelined(t *testing.T) {
	ctx := context.Background()
	// nil pool: every case below is answered from Redis alone.
	rdb := newRedis(t)
	c := NewCache(rdb, nil)

	t.Run("cached matching version passes", func(t *testing.T) {
		mustSet(t, rdb, svPrefix+"u-ok", 4)
		if err := c.CheckSession(ctx, "jti-ok", "u-ok", 4); err != nil {
			t.Fatalf("want nil, got %v", err)
		}
	})
	t.Run("cached version mismatch is rejected", func(t *testing.T) {
		mustSet(t, rdb, svPrefix+"u-old", 5)
		if err := c.CheckSession(ctx, "jti-old", "u-old", 4); err == nil || err.Error() != "session version mismatch" {
			t.Fatalf("want session version mismatch, got %v", err)
		}
	})
	t.Run("blocked jti is rejected even when version matches", func(t *testing.T) {
		mustSet(t, rdb, svPrefix+"u-blk", 1)
		c.BlockJTI(ctx, "jti-blk", time.Now().Add(time.Minute))
		if err := c.CheckSession(ctx, "jti-blk", "u-blk", 1); err == nil || err.Error() != "session revoked (blocked jti)" {
			t.Fatalf("want blocked jti error, got %v", err)
		}
	})
}

func TestCheckSessionCacheMissReadsDBAndRepopulates(t *testing.T) {
	ctx := context.Background()
	pool := testdb.New(t)
	rdb := newRedis(t)
	c := NewCache(rdb, pool)

	var userID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO users (email, name, session_version) VALUES ('session-miss@example.test', 'S', 7) RETURNING id`,
	).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	rdb.Del(ctx, svPrefix+userID)

	if err := c.CheckSession(ctx, "jti-miss", userID, 7); err != nil {
		t.Fatalf("miss with matching db version: %v", err)
	}
	if got, err := rdb.Get(ctx, svPrefix+userID).Int(); err != nil || got != 7 {
		t.Fatalf("cache not repopulated: got %d err %v, want 7", got, err)
	}
	if err := c.CheckSession(ctx, "jti-miss", userID, 6); err == nil || err.Error() != "session version mismatch" {
		t.Fatalf("stale claim version: want mismatch, got %v", err)
	}
}

func mustSet(t *testing.T, rdb *redis.Client, key string, v int) {
	t.Helper()
	if err := rdb.Set(context.Background(), key, v, time.Minute).Err(); err != nil {
		t.Fatalf("redis set %s: %v", key, err)
	}
}

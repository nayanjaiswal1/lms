package session

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

const (
	cacheTTL  = 30 * time.Second
	jtiPrefix = "jti:blocked:"
	svPrefix  = "sv:"
)

// Cache wraps Redis for JTI blocklist and session-version caching.
// Falls back to PostgreSQL on Redis errors so a Redis outage degrades
// gracefully rather than locking all users out.
type Cache struct {
	rdb  *redis.Client
	pool *pgxpool.Pool
}

// NewCache constructs a Cache backed by Redis with the given DB pool as fallback.
func NewCache(rdb *redis.Client, pool *pgxpool.Pool) *Cache {
	return &Cache{rdb: rdb, pool: pool}
}

// BlockJTI marks a JWT ID as revoked in Redis until the token expires.
// The caller also writes to jti_blocklist in Postgres for restart durability.
func (c *Cache) BlockJTI(ctx context.Context, jti string, tokenExpiry time.Time) {
	ttl := time.Until(tokenExpiry)
	if ttl <= 0 {
		return
	}
	_ = c.rdb.Set(ctx, jtiPrefix+jti, "1", ttl).Err()
}

// IsJTIBlocked reports whether a JWT ID has been revoked.
// Falls back to the jti_blocklist table if Redis is unavailable.
func (c *Cache) IsJTIBlocked(ctx context.Context, jti string) bool {
	val, err := c.rdb.Exists(ctx, jtiPrefix+jti).Result()
	if err == nil {
		return val > 0
	}
	var exists bool
	_ = c.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM jti_blocklist WHERE jti = $1 AND expires_at > now())`,
		jti,
	).Scan(&exists)
	return exists
}

// InvalidateVersionCache removes the cached session_version for a user so the
// next request re-fetches from the database immediately.
func (c *Cache) InvalidateVersionCache(ctx context.Context, userID string) {
	_ = c.rdb.Del(ctx, svPrefix+userID).Err()
}

// CheckVersion compares claimVersion against the authoritative session_version
// in the database. Uses a 30s Redis read-through cache to avoid a DB hit on
// every request. Falls back to a direct DB query if Redis is unavailable.
func (c *Cache) CheckVersion(ctx context.Context, userID string, claimVersion int) error {
	key := svPrefix + userID

	cached, err := c.rdb.Get(ctx, key).Int()
	if err == nil {
		if claimVersion != cached {
			return fmt.Errorf("session version mismatch")
		}
		return nil
	}

	var v int
	if err := c.pool.QueryRow(ctx,
		`SELECT session_version FROM users WHERE id = $1`, userID,
	).Scan(&v); err != nil {
		return err
	}

	_ = c.rdb.Set(ctx, key, v, cacheTTL).Err()

	if claimVersion != v {
		return fmt.Errorf("session version mismatch")
	}
	return nil
}

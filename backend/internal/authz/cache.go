package authz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	cacheKeyPrefix    = "rbac:perms:"
	cacheTTL          = 5 * time.Minute
	invalidateChannel = "rbac:invalidate"
)

// Cache wraps Redis for permission-code caching and pub/sub invalidation.
type Cache struct {
	rdb *redis.Client
}

// NewCache constructs a Cache backed by the given Redis client.
func NewCache(rdb *redis.Client) *Cache {
	return &Cache{rdb: rdb}
}

// cacheKey returns the Redis key for a (tenantID, userID) pair.
func cacheKey(tenantID, userID string) string {
	return cacheKeyPrefix + tenantID + ":" + userID
}

// Get returns the cached permission codes for the given user+tenant.
// Returns nil, nil on a cache miss so callers can distinguish miss from error.
func (c *Cache) Get(ctx context.Context, tenantID, userID string) ([]string, error) {
	raw, err := c.rdb.Get(ctx, cacheKey(tenantID, userID)).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, nil
		}
		return nil, fmt.Errorf("authz cache: get: %w", err)
	}

	var codes []string
	if err := json.Unmarshal(raw, &codes); err != nil {
		return nil, fmt.Errorf("authz cache: get: unmarshal: %w", err)
	}
	return codes, nil
}

// Set stores the permission codes for the given user+tenant with cacheTTL expiry.
func (c *Cache) Set(ctx context.Context, tenantID, userID string, codes []string) error {
	raw, err := json.Marshal(codes)
	if err != nil {
		return fmt.Errorf("authz cache: set: marshal: %w", err)
	}
	if err := c.rdb.SetEx(ctx, cacheKey(tenantID, userID), raw, cacheTTL).Err(); err != nil {
		return fmt.Errorf("authz cache: set: %w", err)
	}
	return nil
}

// Invalidate deletes the cached entry for the given user+tenant and publishes
// an invalidation message to invalidateChannel so other replicas can drop their
// local state if applicable.
func (c *Cache) Invalidate(ctx context.Context, tenantID, userID string) error {
	if err := c.rdb.Del(ctx, cacheKey(tenantID, userID)).Err(); err != nil {
		return fmt.Errorf("authz cache: invalidate: del: %w", err)
	}
	if err := c.rdb.Publish(ctx, invalidateChannel, tenantID+":"+userID).Err(); err != nil {
		return fmt.Errorf("authz cache: invalidate: publish: %w", err)
	}
	return nil
}

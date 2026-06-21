package authz

import (
	"context"
	"fmt"
	"log/slog"
)

// Service composes Repo and Cache to provide permission resolution with
// a Redis read-through cache backed by PostgreSQL.
type Service struct {
	repo  *Repo
	cache *Cache
}

// NewService constructs a Service.
func NewService(repo *Repo, cache *Cache) *Service {
	return &Service{repo: repo, cache: cache}
}

// GetEffectivePermissions returns all permission codes held by userID within
// tenantID. It checks Redis first; on a cache miss it queries the DB and
// back-fills the cache. A Redis write failure is logged but does not fail the
// call — the DB result is always authoritative.
func (s *Service) GetEffectivePermissions(ctx context.Context, userID, tenantID string) ([]string, error) {
	cached, err := s.cache.Get(ctx, tenantID, userID)
	if err != nil {
		slog.Warn("authz service: cache get failed, falling back to db",
			"user_id", userID, "tenant_id", tenantID, "error", err)
	}
	if cached != nil {
		return cached, nil
	}

	codes, err := s.repo.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("authz service: get effective permissions: %w", err)
	}

	if setErr := s.cache.Set(ctx, tenantID, userID, codes); setErr != nil {
		slog.Warn("authz service: cache set failed",
			"user_id", userID, "tenant_id", tenantID, "error", setErr)
	}

	return codes, nil
}

// HasPermission reports whether userID holds code within tenantID.
func (s *Service) HasPermission(ctx context.Context, userID, tenantID, code string) (bool, error) {
	codes, err := s.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return false, fmt.Errorf("authz service: has permission: %w", err)
	}
	for _, c := range codes {
		if c == code {
			return true, nil
		}
	}
	return false, nil
}

// HasAnyPermission reports whether userID holds at least one of the given codes
// within tenantID.
func (s *Service) HasAnyPermission(ctx context.Context, userID, tenantID string, codes ...string) (bool, error) {
	effective, err := s.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return false, fmt.Errorf("authz service: has any permission: %w", err)
	}
	held := make(map[string]struct{}, len(effective))
	for _, c := range effective {
		held[c] = struct{}{}
	}
	for _, code := range codes {
		if _, ok := held[code]; ok {
			return true, nil
		}
	}
	return false, nil
}

// HasAllPermissions reports whether userID holds every one of the given codes
// within tenantID.
func (s *Service) HasAllPermissions(ctx context.Context, userID, tenantID string, codes ...string) (bool, error) {
	effective, err := s.GetEffectivePermissions(ctx, userID, tenantID)
	if err != nil {
		return false, fmt.Errorf("authz service: has all permissions: %w", err)
	}
	held := make(map[string]struct{}, len(effective))
	for _, c := range effective {
		held[c] = struct{}{}
	}
	for _, code := range codes {
		if _, ok := held[code]; !ok {
			return false, nil
		}
	}
	return true, nil
}

// InvalidateUser flushes the permission cache for a single (userID, tenantID) pair.
func (s *Service) InvalidateUser(ctx context.Context, userID, tenantID string) error {
	if err := s.cache.Invalidate(ctx, tenantID, userID); err != nil {
		return fmt.Errorf("authz service: invalidate user: %w", err)
	}
	return nil
}

// InvalidateForRoleChange flushes the permission cache for every user that holds
// roleID. Partial failures are logged; the function continues invalidating
// remaining assignments and returns the last error encountered.
func (s *Service) InvalidateForRoleChange(ctx context.Context, roleID string) error {
	assignments, err := s.repo.GetAssignmentsForRole(ctx, roleID)
	if err != nil {
		return fmt.Errorf("authz service: invalidate for role change: %w", err)
	}

	var lastErr error
	for _, a := range assignments {
		if err := s.cache.Invalidate(ctx, a.TenantID, a.UserID); err != nil {
			slog.Warn("authz service: invalidate for role change: partial failure",
				"role_id", roleID, "user_id", a.UserID, "tenant_id", a.TenantID, "error", err)
			lastErr = err
		}
	}
	if lastErr != nil {
		return fmt.Errorf("authz service: invalidate for role change: %w", lastErr)
	}
	return nil
}

package labbuild

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/redis/go-redis/v9"
)

const (
	// runtimeStampPath is written by the lab image's Dockerfile: a sha256 over
	// the grader / renderer / entrypoint bundle, so it changes exactly when the
	// code that verifies a lab changes (nobody bumps it by hand).
	runtimeStampPath = "/opt/mindforge/RUNTIME_ID"
	// unstampedPrefix identifies images that carry no stamp (other lab kinds):
	// identity falls back to the image reference.
	unstampedPrefix = "unstamped:"
	// runtimeCacheTTL bounds how long a probed stamp is trusted, i.e. how long
	// after an image rebuild a stale reuse is still possible.
	runtimeCacheTTL  = 5 * time.Minute
	runtimeKeyPrefix = "labbuild:runtime:"
	runtimeProbeSecs = 30
)

// runtimeID returns the content identity of the image builds of kindName run in.
func (s *Service) runtimeID(ctx context.Context, kindName string) (string, error) {
	kind, ok := labkinds.Get(kindName)
	if !ok {
		return "", fmt.Errorf("labbuild.runtimeID: unknown lab kind %q", kindName)
	}
	image := kind.Image()
	key := runtimeKeyPrefix + image
	if id, err := s.rdb.Get(ctx, key).Result(); err == nil {
		return id, nil
	} else if !errors.Is(err, redis.Nil) {
		return "", fmt.Errorf("labbuild.runtimeID: cache: %w", err)
	}
	containerID, _, err := s.runtime.StartValidation(ctx, "runtime-"+strings.ReplaceAll(uuid.NewString(), "-", ""), image)
	if err != nil {
		return "", fmt.Errorf("labbuild.runtimeID: start probe sandbox: %w", err)
	}
	defer func() { _ = s.runtime.Kill(context.Background(), containerID) }()
	stdout, _, _, err := s.runtime.Exec(ctx, containerID, "cat "+runtimeStampPath+" 2>/dev/null || true", runtimeProbeSecs)
	if err != nil {
		return "", fmt.Errorf("labbuild.runtimeID: read stamp: %w", err)
	}
	id := strings.TrimSpace(stdout)
	if id == "" {
		id = unstampedPrefix + image
	}
	if err := s.rdb.Set(ctx, key, id, runtimeCacheTTL).Err(); err != nil {
		return "", fmt.Errorf("labbuild.runtimeID: cache: %w", err)
	}
	return id, nil
}

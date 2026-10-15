package labbuild

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
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
	// runtimeLastKeyPrefix keeps the last successfully probed stamp for
	// runtimeLastTTL. It is used only when a fresh probe cannot run (no
	// validation capacity, unschedulable, probe error), so a full cluster
	// never stalls the pipeline on identity. A build labelled with a stamp
	// that has since changed is caught by the next successful probe
	// (BuildView.NeedsReverify).
	runtimeLastKeyPrefix = "labbuild:runtime:last:"
	runtimeLastTTL       = 30 * 24 * time.Hour
	runtimeProbeSecs     = 30
	// runtimeProbeTimeout bounds a whole probe (Pod start + read) so a
	// caller with a short budget (an API request) is never consumed by it.
	runtimeProbeTimeout = 60 * time.Second
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
	id, probeErr := s.probeRuntime(ctx, image)
	if probeErr != nil {
		last, err := s.rdb.Get(ctx, runtimeLastKeyPrefix+image).Result()
		if err != nil {
			return "", fmt.Errorf("labbuild.runtimeID: %w (no last known stamp: %v)", probeErr, err)
		}
		slog.Warn("labbuild: runtime probe failed, using the last known stamp", "image", image, "error", probeErr)
		return last, nil
	}
	if _, err := s.rdb.TxPipelined(ctx, func(p redis.Pipeliner) error {
		p.Set(ctx, key, id, runtimeCacheTTL)
		p.Set(ctx, runtimeLastKeyPrefix+image, id, runtimeLastTTL)
		return nil
	}); err != nil {
		return "", fmt.Errorf("labbuild.runtimeID: cache: %w", err)
	}
	return id, nil
}

// probeRuntime reads the image's stamp in a throwaway validation sandbox,
// holding a validation-pod slot (errNoCapacity when none is free).
func (s *Service) probeRuntime(ctx context.Context, image string) (string, error) {
	lease, err := s.acquirePod(ctx, "")
	if err != nil {
		return "", fmt.Errorf("labbuild.probeRuntime: %w", err)
	}
	if lease == nil {
		return "", errNoCapacity
	}
	defer lease.Release()
	pctx, cancel := context.WithTimeout(lease.Ctx, runtimeProbeTimeout)
	defer cancel()
	containerID, _, err := s.runtime.StartValidation(pctx, "runtime-"+strings.ReplaceAll(uuid.NewString(), "-", ""), image)
	if err != nil {
		return "", fmt.Errorf("labbuild.probeRuntime: start probe sandbox: %w", err)
	}
	defer func() { _ = s.runtime.Kill(context.Background(), containerID) }()
	stdout, _, _, err := s.runtime.Exec(pctx, containerID, "cat "+runtimeStampPath+" 2>/dev/null || true", runtimeProbeSecs)
	if err != nil {
		return "", fmt.Errorf("labbuild.probeRuntime: read stamp: %w", err)
	}
	if id := strings.TrimSpace(stdout); id != "" {
		return id, nil
	}
	return unstampedPrefix + image, nil
}

package labbuild

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/ratelimit"
)

// Validation sandboxes (a render, one verify run, a runtime probe: one Pod
// each) are capped GLOBALLY by Config.ValidatePodsMax, and verify runs also per
// org by Config.VerifyParallelPerOrg (docs/debug-labs.md B3: "the org
// validation cap"). Both are Redis-backed counting semaphores
// (ratelimit.Semaphore), so the caps hold across every worker replica. This is
// deliberately different from LABS_CLEANROOM_MAX_CONCURRENT, which is a
// per-process cap protecting the local node and stays in-process on purpose.
//
// A full semaphore never blocks: the job returns jobs.RetryAfter, which frees
// its worker slot and re-queues the SAME job row without consuming a retry.
// Config.BuildDeadline bounds the total wait (deferBuild).
const (
	validatePodsSemKey = "labbuild:validate:pods"
	verifySemKeyPrefix = "labbuild:verify:org:"
	// podLeaseTTL bounds how long a crashed worker can hold a slot; live
	// holders renew every ttl/3.
	podLeaseTTL = 2 * time.Minute
	// capacityBackoff is the delay before a job deferred for capacity runs again.
	capacityBackoff = 30 * time.Second
)

// errNoCapacity means no validation sandbox slot was free (a full semaphore,
// this replica's clean-room slots, or a cluster with no room for the Pod).
var errNoCapacity = errors.New("labbuild: no validation sandbox capacity")

func verifySemKey(org string) string { return verifySemKeyPrefix + org }

// podLease holds one global validation-pod slot and, for verify runs, one of
// the org's slots. Ctx is cancelled if either lease is lost.
type podLease struct {
	Ctx  context.Context
	held []*ratelimit.Lease
}

// Release frees every slot, innermost first. Call exactly once.
func (l *podLease) Release() {
	for i := len(l.held) - 1; i >= 0; i-- {
		l.held[i].Release()
	}
}

// acquirePod takes a validation-pod slot (plus an org verify slot when orgID is
// set). It returns (nil, nil) when either cap is full.
func (s *Service) acquirePod(ctx context.Context, orgID string) (*podLease, error) {
	global, err := s.sem.TryAcquire(ctx, validatePodsSemKey, max(s.cfg.ValidatePodsMax, 1), podLeaseTTL)
	if err != nil || global == nil {
		return nil, err
	}
	l := &podLease{Ctx: global.Ctx, held: []*ratelimit.Lease{global}}
	if orgID == "" {
		return l, nil
	}
	org, err := s.sem.TryAcquire(global.Ctx, verifySemKey(orgID), max(s.cfg.VerifyParallelPerOrg, 1), podLeaseTTL)
	if err != nil || org == nil {
		l.Release()
		return nil, err
	}
	l.Ctx, l.held = org.Ctx, append(l.held, org)
	return l, nil
}

// deferBuild re-queues the current pipeline job for later because validation
// capacity is short, or, once the build has waited Config.BuildDeadline since
// it was queued, fails it as an infra failure (rep keeps any partial results).
func (s *Service) deferBuild(ctx context.Context, b *Build, rep Report, cause error) error {
	if s.cfg.BuildDeadline > 0 && time.Since(b.CreatedAt) >= s.cfg.BuildDeadline {
		rep.Error = fmt.Sprintf("no validation sandbox capacity within %s of queueing the build: %v", s.cfg.BuildDeadline, cause)
		return s.failInfra(ctx, b, rep)
	}
	return jobs.RetryAfter(cause, capacityBackoff)
}

// failInfra fails a build for a platform reason (not the recipe: building again can succeed).
func (s *Service) failInfra(ctx context.Context, b *Build, rep Report) error {
	rep.Infra = true
	return s.failBuild(ctx, b, rep)
}

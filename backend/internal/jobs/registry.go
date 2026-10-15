package jobs

import (
	"context"
	"fmt"
	"sort"
	"sync"
)

// DeadLetterHook is invoked (best-effort, asynchronously) whenever a job for
// its registered handler key permanently exhausts its retries. Lets a domain
// react to a permanent job failure — e.g. flip the status of the resource
// that job was working on, so a user isn't left staring at an infinite
// "processing" state — without every domain writing its own polling
// reconciliation job to detect the same thing after the fact.
type DeadLetterHook func(ctx context.Context, job Job)

type Registry struct {
	mu        sync.RWMutex
	handlers  map[string]Handler
	deadHooks map[string]DeadLetterHook
	anyDead   []DeadLetterHook
	// maxRunning caps concurrently running jobs per handler across all
	// workers (see SetMaxConcurrent).
	maxRunning map[string]int
	// resumable handlers are requeued without consuming a retry when a
	// shutdown interrupts them (see SetResumable).
	resumable map[string]bool
}

func NewRegistry() *Registry {
	return &Registry{
		handlers:   make(map[string]Handler),
		deadHooks:  make(map[string]DeadLetterHook),
		maxRunning: make(map[string]int),
		resumable:  make(map[string]bool),
	}
}

// SetMaxConcurrent caps how many jobs of handler key may be running at once
// across every worker replica (counted in the jobs table at claim time). Use
// it for handlers that hold a worker slot for minutes, so a burst of them
// cannot occupy the whole pool and starve every other handler. n < 1 is
// treated as 1.
//
// ponytail: the count and the claim are not one atomic step, so concurrent
// claimers can overshoot the cap by at most the number of claiming workers
// for an instant (same as the per-org max_concurrent rule); an advisory lock
// per handler is the upgrade if an exact cap ever matters.
func (r *Registry) SetMaxConcurrent(key string, n int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.maxRunning[key] = max(n, 1)
}

// concurrencyCaps returns the per-handler caps as parallel slices (SQL arrays).
func (r *Registry) concurrencyCaps() ([]string, []int32) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	keys := make([]string, 0, len(r.maxRunning))
	caps := make([]int32, 0, len(r.maxRunning))
	for k, n := range r.maxRunning {
		keys = append(keys, k)
		caps = append(caps, int32(n))
	}
	return keys, caps
}

// SetResumable marks handler key as safe to re-run from the start after a
// shutdown interrupted it (idempotent: status-guarded, no external side
// effect that a second run would duplicate). Such a job is put straight back
// on the queue WITHOUT consuming a retry, so deploys and dev reloads do not
// burn its retry budget. Handlers not marked keep the conservative path: the
// orphan reaper fails the run, which consumes a retry and can send the job
// dead — the right outcome for a non-idempotent handler (an email that may
// already have been sent) where an unbounded re-run is the bigger risk.
func (r *Registry) SetResumable(key string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.resumable[key] = true
}

func (r *Registry) isResumable(key string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.resumable[key]
}

// Register panics if the key is already registered.
func (r *Registry) Register(key string, h Handler) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, exists := r.handlers[key]; exists {
		panic(fmt.Sprintf("jobs: handler already registered for key %q", key))
	}
	r.handlers[key] = h
}

// Get returns the handler and true, or nil and false.
func (r *Registry) Get(key string) (Handler, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	h, ok := r.handlers[key]
	return h, ok
}

// OnDead registers a DeadLetterHook for the given handler key. Panics if a
// hook is already registered for this key (mirrors Register's behavior).
func (r *Registry) OnDead(key string, hook DeadLetterHook) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, exists := r.deadHooks[key]; exists {
		panic(fmt.Sprintf("jobs: dead hook already registered for key %q", key))
	}
	r.deadHooks[key] = hook
}

// OnAnyDead registers a hook that fires for EVERY dead job, in addition to the
// per-handler hook. Multiple hooks are allowed (cross-cutting concerns such as
// ops alerting).
func (r *Registry) OnAnyDead(hook DeadLetterHook) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.anyDead = append(r.anyDead, hook)
}

// deadHooksFor returns the per-handler hook (if any) followed by all any-dead hooks.
func (r *Registry) deadHooksFor(key string) []DeadLetterHook {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var out []DeadLetterHook
	if h, ok := r.deadHooks[key]; ok {
		out = append(out, h)
	}
	return append(out, r.anyDead...)
}

// MustGet panics if the key is not registered. Use at startup validation.
func (r *Registry) MustGet(key string) Handler {
	h, ok := r.Get(key)
	if !ok {
		panic(fmt.Sprintf("jobs: no handler registered for key %q", key))
	}
	return h
}

// All returns a sorted list of all registered handler keys.
func (r *Registry) All() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	keys := make([]string, 0, len(r.handlers))
	for k := range r.handlers {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

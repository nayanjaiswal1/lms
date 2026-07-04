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
}

func NewRegistry() *Registry {
	return &Registry{
		handlers:  make(map[string]Handler),
		deadHooks: make(map[string]DeadLetterHook),
	}
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

// getDeadHook returns the registered DeadLetterHook and true, or nil and false.
func (r *Registry) getDeadHook(key string) (DeadLetterHook, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	h, ok := r.deadHooks[key]
	return h, ok
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

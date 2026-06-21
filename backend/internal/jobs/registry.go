package jobs

import (
	"fmt"
	"sort"
	"sync"
)

type Registry struct {
	mu       sync.RWMutex
	handlers map[string]Handler
}

func NewRegistry() *Registry {
	return &Registry{handlers: make(map[string]Handler)}
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

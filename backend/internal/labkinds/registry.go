package labkinds

import (
	"sort"
	"sync"
)

// Registry maps a lab_type string to the Kind implementation handling it.
// Safe for concurrent use — Register only ever runs from package init()s at
// process startup, but Get is called on every lab-kind session request.
type Registry struct {
	mu    sync.RWMutex
	kinds map[string]Kind
}

// NewRegistry returns an empty Registry. Exported for tests that want an
// isolated registry rather than mutating the process-wide Default.
func NewRegistry() *Registry {
	return &Registry{kinds: make(map[string]Kind)}
}

// Register adds k, keyed by k.Name(). A later call with the same name
// overwrites the earlier one — there is exactly one Kind per lab_type.
func (r *Registry) Register(k Kind) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.kinds[k.Name()] = k
}

// Get returns the Kind registered for name, if any.
func (r *Registry) Get(name string) (Kind, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	k, ok := r.kinds[name]
	return k, ok
}

// All returns every registered Kind, ordered by name.
func (r *Registry) All() []Kind {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]Kind, 0, len(r.kinds))
	for _, k := range r.kinds {
		out = append(out, k)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name() < out[j].Name() })
	return out
}

// Default is the process-wide registry every Kind implementation
// self-registers into via an init() in its own file (see debug.go) — adding
// a new lab kind needs no wiring in main.go beyond importing the package
// (already imported transitively through labs) for that init() side effect.
var Default = NewRegistry()

// Register adds k to Default.
func Register(k Kind) { Default.Register(k) }

// Get looks up name in Default.
func Get(name string) (Kind, bool) { return Default.Get(name) }

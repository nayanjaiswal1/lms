package payments

import (
	"log/slog"

	"github.com/mindforge/backend/internal/config"
)

// Registry holds every Provider the running instance has credentials for,
// keyed by name. This is the whole "plugin system" for adding a gateway
// later: implement Provider, register it in FromConfig behind its own
// optional env vars, done — no interface indirection beyond Provider itself.
type Registry struct {
	byName      map[string]Provider
	defaultName string
}

// NewRegistry builds a Registry from an explicit provider list — used
// directly by tests; production wiring goes through FromConfig.
func NewRegistry(defaultName string, providers ...Provider) *Registry {
	byName := make(map[string]Provider, len(providers))
	for _, p := range providers {
		byName[p.Name()] = p
	}
	if defaultName == "" {
		for name := range byName {
			defaultName = name
			break
		}
	}
	return &Registry{byName: byName, defaultName: defaultName}
}

// Get returns the named provider, or the registry's default when name is
// empty. Returns ErrUnknownProvider if name doesn't match any registered
// provider (including when the registry is empty and name is "").
func (r *Registry) Get(name string) (Provider, error) {
	if name == "" {
		name = r.defaultName
	}
	p, ok := r.byName[name]
	if !ok {
		return nil, ErrUnknownProvider
	}
	return p, nil
}

// Names returns every registered provider name, for logging/diagnostics.
func (r *Registry) Names() []string {
	names := make([]string, 0, len(r.byName))
	for name := range r.byName {
		names = append(names, name)
	}
	return names
}

// FromConfig registers Stripe when cfg.StripeSecretKey is set, Razorpay when
// cfg.RazorpayKeyID is set, and the local StubProvider only when nothing else
// is configured and cfg.Env is not "production" — a half-configured
// production deployment must never silently fall back to a provider that
// takes no real money. config.Load already enforces (fatally, at startup)
// that a configured gateway also has its webhook secret set, so any provider
// registered here is safe to receive real webhook traffic.
func FromConfig(cfg *config.Config) *Registry {
	var providers []Provider

	if cfg.StripeSecretKey != "" {
		providers = append(providers, NewStripeProvider(cfg.StripeSecretKey, cfg.StripeWebhookSecret))
	}
	if cfg.RazorpayKeyID != "" {
		providers = append(providers, NewRazorpayProvider(cfg.RazorpayKeyID, cfg.RazorpayKeySecret, cfg.RazorpayWebhookSecret))
	}
	if len(providers) == 0 && !cfg.IsProd() {
		providers = append(providers, NewStubProvider())
	}

	reg := NewRegistry(cfg.PaymentsDefaultProvider, providers...)
	slog.Info("payments providers registered", "providers", reg.Names(), "default", reg.defaultName)
	return reg
}

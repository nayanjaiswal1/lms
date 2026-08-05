package pricing

import (
	"errors"
	"time"
)

const (
	AudienceIndividual = "individual"
	AudienceOrg        = "org"
)

var (
	ErrNotFound = errors.New("pricing: not found")
	ErrInvalid  = errors.New("pricing: invalid input")
)

// Tier is one row of a marketing pricing table — the individual (Free/Plus/
// Pro) or org (Starter/Growth/Enterprise) landing page section. Presentational
// only: there is no billing backend behind CTADisabled, same as the static
// PLAN_TIERS placeholders this replaced (see frontend/lib/features.ts).
type Tier struct {
	ID          string
	Audience    string
	Position    int16
	Name        string
	Price       string
	BillingNote string
	Tagline     string
	Features    []string
	CTALabel    string
	CTADisabled bool
	CTAHref     *string
	Highlighted bool
	UpdatedBy   *string
	UpdatedAt   time.Time
}

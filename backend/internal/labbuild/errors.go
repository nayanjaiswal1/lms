package labbuild

import (
	"errors"
	"net/http"

	"github.com/mindforge/backend/internal/httputil"
)

// Domain errors and their envelope codes. The lab-authoring codes
// (recipe_invalid, block_yanked, ...) live in labauthor; these are the build
// and publish ones.
var (
	ErrBuildNotFound  = errors.New("labbuild: build not found")
	ErrBuildInFlight  = errors.New("labbuild: a build of this recipe version is already in progress")
	ErrNotVerified    = errors.New("labbuild: only a verified build can be published or previewed")
	ErrBuildStale     = errors.New("labbuild: the recipe changed since this build; build it again")
	ErrBuildRateLimit = errors.New("labbuild: build limit reached; try again tomorrow")
	ErrBadPlacement   = errors.New("labbuild: invalid course placement")
	ErrVariantUnknown = errors.New("labbuild: unknown variant")
	ErrNoWorker       = errors.New("labbuild: could not queue the build")
)

// Machine-readable codes in the API error envelope.
const (
	CodeBuildNotFound  = "build_not_found"
	CodeBuildInFlight  = "build_in_flight"
	CodeNotVerified    = "build_not_verified"
	CodeBuildStale     = "build_stale"
	CodeBuildRateLimit = "build_rate_limited"
	CodeBadPlacement   = "invalid_placement"
	CodeVariantUnknown = "variant_unknown"
	CodeQueueFailed    = "build_queue_failed"
)

var errSpecs = map[error]httputil.ErrSpec{
	ErrBuildNotFound:  {Status: http.StatusNotFound, Code: CodeBuildNotFound, Message: "Build not found."},
	ErrBuildInFlight:  {Status: http.StatusConflict, Code: CodeBuildInFlight},
	ErrNotVerified:    {Status: http.StatusConflict, Code: CodeNotVerified},
	ErrBuildStale:     {Status: http.StatusConflict, Code: CodeBuildStale},
	ErrBuildRateLimit: {Status: http.StatusTooManyRequests, Code: CodeBuildRateLimit},
	ErrBadPlacement:   {Status: http.StatusUnprocessableEntity, Code: CodeBadPlacement},
	ErrVariantUnknown: {Status: http.StatusUnprocessableEntity, Code: CodeVariantUnknown},
	ErrNoWorker:       {Status: http.StatusServiceUnavailable, Code: CodeQueueFailed},
}

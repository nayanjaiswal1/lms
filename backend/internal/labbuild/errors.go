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
	// ErrPlatformRecipe: platform recipes are verified in CI and imported on
	// deploy (ImportLabset), never built in the app.
	ErrPlatformRecipe = errors.New("labbuild: platform labs are built and verified in CI, not in the app")
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
	CodePlatformRecipe = "platform_recipe"
	CodeLabsetMissing  = "labset_not_published"
	CodeLabsetMismatch = "labset_mismatch"
	CodeLabsetCorrupt  = "labset_corrupt"
)

var errSpecs = map[error]httputil.ErrSpec{
	ErrLabsetNotPublished: {Status: http.StatusNotFound, Code: CodeLabsetMissing},
	ErrLabsetRuntime:      {Status: http.StatusConflict, Code: CodeLabsetMismatch},
	ErrLabsetIncomplete:   {Status: http.StatusConflict, Code: CodeLabsetMismatch, Message: "The labset does not cover every platform recipe."},
	ErrLabsetRecipe:       {Status: http.StatusConflict, Code: CodeLabsetMismatch, Message: "The labset does not match this database's platform recipes."},
	ErrLabsetCorrupt:      {Status: http.StatusUnprocessableEntity, Code: CodeLabsetCorrupt, Message: "The published labset is corrupt."},
	ErrBuildNotFound:      {Status: http.StatusNotFound, Code: CodeBuildNotFound, Message: "Build not found."},
	ErrBuildInFlight:      {Status: http.StatusConflict, Code: CodeBuildInFlight},
	ErrNotVerified:        {Status: http.StatusConflict, Code: CodeNotVerified},
	ErrBuildStale:         {Status: http.StatusConflict, Code: CodeBuildStale},
	ErrBuildRateLimit:     {Status: http.StatusTooManyRequests, Code: CodeBuildRateLimit},
	ErrBadPlacement:       {Status: http.StatusUnprocessableEntity, Code: CodeBadPlacement},
	ErrVariantUnknown:     {Status: http.StatusUnprocessableEntity, Code: CodeVariantUnknown},
	ErrNoWorker:           {Status: http.StatusServiceUnavailable, Code: CodeQueueFailed},
	ErrPlatformRecipe:     {Status: http.StatusConflict, Code: CodePlatformRecipe},
}

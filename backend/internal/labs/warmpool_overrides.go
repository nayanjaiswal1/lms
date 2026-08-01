package labs

import (
	"fmt"
	"strconv"
	"strings"
)

// ParseWarmPoolOverrides parses LABS_WARM_POOL_OVERRIDES — a comma-separated
// "image=mode[:size]" list — into the planner's override map.
//
//	mindforge/lab-k8s:1.31=fixed:2     pin this image's pool at 2
//	mindforge/lab-docker:27=off        never pre-warm this image
//	mindforge/lab-python-web:3.12=auto:3   automatic, but ceiling 3 not 5
//
// Entries split on the FIRST "=" rather than the last colon (the trick
// LABS_IMAGE_PROFILES needs): an image reference always contains a colon for
// its tag and never an "=", so "=" is the only unambiguous separator here.
//
// Returns an error rather than exiting so the caller decides how a bad value
// fails; main.go treats it as fatal, because silently ignoring a typo'd
// override would leave an operator believing they had disabled warming for an
// image that is in fact still being warmed.
func ParseWarmPoolOverrides(raw string) (map[string]WarmPoolOverride, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	out := map[string]WarmPoolOverride{}
	for _, entry := range strings.Split(raw, ",") {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			continue
		}
		image, spec, found := strings.Cut(entry, "=")
		image, spec = strings.TrimSpace(image), strings.TrimSpace(spec)
		if !found || image == "" || spec == "" {
			return nil, fmt.Errorf("labs.ParseWarmPoolOverrides: entry %q is not image=mode[:size]", entry)
		}

		mode, sizeStr, hasSize := strings.Cut(spec, ":")
		override := WarmPoolOverride{Mode: strings.TrimSpace(mode)}
		switch override.Mode {
		case WarmPoolModeAuto, WarmPoolModeFixed, WarmPoolModeOff:
		default:
			return nil, fmt.Errorf("labs.ParseWarmPoolOverrides: entry %q has mode %q, want one of %s/%s/%s",
				entry, override.Mode, WarmPoolModeAuto, WarmPoolModeFixed, WarmPoolModeOff)
		}

		if hasSize {
			size, err := strconv.Atoi(strings.TrimSpace(sizeStr))
			if err != nil {
				return nil, fmt.Errorf("labs.ParseWarmPoolOverrides: entry %q has non-numeric size %q", entry, sizeStr)
			}
			if size < 0 || size > WarmPoolMaxOverrideSize {
				return nil, fmt.Errorf("labs.ParseWarmPoolOverrides: entry %q size %d out of range 0..%d", entry, size, WarmPoolMaxOverrideSize)
			}
			override.Size = size
		}

		// "fixed" with no size is almost certainly a typo for "off" — pinning a
		// pool at zero is what "off" is for, and silently reading it as zero
		// would look identical to a working override in the admin view.
		if override.Mode == WarmPoolModeFixed && !hasSize {
			return nil, fmt.Errorf("labs.ParseWarmPoolOverrides: entry %q uses mode fixed without a size (use %s=off to disable warming)", entry, image)
		}

		out[image] = override
	}
	return out, nil
}

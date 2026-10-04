package labblock

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Version is a strict MAJOR.MINOR.PATCH semantic version (no pre-release or
// build metadata: block versions are plain releases, and yank handles retraction).
type Version struct{ Major, Minor, Patch int }

var semverRe = regexp.MustCompile(`^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$`)

// ParseVersion parses "1.2.3".
func ParseVersion(s string) (Version, error) {
	m := semverRe.FindStringSubmatch(s)
	if m == nil {
		return Version{}, fmt.Errorf("labblock: %q is not a MAJOR.MINOR.PATCH version", s)
	}
	var v Version
	v.Major, _ = strconv.Atoi(m[1])
	v.Minor, _ = strconv.Atoi(m[2])
	v.Patch, _ = strconv.Atoi(m[3])
	return v, nil
}

func (v Version) String() string { return fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch) }

// Compare returns -1, 0 or 1.
func (v Version) Compare(o Version) int {
	for _, p := range [][2]int{{v.Major, o.Major}, {v.Minor, o.Minor}, {v.Patch, o.Patch}} {
		if p[0] != p[1] {
			if p[0] < p[1] {
				return -1
			}
			return 1
		}
	}
	return 0
}

// BumpPatch returns the next patch version.
func (v Version) BumpPatch() Version { return Version{v.Major, v.Minor, v.Patch + 1} }

// Range is a parsed version constraint: "" or "*" (any), "1" / "1.2" (x-range),
// "1.2.3" (exact), "^1.2" (compatible: same major, or same minor when major is
// 0), "~1.2" (same major.minor).
type Range struct {
	lo, hi Version // half-open [lo, hi); any=true ignores both
	any    bool
}

// ParseRange parses a constraint string.
func ParseRange(s string) (Range, error) {
	s = strings.TrimSpace(s)
	if s == "" || s == "*" {
		return Range{any: true}, nil
	}
	op := byte(0)
	if s[0] == '^' || s[0] == '~' {
		op, s = s[0], s[1:]
	}
	parts := strings.Split(s, ".")
	if len(parts) == 0 || len(parts) > 3 {
		return Range{}, fmt.Errorf("labblock: bad version range %q", s)
	}
	nums := [3]int{}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil || n < 0 {
			return Range{}, fmt.Errorf("labblock: bad version range %q", s)
		}
		nums[i] = n
	}
	lo := Version{nums[0], nums[1], nums[2]}
	var hi Version
	switch {
	case op == '^' && lo.Major > 0:
		hi = Version{lo.Major + 1, 0, 0}
	case op == '^' && lo.Minor > 0:
		hi = Version{0, lo.Minor + 1, 0}
	case op == '^':
		hi = Version{0, 0, lo.Patch + 1}
	case op == '~' || (op == 0 && len(parts) == 2):
		hi = Version{lo.Major, lo.Minor + 1, 0}
	case op == 0 && len(parts) == 1:
		hi = Version{lo.Major + 1, 0, 0}
	default: // exact
		hi = lo.BumpPatch()
	}
	return Range{lo: lo, hi: hi}, nil
}

// Contains reports whether v satisfies the range.
func (r Range) Contains(v Version) bool {
	return r.any || (v.Compare(r.lo) >= 0 && v.Compare(r.hi) < 0)
}

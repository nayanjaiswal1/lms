package labauthor

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/mindforge/backend/internal/labblock"
)

func sha256Hex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

// Capability tokens (docs/debug-labs.md §B1): "<kind>:<name>" with kind one of
// slot, cap, data, svc, env. A data token may carry a numeric predicate
// (data:rows>=5000); a `>=` requirement is satisfied by any provided `>=`/`=`
// bound of the same name that is at least as large.
var tokenKinds = map[string]bool{"slot": true, "cap": true, "data": true, "svc": true, "env": true}

var predicateRe = regexp.MustCompile(`^([A-Za-z0-9_.-]+)(>=|=)(\d+)$`)

// validToken reports whether s is a well-formed capability token.
func validToken(s string) bool {
	kind, name, ok := strings.Cut(s, ":")
	return ok && tokenKinds[kind] && name != ""
}

// providedTokens is every token b provides: its declared provides plus the
// ones implied by its kind section (an app's slots and services, a data
// block's row count, a stub's process).
func providedTokens(b *labblock.ResolvedBlock) []string {
	m := b.Manifest
	out := append([]string(nil), m.Provides...)
	if m.App != nil {
		for _, s := range m.App.Slots {
			out = append(out, "slot:"+s.Name)
		}
		for _, s := range m.App.Services {
			out = append(out, "svc:"+s)
		}
	}
	if m.Data != nil && m.Data.Rows > 0 {
		out = append(out, "data:rows>="+strconv.Itoa(m.Data.Rows))
	}
	if m.Stub != nil && m.Stub.Process != "" {
		out = append(out, "svc:"+m.Stub.Process)
	}
	return out
}

// tokenSatisfied reports whether req is met by any token in provided.
func tokenSatisfied(req string, provided []string) bool {
	rk, rn, _ := strings.Cut(req, ":")
	rm := predicateRe.FindStringSubmatch(rn)
	for _, p := range provided {
		if p == req {
			return true
		}
		if rm == nil || rm[2] != ">=" {
			continue
		}
		pk, pn, _ := strings.Cut(p, ":")
		pm := predicateRe.FindStringSubmatch(pn)
		if pk != rk || pm == nil || pm[1] != rm[1] {
			continue
		}
		want, _ := strconv.ParseInt(rm[3], 10, 64)
		have, _ := strconv.ParseInt(pm[3], 10, 64)
		if have >= want {
			return true
		}
	}
	return false
}

// checkCapabilities implements rules 2 and 5 over one concrete block set:
// every `requires` is met by the union of the other blocks' provides, and no
// block's `conflicts` entry matches another block's key or provided token.
func checkCapabilities(blocks []*labblock.ResolvedBlock) []labblock.Issue {
	var issues []labblock.Issue
	provides := make([][]string, len(blocks))
	for i, b := range blocks {
		provides[i] = providedTokens(b)
	}
	for i, b := range blocks {
		var pool []string
		for j := range blocks {
			pool = append(pool, provides[j]...)
		}
		for _, req := range b.Manifest.Requires {
			if !tokenSatisfied(req, pool) {
				issues = append(issues, labblock.Errf(labblock.CodeUnsatisfied, b.Key, fmt.Sprintf("requires %s, which no block in the recipe provides", req)))
			}
		}
		for _, c := range b.Manifest.Conflicts {
			for j, o := range blocks {
				if i == j {
					continue
				}
				if o.Key == c || contains(provides[j], c) {
					issues = append(issues, labblock.Errf(labblock.CodeConflict, b.Key, fmt.Sprintf("conflicts with %s (declared %q)", o.Key, c)))
				}
			}
		}
	}
	return issues
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

package labauthor

import (
	"encoding/json"
	"fmt"
	"sort"

	"github.com/mindforge/backend/internal/labblock"
)

const (
	// MaxVariants caps how many variants one build materialises and verifies
	// (docs/debug-labs.md §B6).
	MaxVariants = 8
	// maxPoolCombos bounds the fault-pool cross product the validator checks
	// exhaustively.
	maxPoolCombos = 64
	// DefaultVariantKey names the single variant of a recipe with no axes.
	DefaultVariantKey = "default"
)

// Variant is one materialised member of a recipe's variant product: which
// pool member is active for each pool, and the value of every unpinned
// randomizable parameter.
type Variant struct {
	// Key is deterministic: "default" for an axis-free recipe, else "v" +
	// the first 10 hex chars of sha256(canonical Assignment).
	Key string `json:"variant_key"`
	// Active are the block_version_ids that participate in this variant.
	Active []string `json:"active_block_version_ids"`
	// Assignment is {"pools": {pool: block_key}, "params": {"<block_key>.<param>": value}}.
	Assignment map[string]any `json:"assignment"`
	// Params overlays, per block key, the axis parameter values chosen for
	// this variant (on top of the block's effective params).
	Params map[string]map[string]any `json:"params"`
}

// activeSets expands pools: each returned set holds every unpooled block plus
// exactly one member of each pool. Sets are ordered deterministically (pools
// by name, members by block key).
func activeSets(r *labblock.Recipe) ([][]*labblock.ResolvedBlock, error) {
	pools := map[string][]*labblock.ResolvedBlock{}
	var fixed []*labblock.ResolvedBlock
	for _, b := range r.Blocks {
		if b.Ref.Pool == "" {
			fixed = append(fixed, b)
		} else {
			pools[b.Ref.Pool] = append(pools[b.Ref.Pool], b)
		}
	}
	names := sortedNames(pools)
	total := 1
	for _, n := range names {
		sort.Slice(pools[n], func(i, j int) bool { return pools[n][i].Key < pools[n][j].Key })
		total *= len(pools[n])
		if total > maxPoolCombos {
			return nil, fmt.Errorf("fault pools multiply to more than %d combinations", maxPoolCombos)
		}
	}
	sets := [][]*labblock.ResolvedBlock{append([]*labblock.ResolvedBlock(nil), fixed...)}
	for _, n := range names {
		var next [][]*labblock.ResolvedBlock
		for _, s := range sets {
			for _, m := range pools[n] {
				next = append(next, append(append([]*labblock.ResolvedBlock(nil), s...), m))
			}
		}
		sets = next
	}
	return sets, nil
}

// EnumerateVariants returns the recipe's variants (at most MaxVariants) and
// the size of the full product before capping. The product spans fault-pool
// choices and every unpinned `randomize` parameter of the active blocks; when
// it exceeds the cap, MaxVariants members are picked at evenly spaced indices
// so the sample is deterministic and spread across every axis. The recipe's
// effective params must already be resolved.
func EnumerateVariants(r *labblock.Recipe) (variants []Variant, total int, err error) {
	sets, err := activeSets(r)
	if err != nil {
		return nil, 0, err
	}
	type group struct {
		set  []*labblock.ResolvedBlock
		axes []axis
		size int
	}
	groups := make([]group, len(sets))
	for i, s := range sets {
		g := group{set: s, size: 1}
		for _, b := range s {
			g.axes = append(g.axes, paramAxes(b)...)
		}
		for _, a := range g.axes {
			g.size *= len(a.Values)
			if g.size > 1<<20 {
				g.size = 1 << 20 // saturate; only the sample matters past here
			}
		}
		groups[i] = g
		total += g.size
	}

	picks := make([]int, 0, MaxVariants)
	if total <= MaxVariants {
		for i := 0; i < total; i++ {
			picks = append(picks, i)
		}
	} else {
		for j := 0; j < MaxVariants; j++ {
			picks = append(picks, j*total/MaxVariants)
		}
	}

	for _, idx := range picks {
		gi := 0
		for idx >= groups[gi].size {
			idx -= groups[gi].size
			gi++
		}
		g := groups[gi]
		v := Variant{Params: map[string]map[string]any{}}
		pools := map[string]any{}
		params := map[string]any{}
		for _, b := range g.set {
			v.Active = append(v.Active, b.VersionID)
			if b.Ref.Pool != "" {
				pools[b.Ref.Pool] = b.Key
			}
		}
		sort.Strings(v.Active)
		rem := idx
		for i := len(g.axes) - 1; i >= 0; i-- {
			a := g.axes[i]
			val := a.Values[rem%len(a.Values)]
			rem /= len(a.Values)
			if v.Params[a.BlockKey] == nil {
				v.Params[a.BlockKey] = map[string]any{}
			}
			v.Params[a.BlockKey][a.Param] = val
			params[a.BlockKey+"."+a.Param] = val
		}
		v.Assignment = map[string]any{"pools": pools, "params": params}
		if len(pools) == 0 && len(params) == 0 {
			v.Key = DefaultVariantKey
		} else {
			raw, err := canonicalJSON(v.Assignment)
			if err != nil {
				return nil, 0, err
			}
			v.Key = "v" + sha256Hex(raw)[:10]
		}
		variants = append(variants, v)
	}
	return variants, total, nil
}

// canonicalJSON is the deterministic encoding hashes are computed over: the
// value is normalised (numbers to json.Number) and marshalled with sorted map
// keys, no HTML escaping variance (encoding/json is stable across runs).
func canonicalJSON(v any) ([]byte, error) {
	n, err := normalize(v)
	if err != nil {
		return nil, err
	}
	raw, err := json.Marshal(n)
	if err != nil {
		return nil, fmt.Errorf("labauthor.canonicalJSON: %w", err)
	}
	return raw, nil
}

// RecipeHash is sha256 of the canonical JSON of the resolved recipe: lab kind,
// seed, app range, difficulty override, and every block pinned by (key,
// version, content_hash) with its role, pool and effective params, ordered by
// (role, pool, key). Titles, org and owner are excluded, so identical
// compositions hash identically. Effective params must already be resolved
// (Analyze does this).
func RecipeHash(r *labblock.Recipe) (string, error) {
	type hb struct {
		Key         string         `json:"key"`
		Version     string         `json:"version"`
		ContentHash string         `json:"content_hash"`
		Role        string         `json:"role"`
		Pool        string         `json:"pool,omitempty"`
		Params      map[string]any `json:"params"`
	}
	blocks := make([]hb, 0, len(r.Blocks))
	for _, b := range r.Blocks {
		p := b.Params
		if p == nil {
			p = map[string]any{}
		}
		blocks = append(blocks, hb{b.Key, b.Version, b.ContentHash, b.Role(), b.Ref.Pool, p})
	}
	sort.Slice(blocks, func(i, j int) bool {
		a, b := blocks[i], blocks[j]
		if a.Role != b.Role {
			return a.Role < b.Role
		}
		if a.Pool != b.Pool {
			return a.Pool < b.Pool
		}
		return a.Key < b.Key
	})
	raw, err := canonicalJSON(map[string]any{
		"lab_kind":            r.LabKind,
		"app_range":           r.Spec.AppRange,
		"seed":                r.Spec.Seed,
		"difficulty_override": r.Spec.DifficultyOverride,
		"blocks":              blocks,
	})
	if err != nil {
		return "", err
	}
	return sha256Hex(raw), nil
}

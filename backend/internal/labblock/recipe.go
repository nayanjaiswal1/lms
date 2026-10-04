package labblock

// BlockRef is one pinned block in a recipe spec (lab_recipes.spec.blocks[]).
// A recipe always pins an exact lab_block_versions row: a block update never
// changes a recipe until the author takes it.
type BlockRef struct {
	BlockVersionID string `json:"block_version_id"`
	// Role defaults to the block's kind; it exists so a builder step can
	// label a block (e.g. two faults) without changing its kind.
	Role string `json:"role,omitempty"`
	// Pool groups interchangeable blocks: exactly one member of a pool is
	// picked per variant (a "fault pool", docs/debug-labs.md §B6).
	Pool string `json:"pool,omitempty"`
	// Chain makes this fault follow another fault of the recipe, overriding
	// any chain its manifest declares (docs/debug-labs.md §B2 rule 4). Only
	// valid on fault blocks; `after` is the other fault's block key.
	Chain *Chain `json:"chain,omitempty"`
	// Params are the author's explicit parameter values. A randomizable
	// param that is set here is pinned; one that is absent becomes a
	// variant axis.
	Params map[string]any `json:"params,omitempty"`
}

// Spec is the authored recipe body stored in lab_recipes.spec.
type Spec struct {
	// AppRange constrains the app block's version (semver range, e.g. "^1").
	AppRange string     `json:"app_range,omitempty"`
	Blocks   []BlockRef `json:"blocks"`
	// Seed makes git-history dates and any seeded randomness deterministic.
	Seed int64 `json:"seed,omitempty"`
	// DifficultyOverride lets the author override the derived difficulty.
	DifficultyOverride string `json:"difficulty_override,omitempty"`
}

// ResolvedBlock is a BlockRef joined to its stored version row.
type ResolvedBlock struct {
	Ref         BlockRef
	BlockID     string
	VersionID   string
	Key         string // manifest id (block_key)
	Version     string
	ContentHash string
	OrgID       *string // nil = platform-shipped
	Yanked      bool
	Manifest    *Manifest
	// Params are the effective parameter values: schema defaults, then a
	// matching preset, then the author's explicit values. Filled by the
	// engine before kind-specific validation runs.
	Params map[string]any
}

// Role returns the block's role in the recipe.
func (b *ResolvedBlock) Role() string {
	if b.Ref.Role != "" {
		return b.Ref.Role
	}
	return b.Manifest.Kind
}

// Recipe is a spec whose block refs have been resolved against the block
// store. It is what Validate, the hasher and the variant enumerator consume.
type Recipe struct {
	LabKind string
	OrgID   string
	Spec    Spec
	Blocks  []*ResolvedBlock
}

// ByKind returns the blocks whose manifest kind is kind, in spec order.
func (r *Recipe) ByKind(kind string) []*ResolvedBlock {
	var out []*ResolvedBlock
	for _, b := range r.Blocks {
		if b.Manifest.Kind == kind {
			out = append(out, b)
		}
	}
	return out
}

// ByKey returns the block with manifest id key, or nil.
func (r *Recipe) ByKey(key string) *ResolvedBlock {
	for _, b := range r.Blocks {
		if b.Key == key {
			return b
		}
	}
	return nil
}

// ParamValidator validates a set of explicit parameter values against a
// block's JSON Schema (defaults applied, unknown keys rejected). The engine
// hands one to lab-kind plugins so they can validate kind-specific parameter
// carriers (e.g. a fault's check-ref params) without importing the engine.
type ParamValidator func(b *ResolvedBlock, values map[string]any) []Issue

package canonical

import (
	"bytes"
	"fmt"
	"os"
	"strings"

	"github.com/mindforge/backend/internal/labblock"
	"gopkg.in/yaml.v3"
)

// RecipeSpec is a platform lab's recipe (the `recipe:` file a `kind: lab`
// document points at): a composition of pinned lab blocks
// (docs/debug-labs.md Part 2 B5 "Platform course content"). The generator
// emits it as an unpublished lab_recipes row; lab.platform_recipes_sync builds,
// verifies and publishes it.
type RecipeSpec struct {
	LabKind            string        `yaml:"lab_kind"`
	AppRange           string        `yaml:"app_range"`
	Seed               int64         `yaml:"seed"`
	DifficultyOverride string        `yaml:"difficulty_override"`
	Blocks             []RecipeBlock `yaml:"blocks"`
}

// RecipeBlock pins one block: "key@version", optionally in a pool, with params.
type RecipeBlock struct {
	Block  string         `yaml:"block"`
	Role   string         `yaml:"role"`
	Pool   string         `yaml:"pool"`
	Params map[string]any `yaml:"params"`
}

// LoadRecipe reads and strictly parses a recipe file.
func LoadRecipe(path string) (*RecipeSpec, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("canonical.LoadRecipe: %w", err)
	}
	var r RecipeSpec
	dec := yaml.NewDecoder(bytes.NewReader(raw))
	dec.KnownFields(true)
	if err := dec.Decode(&r); err != nil {
		return nil, fmt.Errorf("canonical.LoadRecipe: %s: %w", path, err)
	}
	return &r, nil
}

// validate checks the recipe's shape (block resolution against the block store
// happens at build time, where the validator runs on the real manifests).
func (r *RecipeSpec) validate(ctx string) []error {
	var errs []error
	if strings.TrimSpace(r.LabKind) == "" {
		errs = append(errs, fmt.Errorf("%s: recipe lab_kind is required", ctx))
	}
	if len(r.Blocks) == 0 {
		errs = append(errs, fmt.Errorf("%s: recipe lists no blocks", ctx))
	}
	for i, b := range r.Blocks {
		if key, version, ok := strings.Cut(b.Block, "@"); !ok || key == "" || version == "" {
			errs = append(errs, fmt.Errorf("%s: recipe block[%d] %q must be key@version", ctx, i, b.Block))
		}
	}
	return errs
}

// Spec converts the recipe to the stored lab_recipes.spec, pinning each block
// to its deterministic platform version id.
func (r *RecipeSpec) Spec() (labblock.Spec, error) {
	spec := labblock.Spec{AppRange: r.AppRange, Seed: r.Seed, DifficultyOverride: r.DifficultyOverride, Blocks: []labblock.BlockRef{}}
	for _, b := range r.Blocks {
		key, version, ok := strings.Cut(b.Block, "@")
		if !ok {
			return spec, fmt.Errorf("canonical.RecipeSpec.Spec: block %q must be key@version", b.Block)
		}
		spec.Blocks = append(spec.Blocks, labblock.BlockRef{
			BlockVersionID: LabBlockVersionID(key, version), Role: b.Role, Pool: b.Pool, Params: b.Params,
		})
	}
	return spec, nil
}

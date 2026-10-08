package labauthor

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/google/uuid"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
)

const (
	maxRecipeBlocks  = 30
	maxSpecBytes     = 64 << 10
	maxTitleLen      = 200
	maxSummaryLen    = 1000
	maxRefStringLen  = 64
	initialVersion   = "1.0.0"
	textBlockKeyBase = "org"
)

// Service is the lab-authoring application layer: it joins the repo to the
// kind-agnostic engine (Analyze) and enforces the trust boundary on input.
type Service struct {
	repo  *Repo
	draft *Drafter
}

// NewService builds a Service. draft may be nil (ticket drafting then reports
// ErrAIUnavailable).
func NewService(repo *Repo, draft *Drafter) *Service { return &Service{repo: repo, draft: draft} }

// Repo exposes the persistence layer to the build/publish phase.
func (s *Service) Repo() *Repo { return s.repo }

// ─── recipes ────────────────────────────────────────────────────────────────

// RecipeInput is the writable part of a recipe.
type RecipeInput struct {
	LabKind         string          `json:"lab_kind"`
	Title           string          `json:"title"`
	Spec            labblock.Spec   `json:"spec"`
	TargetPlacement json.RawMessage `json:"target_placement"`
	// Revision is required on update: the revision the client last saw.
	Revision int `json:"revision"`
}

func versionIDs(spec labblock.Spec) []string {
	ids := make([]string, 0, len(spec.Blocks))
	for _, b := range spec.Blocks {
		ids = append(ids, b.BlockVersionID)
	}
	return ids
}

// checkInput validates a recipe write: shape limits, registered lab kind, and
// that every referenced block version is visible to the org (a foreign org's
// block is reported as not found) and not newly pinned while yanked.
func (s *Service) checkInput(ctx context.Context, orgID string, in *RecipeInput, previous *labblock.Spec) error {
	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" || len(in.Title) > maxTitleLen {
		return fmt.Errorf("%w: title is required (max %d characters)", ErrInvalidInput, maxTitleLen)
	}
	if _, ok := labkinds.Get(in.LabKind); !ok {
		return fmt.Errorf("%w: %q", ErrUnknownLabKind, in.LabKind)
	}
	if len(in.Spec.Blocks) > maxRecipeBlocks {
		return fmt.Errorf("%w: at most %d blocks per recipe", ErrInvalidInput, maxRecipeBlocks)
	}
	if raw, err := json.Marshal(in.Spec); err != nil || len(raw) > maxSpecBytes {
		return fmt.Errorf("%w: spec is too large", ErrInvalidInput)
	}
	if len(in.TargetPlacement) > 0 && !json.Valid(in.TargetPlacement) {
		return fmt.Errorf("%w: target_placement is not valid JSON", ErrInvalidInput)
	}
	for _, b := range in.Spec.Blocks {
		if _, err := uuid.Parse(b.BlockVersionID); err != nil {
			return fmt.Errorf("%w: block_version_id %q is not a UUID", ErrInvalidInput, b.BlockVersionID)
		}
		if len(b.Role) > maxRefStringLen || len(b.Pool) > maxRefStringLen {
			return fmt.Errorf("%w: role/pool too long", ErrInvalidInput)
		}
		if b.Pool != "" && !poolNameRe.MatchString(b.Pool) {
			return fmt.Errorf("%w: pool names use lowercase letters, digits, - and _", ErrInvalidInput)
		}
		if b.Chain != nil && (b.Chain.After == "" || len(b.Chain.After) > maxRefStringLen*2 ||
			(b.Chain.Mode != labblock.ChainMasks && b.Chain.Mode != labblock.ChainCompounds)) {
			return fmt.Errorf("%w: a chain needs an `after` fault and a mode of %s or %s", ErrInvalidInput, labblock.ChainMasks, labblock.ChainCompounds)
		}
	}
	if in.Spec.DifficultyOverride != "" && !contains(labblock.Difficulties, in.Spec.DifficultyOverride) {
		return fmt.Errorf("%w: difficulty_override must be one of %s", ErrInvalidInput, strings.Join(labblock.Difficulties, "|"))
	}
	if in.Spec.AppRange != "" {
		if _, err := labblock.ParseRange(in.Spec.AppRange); err != nil {
			return fmt.Errorf("%w: app_range: %v", ErrInvalidInput, err)
		}
	}

	vers, err := s.repo.ResolveVersions(ctx, orgID, versionIDs(in.Spec))
	if err != nil {
		return fmt.Errorf("labauthor.checkInput: %w", err)
	}
	prev := map[string]bool{}
	if previous != nil {
		for _, id := range versionIDs(*previous) {
			prev[id] = true
		}
	}
	var issues []labblock.Issue
	for _, b := range in.Spec.Blocks {
		v, ok := vers[b.BlockVersionID]
		switch {
		case !ok:
			issues = append(issues, labblock.Errf(labblock.CodeBlockNotFound, b.BlockVersionID, "block version not found or not visible to your organization"))
		case v.Yanked && !prev[b.BlockVersionID]:
			issues = append(issues, labblock.Errf(labblock.CodeBlockYanked, v.Key, fmt.Sprintf("version %s was yanked and cannot be added", v.Version)))
		case v.OrgID != nil && *v.OrgID != orgID:
			issues = append(issues, labblock.Errf(labblock.CodeBlockForeignOrg, v.Key, "block belongs to another organization"))
		case !KindAllows(in.LabKind, v.Manifest.Kind):
			issues = append(issues, labblock.Errf(labblock.CodeUnknownKind, v.Key, fmt.Sprintf("%s blocks are not valid in a %s recipe", v.Manifest.Kind, in.LabKind)))
		case b.Chain != nil && v.Manifest.Kind != "fault":
			issues = append(issues, labblock.Errf(labblock.CodeChainInvalid, v.Key, "only faults can be chained"))
		}
	}
	if len(issues) > 0 {
		return &InvalidRecipeError{Analysis: &Analysis{Issues: issues}}
	}
	return nil
}

// CreateRecipe saves a new recipe. Work-in-progress compositions are allowed
// (validation runs separately, on every wizard step); only structurally
// unacceptable input is refused.
func (s *Service) CreateRecipe(ctx context.Context, orgID, userID string, in RecipeInput) (*Recipe, error) {
	if err := s.checkInput(ctx, orgID, &in, nil); err != nil {
		return nil, fmt.Errorf("labauthor.CreateRecipe: %w", err)
	}
	return s.repo.CreateRecipe(ctx, orgID, userID, in.LabKind, in.Title, in.Spec, in.TargetPlacement)
}

// UpdateRecipe saves a recipe under optimistic concurrency (in.Revision).
func (s *Service) UpdateRecipe(ctx context.Context, orgID, id string, in RecipeInput) (*Recipe, error) {
	cur, err := s.repo.GetRecipe(ctx, orgID, id)
	if err != nil {
		return nil, fmt.Errorf("labauthor.UpdateRecipe: %w", err)
	}
	if in.LabKind == "" {
		in.LabKind = cur.LabKind
	}
	if in.LabKind != cur.LabKind {
		return nil, fmt.Errorf("%w: lab_kind cannot change", ErrInvalidInput)
	}
	if err := s.checkInput(ctx, orgID, &in, &cur.Spec); err != nil {
		return nil, fmt.Errorf("labauthor.UpdateRecipe: %w", err)
	}
	return s.repo.UpdateRecipe(ctx, orgID, id, in.Title, in.Spec, in.TargetPlacement, in.Revision)
}

// Resolve loads the recipe's pinned blocks and builds the engine model. The
// returned issues cover refs that could not be resolved.
func (s *Service) Resolve(ctx context.Context, rc *Recipe) (*labblock.Recipe, []labblock.Issue, error) {
	vers, err := s.repo.ResolveVersions(ctx, rc.OrgID, versionIDs(rc.Spec))
	if err != nil {
		return nil, nil, fmt.Errorf("labauthor.Resolve: %w", err)
	}
	r, issues := BuildRecipe(rc.LabKind, rc.OrgID, rc.Spec, vers)
	return r, issues, nil
}

// Validate runs the composition validator over a stored recipe. No side effects.
func (s *Service) Validate(ctx context.Context, orgID, id string) (*Analysis, error) {
	rc, err := s.repo.GetRecipe(ctx, orgID, id)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Validate: %w", err)
	}
	return s.analyze(ctx, rc)
}

func (s *Service) analyze(ctx context.Context, rc *Recipe) (*Analysis, error) {
	r, missing, err := s.Resolve(ctx, rc)
	if err != nil {
		return nil, fmt.Errorf("labauthor.analyze: %w", err)
	}
	if len(missing) > 0 {
		return &Analysis{Issues: missing}, nil
	}
	return Analyze(r), nil
}

// BlockRefView describes one pinned block for the recipe GET response.
type BlockRefView struct {
	BlockVersionID string `json:"block_version_id"`
	BlockID        string `json:"block_id"`
	Key            string `json:"block_key"`
	Kind           string `json:"kind"`
	Version        string `json:"version"`
	Title          string `json:"title"`
	Yanked         bool   `json:"yanked"`
	OrgOwned       bool   `json:"org_owned"`
}

// UpdateAvailable says a pinned block should move to another version. Usually
// a newer non-yanked version exists; when the pinned version was yanked it is
// the newest non-yanked one even if older (a roll-back). Taking it means a new
// recipe revision -> build -> verify -> republish.
type UpdateAvailable struct {
	BlockID         string `json:"block_id"`
	BlockKey        string `json:"block_key"`
	PinnedVersionID string `json:"pinned_version_id"`
	PinnedVersion   string `json:"pinned_version"`
	PinnedYanked    bool   `json:"pinned_yanked"`
	LatestVersionID string `json:"latest_version_id"`
	LatestVersion   string `json:"latest_version"`
	Changelog       string `json:"changelog"`
}

// RecipeView is the recipe GET payload.
type RecipeView struct {
	Recipe  *Recipe           `json:"recipe"`
	Blocks  []BlockRefView    `json:"blocks"`
	Updates []UpdateAvailable `json:"updates"`
}

// blockViews describes the blocks a spec pins (refs that cannot be resolved
// are skipped; the validator reports them).
func blockViews(spec labblock.Spec, vers map[string]*labblock.ResolvedBlock) []BlockRefView {
	out := []BlockRefView{}
	for _, ref := range spec.Blocks {
		if v, ok := vers[ref.BlockVersionID]; ok {
			out = append(out, BlockRefView{
				BlockVersionID: v.VersionID, BlockID: v.BlockID, Key: v.Key, Kind: v.Manifest.Kind,
				Version: v.Version, Title: v.Manifest.Title, Yanked: v.Yanked, OrgOwned: v.OrgID != nil,
			})
		}
	}
	return out
}

// updatesFor computes the available updates of several recipes' pinned blocks
// with a single query for the live versions. The result is parallel to groups.
func (s *Service) updatesFor(ctx context.Context, groups [][]BlockRefView) ([][]UpdateAvailable, error) {
	seen := map[string]bool{}
	var ids []string
	for _, g := range groups {
		for _, b := range g {
			if !seen[b.BlockID] {
				seen[b.BlockID] = true
				ids = append(ids, b.BlockID)
			}
		}
	}
	live, err := s.repo.LiveVersions(ctx, ids)
	if err != nil {
		return nil, fmt.Errorf("labauthor.updatesFor: %w", err)
	}
	latest := map[string]VersionRef{}
	for _, l := range live {
		if cur, ok := latest[l.BlockID]; !ok || versionLess(cur.Version, l.Version) {
			latest[l.BlockID] = l
		}
	}
	out := make([][]UpdateAvailable, len(groups))
	for i, g := range groups {
		out[i] = []UpdateAvailable{}
		for _, b := range g {
			l, ok := latest[b.BlockID]
			if !ok || l.ID == b.BlockVersionID || !(b.Yanked || versionLess(b.Version, l.Version)) {
				continue
			}
			out[i] = append(out[i], UpdateAvailable{
				BlockID: b.BlockID, BlockKey: b.Key, PinnedVersionID: b.BlockVersionID, PinnedVersion: b.Version,
				PinnedYanked: b.Yanked, LatestVersionID: l.ID, LatestVersion: l.Version, Changelog: l.Changelog,
			})
		}
	}
	return out, nil
}

// GetRecipeView returns the recipe, its pinned blocks, and available updates.
func (s *Service) GetRecipeView(ctx context.Context, orgID, id string) (*RecipeView, error) {
	rc, err := s.repo.GetRecipe(ctx, orgID, id)
	if err != nil {
		return nil, fmt.Errorf("labauthor.GetRecipeView: %w", err)
	}
	if err := s.attachState(ctx, orgID, []*Recipe{rc}); err != nil {
		return nil, fmt.Errorf("labauthor.GetRecipeView: %w", err)
	}
	vers, err := s.repo.ResolveVersions(ctx, orgID, versionIDs(rc.Spec))
	if err != nil {
		return nil, fmt.Errorf("labauthor.GetRecipeView: %w", err)
	}
	blocks := blockViews(rc.Spec, vers)
	updates, err := s.updatesFor(ctx, [][]BlockRefView{blocks})
	if err != nil {
		return nil, fmt.Errorf("labauthor.GetRecipeView: %w", err)
	}
	return &RecipeView{Recipe: rc, Blocks: blocks, Updates: updates[0]}, nil
}

// ListRecipes lists the org's recipes with their latest build and the number
// of pending block updates / yanked pins (the list's "update available" badge).
func (s *Service) ListRecipes(ctx context.Context, orgID string, limit, offset int) ([]*Recipe, error) {
	rs, err := s.repo.ListRecipes(ctx, orgID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("labauthor.ListRecipes: %w", err)
	}
	if err := s.attachState(ctx, orgID, rs); err != nil {
		return nil, fmt.Errorf("labauthor.ListRecipes: %w", err)
	}
	return rs, nil
}

// attachState fills each recipe's latest build, update count and yanked count.
func (s *Service) attachState(ctx context.Context, orgID string, rs []*Recipe) error {
	if err := s.repo.AttachLatestBuilds(ctx, rs); err != nil {
		return fmt.Errorf("labauthor.attachState: %w", err)
	}
	var ids []string
	for _, rc := range rs {
		ids = append(ids, versionIDs(rc.Spec)...)
	}
	vers, err := s.repo.ResolveVersions(ctx, orgID, ids)
	if err != nil {
		return fmt.Errorf("labauthor.attachState: %w", err)
	}
	groups := make([][]BlockRefView, len(rs))
	for i, rc := range rs {
		groups[i] = blockViews(rc.Spec, vers)
	}
	updates, err := s.updatesFor(ctx, groups)
	if err != nil {
		return fmt.Errorf("labauthor.attachState: %w", err)
	}
	for i, rc := range rs {
		rc.UpdatesAvailable = len(updates[i])
		for _, b := range groups[i] {
			if b.Yanked {
				rc.YankedBlocks++
			}
		}
	}
	return nil
}

// ─── text blocks ────────────────────────────────────────────────────────────

var (
	slugRe     = regexp.MustCompile(`[^a-z0-9]+`)
	poolNameRe = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]*$`)
)

func slugify(s string) string {
	return strings.Trim(slugRe.ReplaceAllString(strings.ToLower(s), "-"), "-")
}

// prepareTextManifest enforces the trust boundary for org-authored blocks:
// only the text kinds, only markdown/params content, nothing executable
// (no params schema, capability tokens or budgets), then structural validation.
func prepareTextManifest(m *labblock.Manifest, defaultVersion string) error {
	if !IsTextKind(m.Kind) {
		return ErrBlockNotEditable
	}
	if len(m.Params) > 0 || len(m.Requires) > 0 || len(m.Provides) > 0 || len(m.Conflicts) > 0 || m.Budget != (labblock.Budget{}) {
		return fmt.Errorf("%w: text blocks cannot declare params, requires, provides, conflicts or a budget", ErrInvalidInput)
	}
	if m.Ticket != nil && m.Ticket.TemplateFile != "" {
		return fmt.Errorf("%w: org ticket blocks must use template_md (there is no payload to read a file from)", ErrInvalidInput)
	}
	if len(m.Title) > maxTitleLen || len(m.Summary) > maxSummaryLen {
		return fmt.Errorf("%w: title/summary too long", ErrInvalidInput)
	}
	if m.Stack == "" {
		m.Stack = "any"
	}
	if m.Version == "" {
		m.Version = defaultVersion
	}
	if m.ID == "" {
		slug := slugify(m.Title)
		if slug == "" {
			return fmt.Errorf("%w: a title is required", ErrInvalidInput)
		}
		m.ID = fmt.Sprintf("%s.%s.%s", textBlockKeyBase, m.Kind, slug)
	}
	if issues := ValidateManifest(m); labblock.HasErrors(issues) {
		return &InvalidRecipeError{Analysis: &Analysis{Issues: issues}}
	}
	return nil
}

// CreateTextBlock creates an org-owned text block with its first version.
func (s *Service) CreateTextBlock(ctx context.Context, orgID, userID string, m labblock.Manifest) (blockID, versionID string, err error) {
	if err := prepareTextManifest(&m, initialVersion); err != nil {
		return "", "", fmt.Errorf("labauthor.CreateTextBlock: %w", err)
	}
	return s.repo.CreateTextBlock(ctx, orgID, userID, &m, m.Changelog)
}

// UpdateTextBlock adds a new immutable version to an org-owned text block. The
// version defaults to the previous one's patch bump; an existing version string
// is refused (ErrVersionImmutable).
func (s *Service) UpdateTextBlock(ctx context.Context, orgID, userID, blockID string, m labblock.Manifest) (string, error) {
	prev, err := s.repo.LatestManifest(ctx, orgID, blockID)
	if err != nil {
		return "", fmt.Errorf("labauthor.UpdateTextBlock: %w", err)
	}
	next := initialVersion
	if pv, perr := labblock.ParseVersion(prev.Version); perr == nil {
		next = pv.BumpPatch().String()
	}
	m.ID, m.Kind = prev.ID, prev.Kind // identity is fixed across versions
	if err := prepareTextManifest(&m, next); err != nil {
		return "", fmt.Errorf("labauthor.UpdateTextBlock: %w", err)
	}
	return s.repo.AddTextVersion(ctx, orgID, userID, blockID, &m, m.Changelog)
}

// DeleteTextBlock removes an unused org-owned text block.
func (s *Service) DeleteTextBlock(ctx context.Context, orgID, blockID string) error {
	return s.repo.DeleteTextBlock(ctx, orgID, blockID)
}

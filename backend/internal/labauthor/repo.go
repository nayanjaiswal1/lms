package labauthor

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/labblock"
)

// Repo is the lab-authoring persistence layer (lab_blocks, lab_block_versions,
// lab_recipes, lab_ai_drafts). Every query that returns block or recipe data
// takes the caller's orgID and scopes by it: platform blocks (org_id NULL) are
// visible to everyone, org blocks and recipes only to their org.
type Repo struct{ pool *pgxpool.Pool }

// NewRepo returns a Repo over pool.
func NewRepo(pool *pgxpool.Pool) *Repo { return &Repo{pool: pool} }

const (
	pgUniqueViolation     = "23505"
	pgForeignKeyViolation = "23503"
	// semverOrder sorts a lab_block_versions row by its semantic version.
	semverOrder = `string_to_array(v.version, '.')::int[]`
)

func pgCode(err error) (code, constraint string) {
	var pe *pgconn.PgError
	if errors.As(err, &pe) {
		return pe.Code, pe.ConstraintName
	}
	return "", ""
}

// ─── blocks ─────────────────────────────────────────────────────────────────

// BlockSummary is one library row: a block and its newest non-yanked version.
type BlockSummary struct {
	ID              string   `json:"id"`
	OrgID           *string  `json:"org_id"`
	Key             string   `json:"block_key"`
	Kind            string   `json:"kind"`
	Stack           string   `json:"stack"`
	LatestVersionID string   `json:"latest_version_id"`
	LatestVersion   string   `json:"latest_version"`
	Title           string   `json:"title"`
	Summary         string   `json:"summary"`
	Category        string   `json:"category"`
	Difficulty      string   `json:"difficulty"`
	Skills          []string `json:"skills"`
	// OrgOwned is true for blocks the caller's org authored (editable text
	// blocks); false for platform-shipped blocks.
	OrgOwned bool `json:"org_owned"`
}

// BlockFilter narrows ListBlocks.
type BlockFilter struct {
	Kind, Stack, Category string
	Limit, Offset         int
}

// ListBlocks lists the blocks visible to orgID, each with its newest
// non-yanked version (blocks whose every version is yanked are omitted).
func (r *Repo) ListBlocks(ctx context.Context, orgID string, f BlockFilter) ([]BlockSummary, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT b.id, b.org_id, b.block_key, b.kind, b.stack, v.id, v.version,
		       COALESCE(v.manifest->>'title',''), COALESCE(v.manifest->>'summary',''),
		       COALESCE(v.manifest->>'category',''), COALESCE(v.manifest->>'difficulty',''),
		       COALESCE(v.manifest->'skills','[]'::jsonb)
		FROM public.lab_blocks b
		JOIN LATERAL (
		    SELECT v.* FROM public.lab_block_versions v
		    WHERE v.block_id = b.id AND v.yanked_at IS NULL
		    ORDER BY `+semverOrder+` DESC LIMIT 1
		) v ON true
		WHERE (b.org_id IS NULL OR b.org_id = $1)
		  AND ($2 = '' OR b.kind = $2)
		  AND ($3 = '' OR b.stack = $3)
		  AND ($4 = '' OR v.manifest->>'category' = $4)
		ORDER BY b.kind, b.block_key
		LIMIT $5 OFFSET $6`,
		orgID, f.Kind, f.Stack, f.Category, f.Limit, f.Offset)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.ListBlocks: %w", err)
	}
	defer rows.Close()
	out := []BlockSummary{}
	for rows.Next() {
		var s BlockSummary
		var skills []byte
		if err := rows.Scan(&s.ID, &s.OrgID, &s.Key, &s.Kind, &s.Stack, &s.LatestVersionID, &s.LatestVersion,
			&s.Title, &s.Summary, &s.Category, &s.Difficulty, &skills); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.ListBlocks: scan: %w", err)
		}
		if err := json.Unmarshal(skills, &s.Skills); err != nil || s.Skills == nil {
			s.Skills = []string{}
		}
		s.OrgOwned = s.OrgID != nil
		out = append(out, s)
	}
	return out, rows.Err()
}

// BlockVersionInfo is one version row in a block's detail view.
type BlockVersionInfo struct {
	ID          string          `json:"id"`
	Version     string          `json:"version"`
	ContentHash string          `json:"content_hash"`
	Changelog   string          `json:"changelog"`
	Manifest    json.RawMessage `json:"manifest"`
	HasPayload  bool            `json:"has_payload"`
	YankedAt    *time.Time      `json:"yanked_at"`
	YankedWhy   *string         `json:"yanked_reason"`
	CreatedAt   time.Time       `json:"created_at"`
	// RecipeCount is how many of the caller's org's recipes pin this
	// version; LabCount how many published labs were built from it.
	RecipeCount int `json:"recipe_count"`
	LabCount    int `json:"lab_count"`
}

// BlockDetail is a block with its full version history, newest first.
type BlockDetail struct {
	ID       string             `json:"id"`
	OrgID    *string            `json:"org_id"`
	Key      string             `json:"block_key"`
	Kind     string             `json:"kind"`
	Stack    string             `json:"stack"`
	OrgOwned bool               `json:"org_owned"`
	Versions []BlockVersionInfo `json:"versions"`
}

// GetBlock returns a block visible to orgID with all of its versions, or
// ErrBlockNotFound.
func (r *Repo) GetBlock(ctx context.Context, orgID, blockID string) (*BlockDetail, error) {
	var d BlockDetail
	err := r.pool.QueryRow(ctx, `
		SELECT id, org_id, block_key, kind, stack FROM public.lab_blocks
		WHERE id = $1 AND (org_id IS NULL OR org_id = $2)`, blockID, orgID).
		Scan(&d.ID, &d.OrgID, &d.Key, &d.Kind, &d.Stack)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrBlockNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.GetBlock: %w", err)
	}
	d.OrgOwned = d.OrgID != nil
	rows, err := r.pool.Query(ctx, `
		SELECT v.id, v.version, v.content_hash, COALESCE(v.changelog,''), v.manifest,
		       v.payload_key IS NOT NULL, v.yanked_at, v.yanked_reason, v.created_at,
		       (SELECT count(*) FROM public.lab_recipes rc WHERE rc.org_id = $2
		          AND rc.spec->'blocks' @> jsonb_build_array(jsonb_build_object('block_version_id', v.id::text))),
		       (SELECT count(DISTINCT ld.id) FROM public.lab_block_usages u
		          JOIN public.lab_definitions ld ON ld.build_id = u.build_id
		          WHERE u.block_version_id = v.id AND ld.org_id = $2)
		FROM public.lab_block_versions v WHERE v.block_id = $1
		ORDER BY `+semverOrder+` DESC`, blockID, orgID)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.GetBlock: versions: %w", err)
	}
	defer rows.Close()
	d.Versions = []BlockVersionInfo{}
	for rows.Next() {
		var v BlockVersionInfo
		if err := rows.Scan(&v.ID, &v.Version, &v.ContentHash, &v.Changelog, &v.Manifest, &v.HasPayload,
			&v.YankedAt, &v.YankedWhy, &v.CreatedAt, &v.RecipeCount, &v.LabCount); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.GetBlock: scan: %w", err)
		}
		d.Versions = append(d.Versions, v)
	}
	return &d, rows.Err()
}

// ResolveVersions loads block versions by id as ResolvedBlock templates,
// restricted to blocks visible to orgID (platform + own org). Ids that do not
// exist or belong to another org are simply absent from the result.
func (r *Repo) ResolveVersions(ctx context.Context, orgID string, ids []string) (map[string]*labblock.ResolvedBlock, error) {
	out := map[string]*labblock.ResolvedBlock{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT v.id, b.id, b.block_key, b.org_id, v.version, v.content_hash, v.manifest, v.yanked_at IS NOT NULL
		FROM public.lab_block_versions v
		JOIN public.lab_blocks b ON b.id = v.block_id
		WHERE v.id = ANY($1::uuid[]) AND (b.org_id IS NULL OR b.org_id = $2)`, ids, orgID)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.ResolveVersions: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var rb labblock.ResolvedBlock
		var raw []byte
		if err := rows.Scan(&rb.VersionID, &rb.BlockID, &rb.Key, &rb.OrgID, &rb.Version, &rb.ContentHash, &raw, &rb.Yanked); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.ResolveVersions: scan: %w", err)
		}
		m, err := labblock.ManifestFromJSON(raw)
		if err != nil {
			return nil, fmt.Errorf("labauthor.Repo.ResolveVersions: %s@%s: %w", rb.Key, rb.Version, err)
		}
		rb.Manifest = m
		out[rb.VersionID] = &rb
	}
	return out, rows.Err()
}

// VersionRef is a lightweight (version id, semver, changelog) tuple.
type VersionRef struct {
	ID        string
	BlockID   string
	Version   string
	Changelog string
}

// LiveVersions returns every non-yanked version of the given blocks.
func (r *Repo) LiveVersions(ctx context.Context, blockIDs []string) ([]VersionRef, error) {
	if len(blockIDs) == 0 {
		return nil, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT v.id, v.block_id, v.version, COALESCE(v.changelog,'')
		FROM public.lab_block_versions v
		WHERE v.block_id = ANY($1::uuid[]) AND v.yanked_at IS NULL`, blockIDs)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.LiveVersions: %w", err)
	}
	defer rows.Close()
	var out []VersionRef
	for rows.Next() {
		var v VersionRef
		if err := rows.Scan(&v.ID, &v.BlockID, &v.Version, &v.Changelog); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.LiveVersions: scan: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// CreateTextBlock inserts an org-owned block and its first version in one
// transaction. Returns ErrBlockKeyTaken if the org already has that key.
func (r *Repo) CreateTextBlock(ctx context.Context, orgID, userID string, m *labblock.Manifest, changelog string) (blockID, versionID string, err error) {
	raw, err := m.CanonicalJSON()
	if err != nil {
		return "", "", err
	}
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return "", "", fmt.Errorf("labauthor.Repo.CreateTextBlock: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := tx.QueryRow(ctx, `
		INSERT INTO public.lab_blocks (id, org_id, block_key, kind, stack)
		VALUES (gen_random_uuid(), $1, $2, $3, $4) RETURNING id`, orgID, m.ID, m.Kind, m.Stack).Scan(&blockID); err != nil {
		if code, _ := pgCode(err); code == pgUniqueViolation {
			return "", "", ErrBlockKeyTaken
		}
		return "", "", fmt.Errorf("labauthor.Repo.CreateTextBlock: block: %w", err)
	}
	versionID, err = insertVersion(ctx, tx, blockID, userID, m, raw, changelog)
	if err != nil {
		return "", "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", "", fmt.Errorf("labauthor.Repo.CreateTextBlock: commit: %w", err)
	}
	return blockID, versionID, nil
}

func insertVersion(ctx context.Context, tx pgx.Tx, blockID, userID string, m *labblock.Manifest, raw []byte, changelog string) (string, error) {
	var id string
	err := tx.QueryRow(ctx, `
		INSERT INTO public.lab_block_versions (block_id, version, content_hash, manifest, changelog, created_by)
		VALUES ($1, $2, $3, $4::jsonb, NULLIF($5,''), $6) RETURNING id`,
		blockID, m.Version, sha256Hex(raw), raw, changelog, userID).Scan(&id)
	if err != nil {
		code, constraint := pgCode(err)
		switch {
		case code == pgUniqueViolation && constraint == "lab_block_versions_block_id_version_key":
			return "", ErrVersionImmutable
		case code == pgUniqueViolation:
			return "", ErrNoChange
		}
		return "", fmt.Errorf("labauthor.Repo.insertVersion: %w", err)
	}
	return id, nil
}

// AddTextVersion appends an immutable version to an org-owned text block.
// ErrBlockNotFound if the block is not the org's; ErrVersionImmutable if the
// version string already exists; ErrNoChange if the content equals an
// existing version.
func (r *Repo) AddTextVersion(ctx context.Context, orgID, userID, blockID string, m *labblock.Manifest, changelog string) (string, error) {
	raw, err := m.CanonicalJSON()
	if err != nil {
		return "", err
	}
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("labauthor.Repo.AddTextVersion: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var key, kind string
	err = tx.QueryRow(ctx, `SELECT block_key, kind FROM public.lab_blocks WHERE id = $1 AND org_id = $2 FOR UPDATE`, blockID, orgID).Scan(&key, &kind)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrBlockNotFound
	}
	if err != nil {
		return "", fmt.Errorf("labauthor.Repo.AddTextVersion: lock: %w", err)
	}
	if key != m.ID || kind != m.Kind {
		return "", ErrBlockIdentity
	}
	id, err := insertVersion(ctx, tx, blockID, userID, m, raw, changelog)
	if err != nil {
		return "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("labauthor.Repo.AddTextVersion: commit: %w", err)
	}
	return id, nil
}

// LatestManifest returns the newest version's manifest of an org-owned block
// (used to default the next version number on edit).
func (r *Repo) LatestManifest(ctx context.Context, orgID, blockID string) (*labblock.Manifest, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx, `
		SELECT v.manifest FROM public.lab_block_versions v
		JOIN public.lab_blocks b ON b.id = v.block_id
		WHERE b.id = $1 AND b.org_id = $2
		ORDER BY `+semverOrder+` DESC LIMIT 1`, blockID, orgID).Scan(&raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrBlockNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.LatestManifest: %w", err)
	}
	return labblock.ManifestFromJSON(raw)
}

// DeleteTextBlock removes an org-owned block and its versions, unless a
// recipe pins one of its versions or a build used it (ErrBlockInUse).
func (r *Repo) DeleteTextBlock(ctx context.Context, orgID, blockID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("labauthor.Repo.DeleteTextBlock: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var exists bool
	if err := tx.QueryRow(ctx, `SELECT true FROM public.lab_blocks WHERE id = $1 AND org_id = $2 FOR UPDATE`, blockID, orgID).Scan(&exists); errors.Is(err, pgx.ErrNoRows) {
		return ErrBlockNotFound
	} else if err != nil {
		return fmt.Errorf("labauthor.Repo.DeleteTextBlock: lock: %w", err)
	}
	var inUse bool
	if err := tx.QueryRow(ctx, `
		SELECT EXISTS (
		    SELECT 1 FROM public.lab_block_versions v
		    JOIN public.lab_recipes rc ON rc.org_id = $2
		         AND rc.spec->'blocks' @> jsonb_build_array(jsonb_build_object('block_version_id', v.id::text))
		    WHERE v.block_id = $1
		) OR EXISTS (
		    SELECT 1 FROM public.lab_block_usages u
		    JOIN public.lab_block_versions v ON v.id = u.block_version_id WHERE v.block_id = $1
		)`, blockID, orgID).Scan(&inUse); err != nil {
		return fmt.Errorf("labauthor.Repo.DeleteTextBlock: usage: %w", err)
	}
	if inUse {
		return ErrBlockInUse
	}
	if _, err := tx.Exec(ctx, `DELETE FROM public.lab_blocks WHERE id = $1`, blockID); err != nil {
		if code, _ := pgCode(err); code == pgForeignKeyViolation {
			return ErrBlockInUse
		}
		return fmt.Errorf("labauthor.Repo.DeleteTextBlock: delete: %w", err)
	}
	return tx.Commit(ctx)
}

// AffectedLab is a published lab built from a given block version.
type AffectedLab struct {
	ID    string `json:"id"`
	OrgID string `json:"org_id"`
	Title string `json:"title"`
}

// YankVersion marks a block version yanked (new builds refuse it) and returns
// the published labs that were built from it. Live labs are never touched.
// ErrBlockNotFound if the version does not exist; ErrAlreadyYanked if it was
// yanked before.
func (r *Repo) YankVersion(ctx context.Context, versionID, reason string) ([]AffectedLab, error) {
	tag, err := r.pool.Exec(ctx, `
		UPDATE public.lab_block_versions SET yanked_at = now(), yanked_reason = $2
		WHERE id = $1 AND yanked_at IS NULL`, versionID, reason)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.YankVersion: %w", err)
	}
	if tag.RowsAffected() == 0 {
		var exists bool
		if err := r.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM public.lab_block_versions WHERE id = $1)`, versionID).Scan(&exists); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.YankVersion: %w", err)
		}
		if !exists {
			return nil, ErrBlockNotFound
		}
		return nil, ErrAlreadyYanked
	}
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT ld.id, ld.org_id, ld.title
		FROM public.lab_block_usages u
		JOIN public.lab_definitions ld ON ld.build_id = u.build_id
		WHERE u.block_version_id = $1 ORDER BY ld.title`, versionID)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.YankVersion: affected: %w", err)
	}
	defer rows.Close()
	out := []AffectedLab{}
	for rows.Next() {
		var a AffectedLab
		if err := rows.Scan(&a.ID, &a.OrgID, &a.Title); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.YankVersion: scan: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// ─── recipes ────────────────────────────────────────────────────────────────

// Recipe is a lab_recipes row.
type Recipe struct {
	ID              string          `json:"id"`
	OrgID           string          `json:"org_id"`
	OwnerID         string          `json:"owner_id"`
	LabKind         string          `json:"lab_kind"`
	Title           string          `json:"title"`
	Spec            labblock.Spec   `json:"spec"`
	Revision        int             `json:"revision"`
	LabID           *string         `json:"lab_id"`
	TargetPlacement json.RawMessage `json:"target_placement"`
	CreatedAt       time.Time       `json:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at"`
}

const recipeCols = `id, org_id, owner_id, lab_kind, title, spec, revision, lab_id, target_placement, created_at, updated_at`

func scanRecipe(row pgx.Row) (*Recipe, error) {
	var rc Recipe
	var spec, placement []byte
	if err := row.Scan(&rc.ID, &rc.OrgID, &rc.OwnerID, &rc.LabKind, &rc.Title, &spec, &rc.Revision, &rc.LabID, &placement, &rc.CreatedAt, &rc.UpdatedAt); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(spec, &rc.Spec); err != nil {
		return nil, fmt.Errorf("labauthor: recipe %s spec: %w", rc.ID, err)
	}
	if rc.Spec.Blocks == nil {
		rc.Spec.Blocks = []labblock.BlockRef{}
	}
	rc.TargetPlacement = placement
	return &rc, nil
}

// CreateRecipe inserts a recipe.
func (r *Repo) CreateRecipe(ctx context.Context, orgID, ownerID, labKind, title string, spec labblock.Spec, placement json.RawMessage) (*Recipe, error) {
	raw, err := json.Marshal(spec)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.CreateRecipe: %w", err)
	}
	rc, err := scanRecipe(r.pool.QueryRow(ctx, `
		INSERT INTO public.lab_recipes (org_id, owner_id, lab_kind, title, spec, target_placement)
		VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb) RETURNING `+recipeCols,
		orgID, ownerID, labKind, title, raw, nullJSON(placement)))
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.CreateRecipe: %w", err)
	}
	return rc, nil
}

func nullJSON(b json.RawMessage) any {
	if len(b) == 0 || string(b) == "null" {
		return nil
	}
	return []byte(b)
}

// GetRecipe returns the org's recipe or ErrRecipeNotFound.
func (r *Repo) GetRecipe(ctx context.Context, orgID, id string) (*Recipe, error) {
	rc, err := scanRecipe(r.pool.QueryRow(ctx, `SELECT `+recipeCols+` FROM public.lab_recipes WHERE id = $1 AND org_id = $2`, id, orgID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrRecipeNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.GetRecipe: %w", err)
	}
	return rc, nil
}

// ListRecipes lists the org's recipes, newest first.
func (r *Repo) ListRecipes(ctx context.Context, orgID string, limit, offset int) ([]*Recipe, error) {
	rows, err := r.pool.Query(ctx, `SELECT `+recipeCols+` FROM public.lab_recipes WHERE org_id = $1 ORDER BY updated_at DESC LIMIT $2 OFFSET $3`, orgID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.ListRecipes: %w", err)
	}
	defer rows.Close()
	out := []*Recipe{}
	for rows.Next() {
		rc, err := scanRecipe(rows)
		if err != nil {
			return nil, fmt.Errorf("labauthor.Repo.ListRecipes: %w", err)
		}
		out = append(out, rc)
	}
	return out, rows.Err()
}

// UpdateRecipe replaces title/spec/placement if the stored revision equals
// expectedRevision, bumping it. ErrRecipeNotFound / ErrRevisionConflict.
func (r *Repo) UpdateRecipe(ctx context.Context, orgID, id, title string, spec labblock.Spec, placement json.RawMessage, expectedRevision int) (*Recipe, error) {
	raw, err := json.Marshal(spec)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.UpdateRecipe: %w", err)
	}
	rc, err := scanRecipe(r.pool.QueryRow(ctx, `
		UPDATE public.lab_recipes
		SET title = $3, spec = $4::jsonb, target_placement = $5::jsonb, revision = revision + 1, updated_at = now()
		WHERE id = $1 AND org_id = $2 AND revision = $6 RETURNING `+recipeCols,
		id, orgID, title, raw, nullJSON(placement), expectedRevision))
	if errors.Is(err, pgx.ErrNoRows) {
		if _, gerr := r.GetRecipe(ctx, orgID, id); gerr != nil {
			return nil, gerr
		}
		return nil, ErrRevisionConflict
	}
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.UpdateRecipe: %w", err)
	}
	return rc, nil
}

// DeleteRecipe removes the org's recipe; ErrRecipeInUse when a published lab
// still hangs off one of its builds.
func (r *Repo) DeleteRecipe(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM public.lab_recipes WHERE id = $1 AND org_id = $2`, id, orgID)
	if err != nil {
		if code, _ := pgCode(err); code == pgForeignKeyViolation {
			return ErrRecipeInUse
		}
		return fmt.Errorf("labauthor.Repo.DeleteRecipe: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrRecipeNotFound
	}
	return nil
}

// ─── AI draft cache ─────────────────────────────────────────────────────────

// GetDraft returns the cached draft response for cacheKey, or ("", false).
func (r *Repo) GetDraft(ctx context.Context, cacheKey string) (string, bool, error) {
	var resp string
	err := r.pool.QueryRow(ctx, `SELECT response FROM public.lab_ai_drafts WHERE cache_key = $1`, cacheKey).Scan(&resp)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("labauthor.Repo.GetDraft: %w", err)
	}
	return resp, true, nil
}

// PutDraft stores a draft (first writer wins) and returns the winning response.
func (r *Repo) PutDraft(ctx context.Context, cacheKey, orgID, kind, prompt, response string, tokens int) (string, error) {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO public.lab_ai_drafts (cache_key, org_id, kind, prompt, response, tokens_used)
		VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (cache_key) DO NOTHING`,
		cacheKey, orgID, kind, prompt, response, tokens); err != nil {
		return "", fmt.Errorf("labauthor.Repo.PutDraft: %w", err)
	}
	resp, ok, err := r.GetDraft(ctx, cacheKey)
	if err != nil || !ok {
		return "", fmt.Errorf("labauthor.Repo.PutDraft: re-read: %v", err)
	}
	return resp, nil
}

// PayloadRef locates a block version's payload in the private store.
type PayloadRef struct{ Key, SHA string }

// PayloadRefs returns the payload key and sha256 of each given block version
// (text-only versions are absent from the result).
func (r *Repo) PayloadRefs(ctx context.Context, versionIDs []string) (map[string]PayloadRef, error) {
	out := map[string]PayloadRef{}
	if len(versionIDs) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, payload_key, payload_sha256 FROM public.lab_block_versions
		WHERE id = ANY($1::uuid[]) AND payload_key IS NOT NULL`, versionIDs)
	if err != nil {
		return nil, fmt.Errorf("labauthor.Repo.PayloadRefs: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var ref PayloadRef
		if err := rows.Scan(&id, &ref.Key, &ref.SHA); err != nil {
			return nil, fmt.Errorf("labauthor.Repo.PayloadRefs: scan: %w", err)
		}
		out[id] = ref
	}
	return out, rows.Err()
}

package labs

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"slices"
	"strings"

	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/storage"
)

// ─── Lab-kind runtime (backend/internal/labkinds) ────────────────────────────
//
// Everything here is kind-agnostic: the core labs code asks the registry
// "is there a Kind for this lab_type?" and, if so, works only through the
// labkinds.Kind interface and the generic labkinds.VariantView.

// kindFor resolves the pluggable Kind for a lab, if its lab_type has one.
func kindFor(lab *LabDefinition) (labkinds.Kind, bool) {
	return labkinds.Get(lab.LabType)
}

// completionPolicy is the lab kind's completion policy; labs with no kind
// (every hand-authored type) complete when the last required task passes.
func (s *Service) completionPolicy(lab *LabDefinition) labkinds.CompletionPolicy {
	if kind, ok := kindFor(lab); ok {
		return kind.CompletionPolicy()
	}
	return labkinds.CompleteOnRequiredPass
}

// pickVariantKey deterministically maps (user, lab) onto one of keys —
// docs/debug-labs.md §B6: stable per student so retries, hints and the
// debrief stay consistent, different across classmates. keys must be
// non-empty and in a stable order (Repo.ListVariantKeys sorts).
func pickVariantKey(userID, labID string, keys []string) string {
	sum := sha256.Sum256([]byte(userID + "|" + labID))
	return keys[binary.BigEndian.Uint64(sum[:8])%uint64(len(keys))]
}

// choosePinnedVariant returns the variant_key StartSession pins for a kind
// lab, or ErrKindLabNotBuilt if the lab has no build/variants.
func (s *Service) choosePinnedVariant(ctx context.Context, lab *LabDefinition, userID string) (string, error) {
	if lab.BuildID == nil {
		return "", ErrKindLabNotBuilt
	}
	keys, err := s.repo.ListVariantKeys(ctx, *lab.BuildID)
	if err != nil {
		return "", fmt.Errorf("labs.Service.choosePinnedVariant: %w", err)
	}
	if len(keys) == 0 {
		return "", ErrKindLabNotBuilt
	}
	if forced, ok := ctx.Value(variantOverrideKey{}).(string); ok && forced != "" {
		if !slices.Contains(keys, forced) {
			return "", ErrKindLabNotBuilt
		}
		return forced, nil
	}
	return pickVariantKey(userID, lab.ID, keys), nil
}

type variantOverrideKey struct{}

// WithVariantOverride makes StartSession pin the given variant instead of the
// hash(user, lab) pick. Used only by the instructor preview ("Preview as
// student on variant X"); a key that is not one of the build's variants fails
// the start with ErrKindLabNotBuilt.
func WithVariantOverride(ctx context.Context, variantKey string) context.Context {
	return context.WithValue(ctx, variantOverrideKey{}, variantKey)
}

// BundleKeyPrefix is the private-store prefix every lab bundle lives under.
const BundleKeyPrefix = storage.BundleKeyPrefix

// BundleKey is the content-addressed private-store key for a bundle.
func BundleKey(sha string) string { return storage.BundleKey(sha) }

// StoreBundle uploads data to the private store under its content-addressed
// key and returns (key, sha256). Immutable and idempotent: identical bytes
// always land on the same key. Callers (the builder, later) must call this
// BEFORE committing the DB row that references the key.
func (s *Service) StoreBundle(ctx context.Context, data []byte) (key, sha string, err error) {
	if s.bundleStore == nil {
		return "", "", ErrBundleStoreUnavailable
	}
	key, sha, err = storage.PutBundle(ctx, s.bundleStore, data)
	if err != nil {
		return "", "", fmt.Errorf("labs.Service.StoreBundle: %w", err)
	}
	return key, sha, nil
}

// downloadBundle fetches key from the private store and verifies its sha256.
func (s *Service) downloadBundle(ctx context.Context, key, wantSHA string) ([]byte, error) {
	if s.bundleStore == nil {
		return nil, ErrBundleStoreUnavailable
	}
	data, err := s.bundleStore.Download(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("labs.Service.downloadBundle: %w", err)
	}
	sum := sha256.Sum256(data)
	if !strings.EqualFold(hex.EncodeToString(sum[:]), wantSHA) {
		return nil, fmt.Errorf("labs.Service.downloadBundle: %s: %w", key, ErrBundleCorrupt)
	}
	return data, nil
}

// loadVariant loads a variant row and downloads+verifies both bundles.
// withGrader=false skips the grader bundle download (seeding, payloads,
// debrief never need hidden tests in memory).
func (s *Service) loadVariant(ctx context.Context, buildID, variantKey string, withWorkspace, withGrader bool) (*labkinds.VariantView, error) {
	rec, err := s.repo.GetVariantRecord(ctx, buildID, variantKey)
	if err != nil {
		return nil, err
	}
	v := variantViewOf(rec)
	if withWorkspace {
		if v.WorkspaceBundle, err = s.downloadBundle(ctx, rec.WorkspaceKey, rec.WorkspaceSHA); err != nil {
			return nil, err
		}
	}
	if withGrader {
		if v.GraderBundle, err = s.downloadBundle(ctx, rec.GraderKey, rec.GraderSHA); err != nil {
			return nil, err
		}
	}
	return v, nil
}

// variantViewOf projects a stored variant row (no bundle bytes) to the view kinds consume.
func variantViewOf(rec *VariantRecord) *labkinds.VariantView {
	return &labkinds.VariantView{
		BuildID: rec.BuildID, VariantKey: rec.VariantKey, BriefMD: rec.BriefMD,
		ProtectedManifest: rec.ProtectedManifest, AppPorts: rec.AppPorts, IDEPort: rec.IDEPort, Payload: rec.Payload,
	}
}

// sessionVariant loads the variant a kind-lab session is pinned to.
func (s *Service) sessionVariant(ctx context.Context, lab *LabDefinition, session *LabSession, withWorkspace, withGrader bool) (*labkinds.VariantView, error) {
	buildID := sessionBuildID(ctx, s.repo, lab, session)
	if buildID == "" || session.VariantKey == nil || *session.VariantKey == "" {
		return nil, ErrKindLabNotBuilt
	}
	return s.loadVariant(ctx, buildID, *session.VariantKey, withWorkspace, withGrader)
}

// sessionBuildID is the build a session's variant belongs to: the build its
// pinned task version was published from (so republishing the lab from a newer
// build never re-points an in-flight session), falling back to the lab's
// current build for versions cut before that link existed. "" = none.
func sessionBuildID(ctx context.Context, repo *Repo, lab *LabDefinition, session *LabSession) string {
	if id, err := repo.TaskVersionBuildID(ctx, session.TaskVersionID); err == nil && id != nil {
		return *id
	}
	if lab.BuildID != nil {
		return *lab.BuildID
	}
	return ""
}

// extractBundleScript untars stdin into the workspace as labuser.
const extractBundleScript = `mkdir -p ` + labWorkdir + ` && tar -xzf - -C ` + labWorkdir

// seedKindWorkspace streams the pinned variant's pristine workspace bundle
// into /home/labuser/work via ExecStdin (never argv — docs/debug-labs.md).
func (s *Service) seedKindWorkspace(ctx context.Context, containerID string, lab *LabDefinition, session *LabSession) error {
	v, err := s.sessionVariant(ctx, lab, session, true, false)
	if err != nil {
		return fmt.Errorf("labs.Service.seedKindWorkspace: %w", err)
	}
	_, stderr, exitCode, err := s.container.ExecStdin(ctx, containerID, extractBundleScript, v.WorkspaceBundle, SetupScriptTimeoutSeconds)
	if err != nil {
		return fmt.Errorf("labs.Service.seedKindWorkspace: exec: %w", err)
	}
	if exitCode != 0 {
		return fmt.Errorf("labs.Service.seedKindWorkspace: tar exited %d: %s", exitCode, strings.TrimSpace(stderr))
	}
	return nil
}

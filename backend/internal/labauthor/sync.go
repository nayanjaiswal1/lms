package labauthor

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/storage"
)

// Block sync (repo -> DB), docs/debug-labs.md §B4. Platform code blocks live in
// content/lab-blocks/**/block.yaml. LoadBlockTree parses + validates them,
// PackDir builds a deterministic content hash and tar.gz payload, and
// RenderSyncSQL emits the idempotent SQL fixture `coursegen blocks sync`
// writes (matching coursegen generate: it emits SQL, the seed script applies
// it). Payloads are uploaded to the private store before the SQL is applied.

// ManifestFileName is the file that marks a directory as a block.
const ManifestFileName = "block.yaml"

// LoadedBlock is one block directory ready to sync.
type LoadedBlock struct {
	Dir          string
	Manifest     *labblock.Manifest
	ManifestJSON []byte
	// ContentHash is sha256 over the sorted (path, file sha256) list of the
	// whole directory with line endings normalised - the block version's
	// stored identity.
	ContentHash string
	// Payload is the deterministic tar.gz of the directory; nil for a
	// text-only block (block.yaml is the only file).
	Payload    []byte
	PayloadSHA string
	PayloadKey string
	BlockID    string
	VersionID  string
}

type packFile struct {
	path string
	data []byte
}

// normalizeContent converts CRLF to LF in text files (no NUL byte) so a
// Windows checkout hashes and packs identically to Linux CI.
func normalizeContent(b []byte) []byte {
	if bytes.IndexByte(b, 0) >= 0 {
		return b
	}
	return bytes.ReplaceAll(b, []byte("\r\n"), []byte("\n"))
}

// PackDir reads dir (recursively, in sorted path order, forward-slash
// relative paths) and returns its content hash and, when the block ships more
// than block.yaml, a deterministic tar.gz (zero mtimes, uid/gid, no names;
// mode 0644, or 0755 for files with a shebang line).
func PackDir(dir string) (contentHash string, payload []byte, err error) {
	var files []packFile
	err = filepath.WalkDir(dir, func(p string, d fs.DirEntry, werr error) error {
		if werr != nil {
			return werr
		}
		if d.IsDir() {
			if p != dir {
				if _, serr := os.Stat(filepath.Join(p, ManifestFileName)); serr == nil {
					return fmt.Errorf("%s: nested block directories are not allowed", p)
				}
			}
			return nil
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("%s: only regular files are allowed in a block", p)
		}
		raw, rerr := os.ReadFile(p)
		if rerr != nil {
			return rerr
		}
		rel, rerr := filepath.Rel(dir, p)
		if rerr != nil {
			return rerr
		}
		files = append(files, packFile{path: filepath.ToSlash(rel), data: normalizeContent(raw)})
		return nil
	})
	if err != nil {
		return "", nil, fmt.Errorf("labauthor.PackDir: %w", err)
	}
	sort.Slice(files, func(i, j int) bool { return files[i].path < files[j].path })

	h := sha256.New()
	for _, f := range files {
		sum := sha256.Sum256(f.data)
		fmt.Fprintf(h, "%s\x00%s\n", f.path, hex.EncodeToString(sum[:]))
	}
	contentHash = hex.EncodeToString(h.Sum(nil))
	if len(files) == 1 && files[0].path == ManifestFileName {
		return contentHash, nil, nil
	}

	var buf bytes.Buffer
	gz, _ := gzip.NewWriterLevel(&buf, gzip.BestCompression) // level is valid; error impossible
	tw := tar.NewWriter(gz)
	for _, f := range files {
		mode := int64(0o644)
		if bytes.HasPrefix(f.data, []byte("#!")) {
			mode = 0o755
		}
		hdr := &tar.Header{Name: f.path, Mode: mode, Size: int64(len(f.data)), Typeflag: tar.TypeReg, Format: tar.FormatPAX}
		if err := tw.WriteHeader(hdr); err != nil {
			return "", nil, fmt.Errorf("labauthor.PackDir: %w", err)
		}
		if _, err := tw.Write(f.data); err != nil {
			return "", nil, fmt.Errorf("labauthor.PackDir: %w", err)
		}
	}
	if err := tw.Close(); err != nil {
		return "", nil, fmt.Errorf("labauthor.PackDir: %w", err)
	}
	if err := gz.Close(); err != nil {
		return "", nil, fmt.Errorf("labauthor.PackDir: %w", err)
	}
	return contentHash, buf.Bytes(), nil
}

// LoadBlockTree walks root for block.yaml files, parses and validates each
// manifest, checks that a version's ids are unique across the tree, and
// returns the blocks sorted by (key, version). All problems are collected
// into one error so an author sees every mistake in one run.
func LoadBlockTree(root string) ([]*LoadedBlock, error) {
	var dirs []string
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, werr error) error {
		if werr != nil {
			return werr
		}
		if !d.IsDir() && d.Name() == ManifestFileName {
			dirs = append(dirs, filepath.Dir(p))
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("labauthor.LoadBlockTree: %w", err)
	}
	sort.Strings(dirs)

	var blocks []*LoadedBlock
	var problems []string
	seen := map[string]string{}
	for _, dir := range dirs {
		raw, err := os.ReadFile(filepath.Join(dir, ManifestFileName))
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s: %v", dir, err))
			continue
		}
		m, err := labblock.ParseManifest(normalizeContent(raw))
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s: %v", dir, err))
			continue
		}
		bad := false
		for _, is := range ValidateManifest(m) {
			if is.Severity == labblock.SeverityError {
				problems = append(problems, fmt.Sprintf("%s: [%s] %s", dir, is.Code, is.Message))
				bad = true
			}
		}
		if bad {
			continue
		}
		idv := m.ID + "@" + m.Version
		if prev, dup := seen[idv]; dup {
			problems = append(problems, fmt.Sprintf("%s: duplicates %s from %s", dir, idv, prev))
			continue
		}
		seen[idv] = dir
		mj, err := m.CanonicalJSON()
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s: %v", dir, err))
			continue
		}
		hash, payload, err := PackDir(dir)
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s: %v", dir, err))
			continue
		}
		lb := &LoadedBlock{
			Dir: dir, Manifest: m, ManifestJSON: mj, ContentHash: hash, Payload: payload,
			BlockID:   PlatformBlockID(m.ID),
			VersionID: PlatformVersionID(m.ID, m.Version),
		}
		if payload != nil {
			sum := sha256.Sum256(payload)
			lb.PayloadSHA = hex.EncodeToString(sum[:])
			lb.PayloadKey = storage.BundleKey(lb.PayloadSHA)
		}
		blocks = append(blocks, lb)
	}
	if len(problems) > 0 {
		return nil, fmt.Errorf("labauthor.LoadBlockTree: %d problem(s):\n  %s", len(problems), strings.Join(problems, "\n  "))
	}
	sort.Slice(blocks, func(i, j int) bool {
		a, b := blocks[i].Manifest, blocks[j].Manifest
		if a.ID != b.ID {
			return a.ID < b.ID
		}
		return versionLess(a.Version, b.Version)
	})
	return blocks, nil
}

func versionLess(a, b string) bool {
	va, ea := labblock.ParseVersion(a)
	vb, eb := labblock.ParseVersion(b)
	if ea != nil || eb != nil {
		return a < b
	}
	return va.Compare(vb) < 0
}

// PlatformBlockID is the deterministic lab_blocks.id of a platform block
// (UUIDv5 over the block key, same namespace as the content pipeline).
func PlatformBlockID(key string) string { return canonical.LabBlockID(key) }

// PlatformVersionID is the deterministic lab_block_versions.id of a platform
// block version.
func PlatformVersionID(key, version string) string { return canonical.LabBlockVersionID(key, version) }

// UploadPayloads stores every block payload in the private bundle store
// (content-addressed, idempotent), before the SQL that references the keys is
// applied.
func UploadPayloads(ctx context.Context, store storage.PrivateStore, blocks []*LoadedBlock) error {
	for _, b := range blocks {
		if b.Payload == nil {
			continue
		}
		key, sha, err := storage.PutBundle(ctx, store, b.Payload)
		if err != nil {
			return fmt.Errorf("labauthor.UploadPayloads: %s: %w", b.Manifest.ID, err)
		}
		if key != b.PayloadKey || sha != b.PayloadSHA {
			return fmt.Errorf("labauthor.UploadPayloads: %s: payload key mismatch", b.Manifest.ID)
		}
	}
	return nil
}

// RenderSyncSQL renders the idempotent fixture for blocks: per block an
// upsert of lab_blocks (org_id NULL) guarded against a changed kind/stack, and
// per version an immutability check (same version with a different content
// hash raises an exception: bump the version) followed by an insert that is a
// no-op when the version already exists with the same hash. Version rows are
// never updated. Runs in one transaction.
func RenderSyncSQL(blocks []*LoadedBlock) (string, error) {
	var b strings.Builder
	b.WriteString("-- Generated by `coursegen blocks sync` - DO NOT EDIT.\n")
	b.WriteString("-- Idempotent: safe to re-run. lab_block_versions rows are immutable.\n")
	b.WriteString("BEGIN;\n\n")
	for _, lb := range blocks {
		m := lb.Manifest
		tag := "$mf" + lb.ContentHash[:8] + "$"
		for _, s := range []string{string(lb.ManifestJSON), m.Changelog} {
			if strings.Contains(s, tag) {
				return "", fmt.Errorf("labauthor.RenderSyncSQL: %s contains the reserved quote tag %s", m.ID, tag)
			}
		}
		key := sqlQuote(m.ID)
		fmt.Fprintf(&b, "-- %s@%s\n", m.ID, m.Version)
		fmt.Fprintf(&b, "INSERT INTO public.lab_blocks (id, org_id, block_key, kind, stack)\nVALUES ('%s', NULL, %s, %s, %s)\nON CONFLICT (org_id, block_key) DO NOTHING;\n",
			lb.BlockID, key, sqlQuote(m.Kind), sqlQuote(m.Stack))
		fmt.Fprintf(&b, "DO %s BEGIN\n  IF EXISTS (SELECT 1 FROM public.lab_blocks WHERE id = '%s' AND (kind <> %s OR stack <> %s)) THEN\n    RAISE EXCEPTION 'lab block %% changed kind or stack; block identity is immutable', %s;\n  END IF;\n  IF EXISTS (SELECT 1 FROM public.lab_block_versions WHERE block_id = '%s' AND version = %s AND content_hash <> '%s') THEN\n    RAISE EXCEPTION 'lab block %% version %% is already published with different content; bump the version', %s, %s;\n  END IF;\nEND %s;\n",
			tag, lb.BlockID, sqlQuote(m.Kind), sqlQuote(m.Stack), key,
			lb.BlockID, sqlQuote(m.Version), lb.ContentHash, key, sqlQuote(m.Version), tag)
		payloadKey, payloadSHA := "NULL", "NULL"
		if lb.PayloadKey != "" {
			payloadKey, payloadSHA = sqlQuote(lb.PayloadKey), sqlQuote(lb.PayloadSHA)
		}
		changelog := "NULL"
		if m.Changelog != "" {
			changelog = tag + m.Changelog + tag
		}
		fmt.Fprintf(&b, "INSERT INTO public.lab_block_versions (id, block_id, version, content_hash, manifest, payload_key, payload_sha256, changelog)\nVALUES ('%s', '%s', %s, '%s', %s%s%s::jsonb, %s, %s, %s)\nON CONFLICT (block_id, version) DO NOTHING;\n\n",
			lb.VersionID, lb.BlockID, sqlQuote(m.Version), lb.ContentHash, tag, lb.ManifestJSON, tag, payloadKey, payloadSHA, changelog)
	}
	b.WriteString("COMMIT;\n")
	return b.String(), nil
}

// sqlQuote renders s as a standard single-quoted SQL string literal.
func sqlQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", "''") + "'" }

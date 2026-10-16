package main

import (
	"archive/tar"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/joho/godotenv"

	"github.com/mindforge/backend/internal/config"
	dbconn "github.com/mindforge/backend/internal/db"
	"github.com/mindforge/backend/internal/labbuild"
	"github.com/mindforge/backend/internal/storage"
)

const (
	importTimeout = 30 * time.Minute
	// maxLabsetTarBytes bounds a labset read from stdin (47 recipes x up to 8
	// variants x 3 bundles stays well under this).
	maxLabsetTarBytes = 8 << 30
)

// runBlocksImport imports a CI labset into this environment's database and
// private bundle store (labbuild.ImportLabset). "-" reads the labset as a tar
// on stdin, so a deploy can stream it into the backend pod:
//
//	tar -C labset -cf - . | kubectl exec -i deploy/backend -- /app/coursegen blocks import --expect-runtime-id ID -
//
// Credentials are the backend's own: DATABASE_URL and MINIO_* from the
// environment (and, run from backend/ on a dev box, backend/.env exactly like
// cmd/server).
func runBlocksImport(args []string, stdin io.Reader) error {
	fs := newFlagSet("blocks import")
	expect := fs.String("expect-runtime-id", "", "runtime stamp of this environment's lab image (required)")
	partial := fs.Bool("partial", false, "import only the labset's recipes (authoring a single recipe); deploys never pass this")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 || *expect == "" {
		return fmt.Errorf("%s", blocksUsage)
	}
	_ = godotenv.Load() // same as cmd/server: optional .env, never overrides the environment

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		return fmt.Errorf("blocks import: DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), importTimeout)
	defer cancel()
	pool, err := dbconn.Connect(ctx, dsn)
	if err != nil {
		return fmt.Errorf("blocks import: %w", err)
	}
	defer pool.Close()
	store, err := storage.NewPrivateMinioClient(config.LoadMinioOnly())
	if err != nil {
		return fmt.Errorf("blocks import: private store: %w", err)
	}
	if err := store.EnsureBucket(ctx); err != nil {
		return fmt.Errorf("blocks import: ensure private bucket: %w", err)
	}
	return importLabsetFrom(ctx, labbuild.NewImporter(pool, store), fs.Arg(0), stdin,
		labbuild.ImportOptions{ExpectRuntimeID: *expect, Partial: *partial})
}

// importLabsetFrom imports the labset at src (a directory, or "-" for a tar on stdin).
func importLabsetFrom(ctx context.Context, imp *labbuild.Service, src string, stdin io.Reader, opt labbuild.ImportOptions) error {
	dir := src
	if src == "-" {
		tmp, err := os.MkdirTemp("", "mf-labset-")
		if err != nil {
			return fmt.Errorf("blocks import: %w", err)
		}
		defer os.RemoveAll(tmp)
		if err := extractTar(stdin, tmp, maxLabsetTarBytes); err != nil {
			return fmt.Errorf("blocks import: %w", err)
		}
		dir = tmp
	}
	res, err := imp.ImportLabset(ctx, dir, opt)
	if err != nil {
		return fmt.Errorf("blocks import: %w", err)
	}
	for _, r := range res.Recipes {
		state := fmt.Sprintf("published v%d", r.Version)
		if r.Unchanged {
			state = fmt.Sprintf("unchanged (v%d)", r.Version)
		}
		fmt.Printf("  %s  lab %s  build %s  %s\n", r.RecipeID, r.LabID, r.BuildID, state)
	}
	fmt.Printf("coursegen blocks import: %d recipe(s), %d bundle(s) uploaded\n", len(res.Recipes), res.Uploaded)
	return nil
}

// extractTar unpacks a plain tar of regular files and directories into dir,
// rejecting links, absolute or escaping paths, and archives over maxBytes.
func extractTar(r io.Reader, dir string, maxBytes int64) error {
	tr := tar.NewReader(r)
	var total int64
	for {
		hdr, err := tr.Next()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("extractTar: %w", err)
		}
		name := path.Clean(strings.TrimPrefix(hdr.Name, "./"))
		if name == "." {
			continue
		}
		if path.IsAbs(name) || name == ".." || strings.HasPrefix(name, "../") {
			return fmt.Errorf("extractTar: unsafe path %q", hdr.Name)
		}
		dst := filepath.Join(dir, filepath.FromSlash(name))
		switch hdr.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(dst, 0o700); err != nil {
				return fmt.Errorf("extractTar: %w", err)
			}
		case tar.TypeReg:
			if total += hdr.Size; total > maxBytes {
				return fmt.Errorf("extractTar: archive exceeds %d bytes", maxBytes)
			}
			if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
				return fmt.Errorf("extractTar: %w", err)
			}
			f, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
			if err != nil {
				return fmt.Errorf("extractTar: %w", err)
			}
			_, cerr := io.Copy(f, io.LimitReader(tr, hdr.Size))
			if err := errors.Join(cerr, f.Close()); err != nil {
				return fmt.Errorf("extractTar: %s: %w", name, err)
			}
		default:
			return fmt.Errorf("extractTar: %q is not a regular file or directory", hdr.Name)
		}
	}
}

// runBlocksPublishLabset uploads a CI-verified labset to the private bucket
// (labsets/<runtime_id>.tar.gz) so any environment can import it with
// POST /api/admin/lab-authoring/labset/import. Credentials: MINIO_* from the
// environment, exactly like `blocks sync`. "-" reads the labset as a tar on
// stdin, like `blocks import`, so a deploy can publish from inside the backend pod.
func runBlocksPublishLabset(args []string, stdin io.Reader) error {
	fs := newFlagSet("blocks publish-labset")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("%s", blocksUsage)
	}
	_ = godotenv.Load()
	ctx, cancel := context.WithTimeout(context.Background(), importTimeout)
	defer cancel()
	store, err := storage.NewPrivateMinioClient(config.LoadMinioOnly())
	if err != nil {
		return fmt.Errorf("blocks publish-labset: private store: %w", err)
	}
	if err := store.EnsureBucket(ctx); err != nil {
		return fmt.Errorf("blocks publish-labset: ensure private bucket: %w", err)
	}
	dir := fs.Arg(0)
	if dir == "-" {
		tmp, err := os.MkdirTemp("", "mf-labset-")
		if err != nil {
			return fmt.Errorf("blocks publish-labset: %w", err)
		}
		defer os.RemoveAll(tmp)
		if err := extractTar(stdin, tmp, maxLabsetTarBytes); err != nil {
			return fmt.Errorf("blocks publish-labset: %w", err)
		}
		dir = tmp
	}
	key, m, err := labbuild.PublishLabset(ctx, store, dir)
	if err != nil {
		return fmt.Errorf("blocks publish-labset: %w", err)
	}
	fmt.Printf("coursegen blocks publish-labset: %d recipe(s) -> %s (git %s, ci build %s)\n", len(m.Recipes), key, m.GitSHA, m.CIBuild)
	return nil
}

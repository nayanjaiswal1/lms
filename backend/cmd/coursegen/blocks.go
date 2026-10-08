package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/storage"
)

// Defaults assume invocation from backend/, like the other subcommands.
const (
	defaultBlocksDir = "../content/lab-blocks"
	defaultBlocksSQL = "db/fixtures/lab-blocks.generated.sql"
	uploadTimeout    = 5 * time.Minute
)

const blocksUsage = "usage: coursegen blocks sync [--in DIR] [--out FILE] [--dry-run] [--no-upload]\n" +
	"       coursegen blocks verify [--in DIR] [--parallel N] [--report FILE] RECIPE.yaml..."

// runBlocks dispatches `coursegen blocks <action>`.
func runBlocks(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("%s", blocksUsage)
	}
	switch args[0] {
	case "sync":
		return runBlocksSync(args[1:])
	case "verify":
		return runBlocksVerify(args[1:])
	}
	return fmt.Errorf("%s", blocksUsage)
}

// runBlocksSync validates every content/lab-blocks/**/block.yaml, uploads the
// block payloads to the private bundle store, and writes the idempotent SQL
// fixture (apply it with scripts/db-seed-courses.sh, which runs every
// db/fixtures/*.generated.sql). Same model as `generate`: SQL out, no direct
// DB writes.
func runBlocksSync(args []string) error {
	fs := newFlagSet("blocks sync")
	in := fs.String("in", defaultBlocksDir, "block tree to sync")
	out := fs.String("out", defaultBlocksSQL, "path to write the generated SQL fixture")
	dry := fs.Bool("dry-run", false, "validate and report only: no upload, no file written")
	noUpload := fs.Bool("no-upload", false, "write the SQL but skip the private-store upload (upload payloads separately before applying)")
	if err := fs.Parse(args); err != nil {
		return err
	}

	blocks, err := labauthor.LoadBlockTree(*in)
	if err != nil {
		return fmt.Errorf("blocks sync: load block tree: %w", err)
	}
	payloads := 0
	for _, b := range blocks {
		if b.Payload != nil {
			payloads++
		}
		fmt.Printf("  %s@%s  %.12s  %s\n", b.Manifest.ID, b.Manifest.Version, b.ContentHash, payloadNote(b))
	}
	fmt.Printf("coursegen blocks sync: %d block version(s), %d payload(s)\n", len(blocks), payloads)
	if *dry {
		return nil
	}

	if !*noUpload && payloads > 0 {
		store, err := storage.NewPrivateMinioClient(config.LoadMinioOnly())
		if err != nil {
			return fmt.Errorf("blocks sync: private store: %w", err)
		}
		ctx, cancel := context.WithTimeout(context.Background(), uploadTimeout)
		defer cancel()
		if err := store.EnsureBucket(ctx); err != nil {
			return fmt.Errorf("blocks sync: ensure private bucket: %w", err)
		}
		if err := labauthor.UploadPayloads(ctx, store, blocks); err != nil {
			return fmt.Errorf("blocks sync: upload payloads: %w", err)
		}
	}

	sql, err := labauthor.RenderSyncSQL(blocks)
	if err != nil {
		return fmt.Errorf("blocks sync: render sql: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(*out), 0o755); err != nil {
		return fmt.Errorf("blocks sync: %w", err)
	}
	if err := os.WriteFile(*out, []byte(sql), 0o644); err != nil {
		return fmt.Errorf("blocks sync: %w", err)
	}
	fmt.Printf("coursegen blocks sync: wrote %s\n", *out)
	return nil
}

func payloadNote(b *labauthor.LoadedBlock) string {
	if b.Payload == nil {
		return "manifest only"
	}
	return fmt.Sprintf("payload %d bytes", len(b.Payload))
}

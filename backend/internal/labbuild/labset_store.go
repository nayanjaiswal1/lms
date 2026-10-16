package labbuild

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/mindforge/backend/internal/storage"
)

// LabsetKeyPrefix is the private-store prefix CI publishes verified labsets
// under, one object per lab runtime: labsets/<runtime_id>.tar.gz. Each
// environment imports the object for ITS lab image's runtime, so dev, staging
// and prod share one bucket-per-env layout with no kubectl access from CI.
const LabsetKeyPrefix = "labsets/"

// platformLabKind is the lab kind platform recipes are built for; its image
// carries the runtime stamp a labset must match.
const platformLabKind = "debug"

// ErrLabsetNotPublished means CI has not published a labset for this runtime.
var ErrLabsetNotPublished = errors.New("labbuild: no labset has been published for this lab runtime")

// LabsetKey is the private-store key of the labset verified against runtimeID.
func LabsetKey(runtimeID string) string { return LabsetKeyPrefix + runtimeID + ".tar.gz" }

// PublishLabset validates the labset at dir and uploads it, replacing the
// previous labset for the same runtime. The labset is secret (graders, fix and
// cheat overlays): the store is the private bucket, never a public one.
func PublishLabset(ctx context.Context, store storage.PrivateStore, dir string) (key string, m *Labset, err error) {
	m, err = ReadLabset(dir)
	if err != nil {
		return "", nil, fmt.Errorf("labbuild.PublishLabset: %w", err)
	}
	var entries []tarEntry
	err = filepath.WalkDir(dir, func(p string, d fs.DirEntry, werr error) error {
		if werr != nil || d.IsDir() {
			return werr
		}
		rel, rerr := filepath.Rel(dir, p)
		if rerr != nil {
			return rerr
		}
		data, rerr := os.ReadFile(p)
		if rerr != nil {
			return rerr
		}
		entries = append(entries, tarEntry{Name: filepath.ToSlash(rel), Data: data, Mode: 0o600})
		return nil
	})
	if err != nil {
		return "", nil, fmt.Errorf("labbuild.PublishLabset: read %s: %w", dir, err)
	}
	tgz, err := packTarGz(entries)
	if err != nil {
		return "", nil, fmt.Errorf("labbuild.PublishLabset: %w", err)
	}
	key = LabsetKey(m.RuntimeID)
	if err := store.Upload(ctx, key, "application/gzip", bytes.NewReader(tgz), int64(len(tgz))); err != nil {
		return "", nil, fmt.Errorf("labbuild.PublishLabset: upload: %w", err)
	}
	return key, m, nil
}

// ImportPublishedLabset imports the labset CI published for THIS environment's
// lab runtime (probed from the lab image, the same stamp builds use). Whole-set
// imports only: ImportLabset still refuses a labset that does not cover every
// platform recipe or was verified against another runtime.
func (s *Service) ImportPublishedLabset(ctx context.Context) (*ImportResult, string, error) {
	runtimeID, err := s.runtimeID(ctx, platformLabKind)
	if err != nil {
		return nil, "", fmt.Errorf("labbuild.ImportPublishedLabset: %w", err)
	}
	data, err := s.store.Download(ctx, LabsetKey(runtimeID))
	if err != nil {
		return nil, runtimeID, fmt.Errorf("%w (%s): %v", ErrLabsetNotPublished, runtimeID, err)
	}
	files, err := readTar(data)
	if err != nil {
		return nil, runtimeID, fmt.Errorf("%w: %v", ErrLabsetCorrupt, err)
	}
	tmp, err := os.MkdirTemp("", "mf-labset-")
	if err != nil {
		return nil, runtimeID, fmt.Errorf("labbuild.ImportPublishedLabset: %w", err)
	}
	defer os.RemoveAll(tmp)
	for name, content := range files {
		dst := filepath.Join(tmp, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
			return nil, runtimeID, fmt.Errorf("labbuild.ImportPublishedLabset: %w", err)
		}
		if err := os.WriteFile(dst, content, 0o600); err != nil {
			return nil, runtimeID, fmt.Errorf("labbuild.ImportPublishedLabset: %w", err)
		}
	}
	res, err := s.ImportLabset(ctx, tmp, ImportOptions{ExpectRuntimeID: runtimeID})
	return res, runtimeID, err
}

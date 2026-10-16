package labbuild

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestPublishLabsetRoundTrip(t *testing.T) {
	dir := t.TempDir()
	if err := WriteLabsetBundle(dir, []byte("bundle")); err != nil {
		t.Fatal(err)
	}
	if err := WriteLabsetManifest(dir, &Labset{RuntimeID: "rt1", GitSHA: "abc"}); err != nil {
		t.Fatal(err)
	}
	store := newMemStore()
	key, _, err := PublishLabset(context.Background(), store, dir)
	if err != nil {
		t.Fatal(err)
	}
	if key != LabsetKey("rt1") {
		t.Fatalf("key = %q", key)
	}
	data, err := store.Download(context.Background(), key)
	if err != nil {
		t.Fatal(err)
	}
	files, err := readTar(data)
	if err != nil {
		t.Fatal(err)
	}
	out := t.TempDir()
	for name, content := range files {
		dst := filepath.Join(out, filepath.FromSlash(name))
		if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(dst, content, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	m, err := ReadLabset(out)
	if err != nil {
		t.Fatalf("unpacked labset fails its own integrity check: %v", err)
	}
	if m.RuntimeID != "rt1" {
		t.Fatalf("runtime = %q", m.RuntimeID)
	}
}

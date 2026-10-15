package labbuild

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"sync"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/storage"
)

// memStore is an in-memory storage.PrivateStore.
type memStore struct {
	mu   sync.Mutex
	objs map[string][]byte
}

func newMemStore() *memStore { return &memStore{objs: map[string][]byte{}} }

func (m *memStore) Upload(_ context.Context, key, _ string, r io.Reader, _ int64) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.objs[key] = data
	return nil
}

func (m *memStore) Download(_ context.Context, key string) ([]byte, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, ok := m.objs[key]
	if !ok {
		return nil, errors.New("memStore: no such key")
	}
	return data, nil
}

func (m *memStore) Delete(_ context.Context, key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.objs, key)
	return nil
}

func (m *memStore) List(_ context.Context, prefix string) ([]storage.PrivateObject, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []storage.PrivateObject
	for k := range m.objs {
		if strings.HasPrefix(k, prefix) {
			out = append(out, storage.PrivateObject{Key: k})
		}
	}
	return out, nil
}

// testRendered is a renderer output with a captured-trace placeholder, a cheat
// diff and no app ports.
func testRendered(t *testing.T, key string) renderedVariant {
	t.Helper()
	brief := "Orders total is wrong.\n\n{{captured.trace}}\n"
	ws, err := packTarGz([]tarEntry{{Name: "TICKET.md", Data: []byte(brief)}, {Name: "app/models.py", Data: []byte("x = 1\n")}})
	require.NoError(t, err)
	gr, err := packTarGz([]tarEntry{{Name: "grade.py", Data: []byte("print('ok')\n")}})
	require.NoError(t, err)
	vf, err := packTarGz([]tarEntry{{Name: "overlays/fix-1.tgz", Data: []byte("fix")}})
	require.NoError(t, err)
	m := map[string]any{
		"protected_manifest": map[string]any{"paths": []string{"tests/"}},
		"brief_md":           brief,
		"captures":           []string{"trace"},
		"cheats":             []map[string]any{{"issue": 0, "name": "skip", "overlay": "cheat-0-0", "diff": "--- a\n+++ b\n"}},
		"payload":            map[string]any{"root_cause_md": "rounding", "fix_diff": "--- fix\n"},
	}
	raw, err := json.Marshal(m)
	require.NoError(t, err)
	return renderedVariant{Key: key, Files: map[string][]byte{"workspace.tar.gz": ws, "grader.tar.gz": gr, "verify.tar.gz": vf, "meta.json": raw}}
}

// The build job and the offline/labset path must produce the same row: both
// go through variantRowFrom; storeVariant only adds the uploads.
func TestVariantRowFrom_MatchesJobPath(t *testing.T) {
	a := testRendered(t, "v0")
	store := newMemStore()
	s := &Service{store: store}
	row, err := s.storeVariant(context.Background(), &Build{ID: "b1"}, a)
	require.NoError(t, err)
	art, err := variantRowFrom("b1", a)
	require.NoError(t, err)
	require.Equal(t, art.Row, *row)

	require.Equal(t, []int{}, row.AppPorts)
	require.Equal(t, storage.BundleKey(row.WorkspaceSHA), row.WorkspaceKey)
	require.Equal(t, storage.BundleKey(row.GraderSHA), row.GraderKey)
	var p map[string]any
	require.NoError(t, json.Unmarshal(row.Payload, &p))
	vfSHA := sha256Hex(a.Files["verify.tar.gz"])
	require.Equal(t, vfSHA, p["verify_bundle_sha256"])
	require.Equal(t, storage.BundleKey(vfSHA), p["verify_bundle_key"])
	require.Equal(t, map[string]any{"cheat-0-0": "--- a\n+++ b\n"}, p["cheat_diffs"])
	require.Equal(t, []any{"trace"}, p["captures"])
	require.Equal(t, "rounding", p["root_cause_md"])
	for _, k := range []string{row.WorkspaceKey, row.GraderKey, storage.BundleKey(vfSHA)} {
		_, err := store.Download(context.Background(), k)
		require.NoError(t, err, "bundle %s uploaded", k)
	}
}

func TestFinalizeBrief_FillsTicketAndRow(t *testing.T) {
	a := testRendered(t, "v0")
	art, err := variantRowFrom("", a)
	require.NoError(t, err)
	box := newCaptureBox([]string{"trace"})
	box.got["trace"] = "Traceback (most recent call last):\nValueError: boom"

	brief, ws, err := finalizeBrief(art.Row.BriefMD, art.Workspace, box)
	require.NoError(t, err)
	require.Contains(t, brief, "ValueError: boom")
	require.NotContains(t, brief, "{{captured")
	files, err := readTar(ws)
	require.NoError(t, err)
	require.Equal(t, brief, string(files["TICKET.md"]))
	require.Equal(t, "x = 1\n", string(files["app/models.py"]))

	before := art.Row.WorkspaceSHA
	art.setBrief(brief, ws)
	require.Equal(t, brief, art.Row.BriefMD)
	require.Equal(t, sha256Hex(ws), art.Row.WorkspaceSHA)
	require.NotEqual(t, before, art.Row.WorkspaceSHA)
	require.Equal(t, storage.BundleKey(art.Row.WorkspaceSHA), art.Row.WorkspaceKey)
	require.True(t, bytes.Equal(ws, art.Workspace))

	_, _, err = finalizeBrief(art.Row.BriefMD+"{{captured.log}}", art.Workspace, box)
	var ce *contentError
	require.ErrorAs(t, err, &ce)
	require.Contains(t, ce.msg, "log")
}

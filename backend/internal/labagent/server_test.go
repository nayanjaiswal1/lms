package labagent

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/labs"
)

// fakeRT embeds the interface so only the calls under test are implemented.
type fakeRT struct {
	labs.ContainerRuntime
	started []string
	listed  []labs.ContainerInfo
	killed  []string
}

func (f *fakeRT) Start(_ context.Context, id string, _ int, image string) (string, string, error) {
	f.started = append(f.started, image)
	return "abcdef123456abcdef", "abcdef123456:7681", nil
}

func (f *fakeRT) List(context.Context, string) ([]labs.ContainerInfo, error) { return f.listed, nil }

func (f *fakeRT) Kill(_ context.Context, id string) error {
	f.killed = append(f.killed, id)
	return nil
}

func do(h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestStart_ImageAllowlist(t *testing.T) {
	f := &fakeRT{}
	h := New(f, []string{"mindforge/lab-node-web:1"}).Handler()

	ok := do(h, "POST", labs.AgentPathContainers, `{"kind":"lab","id":"sess-1","reset_count":0,"image":"mindforge/lab-node-web:1"}`)
	assert.Equal(t, http.StatusOK, ok.Code)

	bad := do(h, "POST", labs.AgentPathContainers, `{"kind":"lab","id":"sess-1","reset_count":0,"image":"alpine"}`)
	assert.Equal(t, http.StatusBadRequest, bad.Code)
	assert.Equal(t, []string{"mindforge/lab-node-web:1"}, f.started, "disallowed image must never reach the runtime")
}

func TestStart_FlagsNotOverridable(t *testing.T) {
	f := &fakeRT{}
	h := New(f, []string{"img"}).Handler()
	for _, extra := range []string{`"privileged":true`, `"volumes":["/:/host"]`, `"network":"host"`, `"cap_add":["SYS_ADMIN"]`, `"args":["--privileged"]`} {
		rec := do(h, "POST", labs.AgentPathContainers, `{"kind":"lab","id":"s","reset_count":0,"image":"img",`+extra+`}`)
		assert.Equal(t, http.StatusBadRequest, rec.Code, extra)
	}
	assert.Empty(t, f.started)
}

func TestStart_RejectsBadIDAndKind(t *testing.T) {
	s := New(&fakeRT{}, []string{"img"})
	require.Error(t, s.ValidateStart(labs.AgentStartRequest{Kind: "lab", ID: "a b; rm", Image: "img"}))
	require.Error(t, s.ValidateStart(labs.AgentStartRequest{Kind: "lab", ID: "../x", Image: "img"}))
	require.Error(t, s.ValidateStart(labs.AgentStartRequest{Kind: "host", ID: "x", Image: "img"}))
	require.Error(t, s.ValidateStart(labs.AgentStartRequest{Kind: "lab", ID: "x", ResetCount: -1, Image: "img"}))
	require.NoError(t, s.ValidateStart(labs.AgentStartRequest{Kind: "warm", ID: "x-1", Image: "img"}))
}

func TestExecBounds(t *testing.T) {
	require.Error(t, ValidateExec(labs.AgentExecRequest{Mode: "root", TimeoutSec: 5}))
	require.Error(t, ValidateExec(labs.AgentExecRequest{Mode: labs.AgentExecUser, TimeoutSec: 0}))
	require.Error(t, ValidateExec(labs.AgentExecRequest{Mode: labs.AgentExecUser, TimeoutSec: labs.AgentMaxExecTimeoutSec + 1}))
	require.NoError(t, ValidateExec(labs.AgentExecRequest{Mode: labs.AgentExecSetup, TimeoutSec: 120}))
	require.Error(t, ValidateCapture(labs.AgentExecCaptureRequest{MaxBytes: labs.AgentMaxCaptureBytes + 1}))
}

func TestKill_OnlyLabContainers(t *testing.T) {
	f := &fakeRT{listed: []labs.ContainerInfo{{ID: "abcdef123456", Name: "mindforge-lab-s-0"}}}
	h := New(f, []string{"img"}).Handler()

	assert.Equal(t, http.StatusNoContent, do(h, "DELETE", labs.AgentPathContainers+"/abcdef123456", "").Code)
	other := do(h, "DELETE", labs.AgentPathContainers+"/111111111111", "")
	assert.Equal(t, http.StatusNotFound, other.Code)
	assert.Equal(t, http.StatusBadRequest, do(h, "DELETE", labs.AgentPathContainers+"/mindforge_postgres_prod", "").Code)
	assert.Equal(t, []string{"abcdef123456"}, f.killed)
}

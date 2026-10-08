package labs

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"
)

// AgentClient implements ContainerRuntime by calling the lab agent on the lab
// host over mTLS, so the app host never holds a Docker socket.
type AgentClient struct {
	base     string
	http     *http.Client
	profiles map[string]ImageProfile
}

// AgentClientConfig holds the agent URL and mTLS material paths.
type AgentClientConfig struct {
	URL, CAFile, CertFile, KeyFile string
}

// agentRequestSlack is HTTP headroom beyond an exec's own timeout.
const agentRequestSlack = 30 * time.Second

// NewAgentClient builds a client trusting only CAFile for the server and
// presenting CertFile/KeyFile as its identity.
func NewAgentClient(cfg AgentClientConfig, profiles map[string]ImageProfile) (*AgentClient, error) {
	if cfg.URL == "" || cfg.CAFile == "" || cfg.CertFile == "" || cfg.KeyFile == "" {
		return nil, errors.New("labs.NewAgentClient: LABS_AGENT_URL, LABS_AGENT_CA_FILE, LABS_AGENT_CERT_FILE and LABS_AGENT_KEY_FILE are all required")
	}
	caPEM, err := os.ReadFile(cfg.CAFile)
	if err != nil {
		return nil, fmt.Errorf("labs.NewAgentClient: read CA: %w", err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(caPEM) {
		return nil, errors.New("labs.NewAgentClient: CA file has no certificates")
	}
	cert, err := tls.LoadX509KeyPair(cfg.CertFile, cfg.KeyFile)
	if err != nil {
		return nil, fmt.Errorf("labs.NewAgentClient: load client cert: %w", err)
	}
	if profiles == nil {
		profiles = map[string]ImageProfile{}
	}
	return &AgentClient{
		base:     cfg.URL,
		profiles: profiles,
		http: &http.Client{Transport: &http.Transport{
			TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS13, RootCAs: pool, Certificates: []tls.Certificate{cert}},
		}},
	}, nil
}

func (a *AgentClient) do(ctx context.Context, method, path string, in, out any) error {
	var body io.Reader
	if in != nil {
		b, err := json.Marshal(in)
		if err != nil {
			return fmt.Errorf("labs.AgentClient: encode: %w", err)
		}
		body = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, a.base+path, body)
	if err != nil {
		return fmt.Errorf("labs.AgentClient: request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := a.http.Do(req)
	if err != nil {
		return fmt.Errorf("labs.AgentClient: %s %s: %w", method, path, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		var e AgentErrorResponse
		_ = json.NewDecoder(io.LimitReader(resp.Body, 64*1024)).Decode(&e)
		return fmt.Errorf("labs.AgentClient: %s %s: status %d: %s", method, path, resp.StatusCode, e.Error)
	}
	if out == nil {
		return nil
	}
	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return fmt.Errorf("labs.AgentClient: decode: %w", err)
	}
	return nil
}

func agentContainerPath(id, suffix string) string {
	return AgentPathContainers + "/" + url.PathEscape(id) + suffix
}

func (a *AgentClient) start(ctx context.Context, kind, id string, reset int, image string) (string, string, error) {
	var r AgentStartResponse
	err := a.do(ctx, http.MethodPost, AgentPathContainers, AgentStartRequest{Kind: kind, ID: id, ResetCount: reset, Image: image}, &r)
	return r.ContainerID, r.ContainerHost, err
}

func (a *AgentClient) Start(ctx context.Context, sessionID string, resetCount int, image string) (string, string, error) {
	return a.start(ctx, AgentKindLab, sessionID, resetCount, image)
}

func (a *AgentClient) StartWarm(ctx context.Context, warmID, image string) (string, string, error) {
	return a.start(ctx, AgentKindWarm, warmID, 0, image)
}

func (a *AgentClient) StartValidation(ctx context.Context, id, image string) (string, string, error) {
	return a.start(ctx, AgentKindValidation, id, 0, image)
}

func (a *AgentClient) Kill(ctx context.Context, containerID string) error {
	return a.do(ctx, http.MethodDelete, agentContainerPath(containerID, ""), nil, nil)
}

func (a *AgentClient) exec(ctx context.Context, mode, containerID, script string, stdin []byte, timeoutSec int) (string, string, int, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSec)*time.Second+agentRequestSlack)
	defer cancel()
	var r AgentExecResponse
	err := a.do(ctx, http.MethodPost, agentContainerPath(containerID, AgentSuffixExec),
		AgentExecRequest{Mode: mode, Script: script, Stdin: stdin, TimeoutSec: timeoutSec}, &r)
	if err != nil {
		return "", "", -1, err
	}
	return string(r.Stdout), string(r.Stderr), r.ExitCode, nil
}

func (a *AgentClient) Exec(ctx context.Context, containerID, script string, timeoutSec int) (string, string, int, error) {
	return a.exec(ctx, AgentExecUser, containerID, script, nil, timeoutSec)
}

func (a *AgentClient) ExecStdin(ctx context.Context, containerID, script string, stdin []byte, timeoutSec int) (string, string, int, error) {
	if stdin == nil {
		stdin = []byte{}
	}
	return a.exec(ctx, AgentExecUser, containerID, script, stdin, timeoutSec)
}

func (a *AgentClient) ExecSetup(ctx context.Context, containerID, script string, timeoutSec int) (string, string, int, error) {
	return a.exec(ctx, AgentExecSetup, containerID, script, nil, timeoutSec)
}

func (a *AgentClient) ExecCapture(ctx context.Context, containerID, script string, maxBytes int) (string, string, int, error) {
	var r AgentExecResponse
	err := a.do(ctx, http.MethodPost, agentContainerPath(containerID, AgentSuffixExecCapture),
		AgentExecCaptureRequest{Script: script, MaxBytes: maxBytes}, &r)
	if err != nil {
		return "", "", -1, err
	}
	return string(r.Stdout), string(r.Stderr), r.ExitCode, nil
}

func (a *AgentClient) IsRunning(ctx context.Context, containerID string) bool {
	var r AgentRunningResponse
	if err := a.do(ctx, http.MethodGet, agentContainerPath(containerID, AgentSuffixRunning), nil, &r); err != nil {
		return false
	}
	return r.Running
}

func (a *AgentClient) Pause(ctx context.Context, containerID string) error {
	return a.do(ctx, http.MethodPost, agentContainerPath(containerID, AgentSuffixPause), nil, nil)
}

func (a *AgentClient) Unpause(ctx context.Context, containerID string) error {
	return a.do(ctx, http.MethodPost, agentContainerPath(containerID, AgentSuffixUnpause), nil, nil)
}

func (a *AgentClient) List(ctx context.Context, namePrefix string) ([]ContainerInfo, error) {
	var raw []AgentContainerInfo
	if err := a.do(ctx, http.MethodGet, AgentPathContainers+"?prefix="+url.QueryEscape(namePrefix), nil, &raw); err != nil {
		return nil, err
	}
	out := make([]ContainerInfo, 0, len(raw))
	for _, c := range raw {
		t, err := time.Parse(time.RFC3339Nano, c.CreatedAt)
		if err != nil {
			t = time.Now() // same fail-toward-"just created" rule as DockerContainerService.List
		}
		out = append(out, ContainerInfo{ID: c.ID, Name: c.Name, CreatedAt: t})
	}
	return out, nil
}

// Classify resolves locally: profiles are config both sides share, and the
// agent re-resolves them itself when it builds the container.
func (a *AgentClient) Classify(image string) ImageProfile { return a.profiles[image] }

var _ ContainerRuntime = (*AgentClient)(nil)

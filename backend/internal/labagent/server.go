// Package labagent is the HTTP front of the lab host's Docker access. It runs
// next to the Docker socket and exposes only typed lab operations: the API
// server can ask for "start allowed image X" or "exec in lab container Y", but
// never supplies a Docker flag, image outside the allowlist, or a container
// that is not a lab sandbox.
package labagent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/mindforge/backend/internal/labs"
)

var (
	idPattern          = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`)
	containerIDPattern = regexp.MustCompile(`^[a-f0-9]{12,64}$`)
	// ownedPrefixes are the only container names the agent will touch.
	ownedPrefixes = []string{"mindforge-lab-", labs.WarmContainerNamePrefix, labs.ValidationContainerNamePrefix}
)

// Server serves the agent API on top of a ContainerRuntime (the real
// DockerContainerService in production).
type Server struct {
	rt      labs.ContainerRuntime
	allowed map[string]struct{}
	// verified caches container IDs already confirmed to be lab sandboxes.
	verified sync.Map
}

// New returns a Server accepting only images in allowedImages.
func New(rt labs.ContainerRuntime, allowedImages []string) *Server {
	allowed := make(map[string]struct{}, len(allowedImages))
	for _, img := range allowedImages {
		allowed[img] = struct{}{}
	}
	return &Server{rt: rt, allowed: allowed}
}

// Handler returns the routed API.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	p := labs.AgentPathContainers
	mux.HandleFunc("POST "+p, s.handleStart)
	mux.HandleFunc("GET "+p, s.handleList)
	mux.HandleFunc("DELETE "+p+"/{id}", s.owned(s.handleKill))
	mux.HandleFunc("POST "+p+"/{id}"+labs.AgentSuffixExec, s.owned(s.handleExec))
	mux.HandleFunc("POST "+p+"/{id}"+labs.AgentSuffixExecCapture, s.owned(s.handleExecCapture))
	mux.HandleFunc("GET "+p+"/{id}"+labs.AgentSuffixRunning, s.owned(s.handleRunning))
	mux.HandleFunc("POST "+p+"/{id}"+labs.AgentSuffixPause, s.owned(s.handlePause))
	mux.HandleFunc("POST "+p+"/{id}"+labs.AgentSuffixUnpause, s.owned(s.handleUnpause))
	return mux
}

type validationError string

func (e validationError) Error() string { return string(e) }

// ValidateStart checks a start request and returns nothing but an error: the
// agent never echoes request fields into Docker flags, only into the name.
func (s *Server) ValidateStart(r labs.AgentStartRequest) error {
	switch r.Kind {
	case labs.AgentKindLab, labs.AgentKindWarm, labs.AgentKindValidation:
	default:
		return validationError("unknown kind")
	}
	if !idPattern.MatchString(r.ID) {
		return validationError("invalid id")
	}
	if r.ResetCount < 0 || r.ResetCount > 1_000_000 {
		return validationError("invalid reset_count")
	}
	if _, ok := s.allowed[r.Image]; !ok {
		return validationError("image not allowed")
	}
	return nil
}

// ValidateExec checks exec bounds.
func ValidateExec(r labs.AgentExecRequest) error {
	if r.Mode != labs.AgentExecUser && r.Mode != labs.AgentExecSetup {
		return validationError("unknown mode")
	}
	if r.TimeoutSec < 1 || r.TimeoutSec > labs.AgentMaxExecTimeoutSec {
		return validationError("invalid timeout_sec")
	}
	return nil
}

// ValidateCapture checks capture bounds.
func ValidateCapture(r labs.AgentExecCaptureRequest) error {
	if r.MaxBytes < 1 || r.MaxBytes > labs.AgentMaxCaptureBytes {
		return validationError("invalid max_bytes")
	}
	return nil
}

func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, labs.AgentMaxRequestBytes))
	dec.DisallowUnknownFields() // an unexpected field (e.g. "privileged") is a 400, never ignored
	if err := dec.Decode(v); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid body")
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("labagent: write response", "error", err)
	}
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, labs.AgentErrorResponse{Error: msg})
}

func writeRuntimeErr(w http.ResponseWriter, op string, err error) {
	slog.Error("labagent: runtime call failed", "op", op, "error", err)
	writeErr(w, http.StatusBadGateway, op+" failed")
}

func (s *Server) handleStart(w http.ResponseWriter, r *http.Request) {
	var req labs.AgentStartRequest
	if !decode(w, r, &req) {
		return
	}
	if err := s.ValidateStart(req); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var id, host string
	var err error
	switch req.Kind {
	case labs.AgentKindLab:
		id, host, err = s.rt.Start(r.Context(), req.ID, req.ResetCount, req.Image)
	case labs.AgentKindWarm:
		id, host, err = s.rt.StartWarm(r.Context(), req.ID, req.Image)
	default:
		id, host, err = s.rt.StartValidation(r.Context(), req.ID, req.Image)
	}
	if err != nil {
		writeRuntimeErr(w, "start", err)
		return
	}
	s.verified.Store(id, struct{}{})
	writeJSON(w, http.StatusOK, labs.AgentStartResponse{ContainerID: id, ContainerHost: host})
}

func (s *Server) handleList(w http.ResponseWriter, r *http.Request) {
	prefix := r.URL.Query().Get("prefix")
	if !ownedPrefix(prefix) {
		writeErr(w, http.StatusBadRequest, "invalid prefix")
		return
	}
	infos, err := s.rt.List(r.Context(), prefix)
	if err != nil {
		writeRuntimeErr(w, "list", err)
		return
	}
	out := make([]labs.AgentContainerInfo, 0, len(infos))
	for _, c := range infos {
		out = append(out, labs.AgentContainerInfo{ID: c.ID, Name: c.Name, CreatedAt: c.CreatedAt.Format(time.RFC3339Nano)})
	}
	writeJSON(w, http.StatusOK, out)
}

// ownedPrefix reports whether prefix is one of (or extends) the lab name prefixes.
func ownedPrefix(prefix string) bool {
	for _, p := range ownedPrefixes {
		if strings.HasPrefix(prefix, p) {
			return true
		}
	}
	return false
}

// owned wraps a per-container handler with the "is this a lab sandbox" check,
// so the API server cannot exec into or kill the agent's own or any other
// container on the lab host.
func (s *Server) owned(next func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := r.PathValue("id")
		if !containerIDPattern.MatchString(id) {
			writeErr(w, http.StatusBadRequest, "invalid container id")
			return
		}
		if _, ok := s.verified.Load(id); !ok {
			if !s.isLabContainer(r.Context(), id) {
				writeErr(w, http.StatusNotFound, "no such lab container")
				return
			}
			s.verified.Store(id, struct{}{})
		}
		next(w, r, id)
	}
}

func (s *Server) isLabContainer(ctx context.Context, id string) bool {
	for _, p := range ownedPrefixes {
		infos, err := s.rt.List(ctx, p)
		if err != nil {
			slog.Error("labagent: ownership list failed", "error", err)
			return false
		}
		for _, c := range infos {
			if strings.HasPrefix(c.Name, p) && (strings.HasPrefix(id, c.ID) || strings.HasPrefix(c.ID, id)) {
				return true
			}
		}
	}
	return false
}

func (s *Server) handleKill(w http.ResponseWriter, r *http.Request, id string) {
	if err := s.rt.Kill(r.Context(), id); err != nil {
		writeRuntimeErr(w, "kill", err)
		return
	}
	s.verified.Delete(id)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleExec(w http.ResponseWriter, r *http.Request, id string) {
	var req labs.AgentExecRequest
	if !decode(w, r, &req) {
		return
	}
	if err := ValidateExec(req); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var stdout, stderr string
	var code int
	var err error
	switch {
	case req.Mode == labs.AgentExecSetup:
		stdout, stderr, code, err = s.rt.ExecSetup(r.Context(), id, req.Script, req.TimeoutSec)
	case req.Stdin != nil:
		stdout, stderr, code, err = s.rt.ExecStdin(r.Context(), id, req.Script, req.Stdin, req.TimeoutSec)
	default:
		stdout, stderr, code, err = s.rt.Exec(r.Context(), id, req.Script, req.TimeoutSec)
	}
	if err != nil {
		writeRuntimeErr(w, "exec", err)
		return
	}
	writeJSON(w, http.StatusOK, labs.AgentExecResponse{Stdout: []byte(stdout), Stderr: []byte(stderr), ExitCode: code})
}

func (s *Server) handleExecCapture(w http.ResponseWriter, r *http.Request, id string) {
	var req labs.AgentExecCaptureRequest
	if !decode(w, r, &req) {
		return
	}
	if err := ValidateCapture(req); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	stdout, stderr, code, err := s.rt.ExecCapture(r.Context(), id, req.Script, req.MaxBytes)
	if err != nil {
		writeRuntimeErr(w, "exec-capture", err)
		return
	}
	writeJSON(w, http.StatusOK, labs.AgentExecResponse{Stdout: []byte(stdout), Stderr: []byte(stderr), ExitCode: code})
}

func (s *Server) handleRunning(w http.ResponseWriter, r *http.Request, id string) {
	writeJSON(w, http.StatusOK, labs.AgentRunningResponse{Running: s.rt.IsRunning(r.Context(), id)})
}

func (s *Server) handlePause(w http.ResponseWriter, r *http.Request, id string) {
	s.simple(w, "pause", s.rt.Pause(r.Context(), id))
}

func (s *Server) handleUnpause(w http.ResponseWriter, r *http.Request, id string) {
	s.simple(w, "unpause", s.rt.Unpause(r.Context(), id))
}

func (s *Server) simple(w http.ResponseWriter, op string, err error) {
	if err != nil {
		writeRuntimeErr(w, op, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ErrNoAllowedImages is returned by main when the allowlist is empty.
var ErrNoAllowedImages = errors.New("labagent: LABAGENT_ALLOWED_IMAGES must list at least one image")

// ParseAllowedImages splits the comma-separated allowlist env value.
func ParseAllowedImages(raw string) ([]string, error) {
	var out []string
	for _, p := range strings.Split(raw, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("labagent.ParseAllowedImages: %w", ErrNoAllowedImages)
	}
	return out, nil
}

// Command labagent runs on the dedicated lab host next to the Docker socket and
// serves the typed lab-runtime API over mTLS (see internal/labagent).
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/labagent"
	"github.com/mindforge/backend/internal/labs"
)

const (
	envListen         = "LABAGENT_LISTEN_ADDR"
	envCertFile       = "LABAGENT_TLS_CERT_FILE"
	envKeyFile        = "LABAGENT_TLS_KEY_FILE"
	envClientCAFile   = "LABAGENT_CLIENT_CA_FILE"
	envAllowedImages  = "LABAGENT_ALLOWED_IMAGES"
	defaultListenAddr = ":8443"
	probeTimeout      = 2 * time.Minute
	shutdownTimeout   = 15 * time.Second
	defaultPidsLimit  = labs.DefaultContainerPidsLimit
)

func main() {
	if err := run(); err != nil {
		slog.Error("labagent: fatal", "error", err)
		os.Exit(1)
	}
}

func envBool(key string, fallback bool) (bool, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		return false, fmt.Errorf("invalid %s: %w", key, err)
	}
	return v, nil
}

func run() error {
	allowed, err := labagent.ParseAllowedImages(os.Getenv(envAllowedImages))
	if err != nil {
		return err
	}
	names, err := config.ParseImageProfiles(os.Getenv("LABS_IMAGE_PROFILES"))
	if err != nil {
		return fmt.Errorf("LABS_IMAGE_PROFILES: %w", err)
	}
	profiles, err := labs.ResolveImageProfiles(names, os.Getenv("LABS_NESTED_DOCKER_RUNTIME"), "")
	if err != nil {
		return err
	}
	for image := range profiles {
		if !contains(allowed, image) {
			return fmt.Errorf("LABS_IMAGE_PROFILES image %q is not in %s", image, envAllowedImages)
		}
	}

	perSession, err := envBool("LABS_NETWORK_PER_SESSION", true)
	if err != nil {
		return err
	}
	internal, err := envBool("LABS_NETWORK_INTERNAL", false)
	if err != nil {
		return err
	}
	quota, err := envBool("LABS_STORAGE_QUOTA_ENABLED", true)
	if err != nil {
		return err
	}
	pids := defaultPidsLimit
	if raw := os.Getenv("LABS_PIDS_LIMIT"); raw != "" {
		if pids, err = strconv.Atoi(raw); err != nil {
			return fmt.Errorf("invalid LABS_PIDS_LIMIT: %w", err)
		}
	}

	docker := labs.NewDockerContainerService(profiles)
	docker.SetHardening(
		labs.RuntimeLimits{PidsLimit: pids, StorageQuota: quota},
		labs.NetworkPolicy{PerSession: perSession, Internal: internal, ProxyContainer: os.Getenv("LABS_PROXY_CONTAINER")})

	if quota {
		ctx, cancel := context.WithTimeout(context.Background(), probeTimeout)
		err := docker.ProbeStorageQuota(ctx, allowed[0])
		cancel()
		if err != nil {
			return fmt.Errorf("LABS_STORAGE_QUOTA_ENABLED is on but the host cannot enforce it (set it false only knowingly): %w", err)
		}
	}

	tlsCfg, err := serverTLS(os.Getenv(envCertFile), os.Getenv(envKeyFile), os.Getenv(envClientCAFile))
	if err != nil {
		return err
	}
	addr := os.Getenv(envListen)
	if addr == "" {
		addr = defaultListenAddr
	}
	srv := &http.Server{
		Addr:              addr,
		Handler:           labagent.New(docker, allowed).Handler(),
		TLSConfig:         tlsCfg,
		ReadHeaderTimeout: 10 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServeTLS("", "") }()
	slog.Info("labagent: listening", "addr", addr, "allowed_images", len(allowed), "storage_quota", quota, "per_session_network", perSession)

	select {
	case err := <-errCh:
		return fmt.Errorf("serve: %w", err)
	case <-ctx.Done():
		sctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		return srv.Shutdown(sctx)
	}
}

// serverTLS requires and verifies a client certificate signed by the CA file.
func serverTLS(certFile, keyFile, clientCAFile string) (*tls.Config, error) {
	if certFile == "" || keyFile == "" || clientCAFile == "" {
		return nil, fmt.Errorf("%s, %s and %s are required", envCertFile, envKeyFile, envClientCAFile)
	}
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, fmt.Errorf("load server cert: %w", err)
	}
	caPEM, err := os.ReadFile(clientCAFile)
	if err != nil {
		return nil, fmt.Errorf("read client CA: %w", err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(caPEM) {
		return nil, errors.New("client CA file has no certificates")
	}
	return &tls.Config{
		MinVersion:   tls.VersionTLS13,
		Certificates: []tls.Certificate{cert},
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    pool,
	}, nil
}

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}

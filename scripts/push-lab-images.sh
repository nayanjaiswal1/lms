#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/push-lab-images.sh — Build every lab-images/* Dockerfile and push it
# to a registry, so the Kubernetes runtime pulls lab sandbox images normally
# instead of needing a manual `docker save | k3s ctr images import` after
# every build (the fragile step that broke when mindforge/lab-k8s:1.31 was
# added but never wired into that import loop — see docs/local-k3s-dev.md).
#
# Usage:
#   bash scripts/push-lab-images.sh                       # local dev default
#   REGISTRY=ghcr.io/youruser bash scripts/push-lab-images.sh   # any registry
#
# REGISTRY   Optional. Any registry the cluster's nodes can pull from
#            (a private registry, ghcr.io/youruser, docker.io/youruser, ...).
#            Defaults to "localhost:5000" — a throwaway `registry:2` container
#            this script starts itself (idempotent) — for local k3s dev with
#            zero external account/credentials needed.
#
# After this, set LABS_IMAGE_REGISTRY="$REGISTRY" wherever the backend runs
# (backend/.env for native hybrid dev, or the k8s overlay's ConfigMap patch
# for an in-cluster backend) — see ENV_VARS.md "LABS_IMAGE_REGISTRY". The
# backend classifies against the bare image name (LABS_IMAGE_PROFILES,
# content frontmatter) regardless of registry; only the Pod's pulled image
# gains the "<registry>/" prefix (runtime_kubernetes.go, qualifyImage).
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

command -v docker &>/dev/null || error "docker is not installed."

REGISTRY="${REGISTRY:-localhost:5000}"
USING_LOCAL_DEFAULT=false
[[ "$REGISTRY" == "localhost:5000" ]] && USING_LOCAL_DEFAULT=true

if [[ "$USING_LOCAL_DEFAULT" == true ]]; then
  if docker ps --format '{{.Names}}' | grep -qx mindforge-local-registry; then
    info "Local registry container already running."
  elif systemctl is-enabled mindforge-local-registry &>/dev/null; then
    # setup-k3s-local.sh installed the systemd unit — it owns this container
    # (recreates it on crash/removal/reboot). Start it rather than racing it
    # with a second, unmanaged `docker run` of the same name.
    info "Starting mindforge-local-registry via systemd..."
    sudo systemctl start mindforge-local-registry
  elif docker ps -a --format '{{.Names}}' | grep -qx mindforge-local-registry; then
    info "Starting existing local registry container..."
    docker start mindforge-local-registry >/dev/null
  else
    warn "No systemd unit found (see scripts/setup-k3s-local.sh) — starting a plain docker container instead. It won't survive a 'docker rm'; re-run scripts/setup-k3s-local.sh to install the self-healing systemd unit."
    docker run -d --restart=always -p 5000:5000 -v mindforge-registry-data:/var/lib/registry --name mindforge-local-registry registry:2 >/dev/null
  fi
  success "Local registry ready at ${REGISTRY}."

  # k3s's containerd refuses plain-HTTP registries unless told to trust one —
  # scripts/setup-k3s-local.sh writes this; just verify it's in place so a
  # push here doesn't silently produce images the cluster can't pull.
  # world-readable (root:root 644 under a 755 dir) — plain test, no sudo
  # needed, and sudo here would block forever on a password prompt when run
  # non-interactively (no TTY to answer it).
  if command -v k3s &>/dev/null && [[ ! -f /etc/rancher/k3s/registries.yaml ]]; then
    warn "k3s has no /etc/rancher/k3s/registries.yaml — pulls from ${REGISTRY} will fail with an HTTPS error until scripts/setup-k3s-local.sh has been (re-)run."
  fi
fi

# name:tag as already referenced by LABS_IMAGE_PROFILES / course content
# frontmatter (backend/.env, content/courses/**, docs/labs.md) — this script
# is the one place that list is kept in sync with what actually gets built.
declare -A IMAGES=(
  ["lab-images/lab-docker/Dockerfile"]="mindforge/lab-docker:27"
  ["lab-images/lab-docker/Dockerfile.sysbox"]="mindforge/lab-docker-sysbox:27"
  ["lab-images/lab-k8s/Dockerfile"]="mindforge/lab-k8s:1.31"
  ["lab-images/lab-node-web/Dockerfile"]="mindforge/lab-node-web:22"
  ["lab-images/lab-python-web/Dockerfile"]="mindforge/lab-python-web:3.12"
)

for dockerfile in "${!IMAGES[@]}"; do
  name="${IMAGES[$dockerfile]}"
  # lab-node-web and lab-python-web COPY their entrypoint.sh/app-runner.sh
  # from lab-images/shared/ (deduped — the two were byte-identical copies),
  # so those two need the wider lab-images/ context; every other image's
  # Dockerfile still only COPYs from its own directory.
  case "$dockerfile" in
    lab-images/lab-node-web/Dockerfile|lab-images/lab-python-web/Dockerfile)
      context="lab-images" ;;
    *)
      context="$(dirname "$dockerfile")" ;;
  esac
  target="${REGISTRY}/${name}"
  info "Building ${name} (${dockerfile})..."
  docker build -t "$target" -f "$dockerfile" "$context"
  info "Pushing ${target}..."
  docker push "$target"
  success "${target} pushed."
done

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Lab images pushed to ${REGISTRY}${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  Set LABS_IMAGE_REGISTRY=${REGISTRY} wherever the backend runs, then"
echo "  restart it (native hybrid dev: backend/.env + restart air; in-cluster:"
echo "  kubectl rollout restart deployment/backend -n mindforge)."
echo ""

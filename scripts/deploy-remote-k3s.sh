#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/deploy-remote-k3s.sh — Deploy MindForge to a k3s box over SSH.
#
# Usage: scripts/deploy-remote-k3s.sh <user@host> [domain] [--force-clear-docker]
#   user@host             SSH target. Needs a working k3s install (or root
#                          enough to get one — see setup-k3s-local.sh).
#                          Use the target's mDNS name (e.g. nayan@ideapad.local),
#                          not a bare IP — a DHCP lease change silently breaks
#                          an IP-pinned target on the next run.
#   domain                Hostname the app is served on. Defaults to the
#                          target's own mDNS name (mindforge.<hostname>.local).
#   --force-clear-docker  sysbox-ce's installer refuses to run with ANY
#                          existing docker container (even stopped ones) and
#                          wants them removed. Without this flag the script
#                          aborts and lists them instead of deleting anything
#                          on your behalf.
#
# Images build HERE (wherever this script runs), not on the target: an actual
# remote laptop's wifi turned out to be too unreliable to sustain `npm ci` /
# multi-minute docker builds without timing out or dropping mid-transfer.
# Only the lightweight parts still touch the network per deploy — the small
# scripts/ + k8s/ directories, and each built image's layers via
# `docker save | ssh ... k3s ctr images import` (far shorter-lived than a
# full source-tree transfer + remote build). No registry involved: lab images
# are imported under the exact "localhost:5000/..." tag the backend already
# requests at runtime (LABS_IMAGE_REGISTRY), so that "pull" is a local
# containerd cache hit, never an actual network fetch.
#
# One-time cluster setup (k3s, Traefik's Gateway API provider, cert-manager,
# sysbox-ce wiring) still runs ON the target via SSH — those are lightweight
# kubectl/helm/systemctl calls, not builds, and stay idempotent/skip-if-done
# via the existing setup-k3s-local.sh / setup-sysbox-local.sh.
#
# Requires Docker running locally, targeting linux/amd64 (the k3s node's
# arch — `docker version --format '{{.Server.Os}}/{{.Server.Arch}}'` to check).
#
# Safe to re-run against the same host (every step is idempotent).
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

TARGET="${1:-}"
[[ -n "$TARGET" ]] || error "Usage: $0 <user@host> [domain] [--force-clear-docker]"
shift

DOMAIN=""
FORCE_CLEAR_DOCKER=false
for arg in "$@"; do
  case "$arg" in
    --force-clear-docker) FORCE_CLEAR_DOCKER=true ;;
    *) DOMAIN="$arg" ;;
  esac
done

command -v docker &>/dev/null || error "docker is not installed locally."

# Retries only on 255 (ssh's own connection-level failure — never returned by
# the remote command itself), so a transient mDNS/wifi blip on a quick
# command doesn't abort the whole run.
ssh_target() {
  local attempt rc
  for attempt in 1 2 3 4 5; do
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes "$TARGET" "$@"
    rc=$?
    [[ $rc -ne 255 ]] && return $rc
    [[ $attempt -lt 5 ]] && sleep 3
  done
  return 255
}

# ─── 1. SSH key auth ──────────────────────────────────────────────────────────
info "Checking SSH key auth to ${TARGET}..."
ssh_target true 2>/dev/null || error "Passwordless SSH to ${TARGET} isn't set up. Run: ssh-copy-id ${TARGET}"
success "SSH key auth works."

# ─── 2. Passwordless sudo (one-time) ─────────────────────────────────────────
if ssh_target sudo -n true 2>/dev/null; then
  info "Passwordless sudo already set up on ${TARGET} — skipping."
else
  warn "One-time fix: a scoped sudoers.d drop-in granting NOPASSWD to this SSH user (needed for k3s/sysbox setup and image import, none of which have a TTY to prompt on)."
  if [[ -n "${DEPLOY_SUDO_PASSWORD:-}" ]]; then
    SUDO_PW="$DEPLOY_SUDO_PASSWORD"
  else
    read -r -s -p "One-time sudo password for ${TARGET} (not stored; or set DEPLOY_SUDO_PASSWORD to skip this prompt): " SUDO_PW
    echo
  fi
  REMOTE_USER="${TARGET%@*}"
  echo "$SUDO_PW" | ssh_target "sudo -S -v" 2>/dev/null || error "sudo authentication failed."
  echo "$SUDO_PW" | ssh_target "sudo -S bash -c 'echo \"${REMOTE_USER} ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/mindforge-deploy && chmod 440 /etc/sudoers.d/mindforge-deploy && visudo -cf /etc/sudoers.d/mindforge-deploy'" \
    || error "Failed to write /etc/sudoers.d/mindforge-deploy."
  unset SUDO_PW
  ssh_target sudo -n true 2>/dev/null || error "sudoers drop-in written but passwordless sudo still isn't working."
  success "Passwordless sudo configured."
fi

# ─── 3. Transfer only the lightweight bits (scripts/ + k8s/) ────────────────
info "Transferring scripts/ + k8s/ to ${TARGET}:~/mindforge..."
TRANSFER_OK=false
for attempt in 1 2 3; do
  if tar -czf - scripts k8s | ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes \
      "$TARGET" "mkdir -p ~/mindforge && rm -rf ~/mindforge/scripts ~/mindforge/k8s && tar -xzf - -C ~/mindforge"; then
    TRANSFER_OK=true
    break
  fi
  warn "Transfer attempt ${attempt}/3 failed — retrying..."
  sleep 3
done
[[ "$TRANSFER_OK" == true ]] || error "Transfer to ${TARGET} failed after 3 attempts."
success "Transferred."

# ─── 4. helm on PATH (setup-k3s-local.sh's own preflight needs it first) ────
if ssh_target "command -v helm" &>/dev/null; then
  info "helm already on PATH remotely — skipping."
else
  info "Installing helm remotely..."
  ssh_target "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh && chmod +x /tmp/get_helm.sh && sudo /tmp/get_helm.sh" >/dev/null
  ssh_target "command -v helm" &>/dev/null || error "helm install failed."
  success "helm installed."
fi

# ─── 5. Resolve the domain, point the local overlay at it ───────────────────
if [[ -z "$DOMAIN" ]]; then
  if ! ssh_target "systemctl is-active --quiet avahi-daemon" 2>/dev/null; then
    error "avahi-daemon isn't running on ${TARGET} — can't derive a stable mDNS domain. Pass one explicitly: $0 ${TARGET} <domain>"
  fi
  REMOTE_HOSTNAME="$(ssh_target hostname)"
  [[ -n "$REMOTE_HOSTNAME" ]] || error "Couldn't read ${TARGET}'s hostname."
  DOMAIN="mindforge.${REMOTE_HOSTNAME}.local"
  info "No domain given — using ${TARGET}'s mDNS name: ${DOMAIN}"
fi
info "Pointing the local overlay at ${DOMAIN} (remote copy only)..."
ssh_target "cd ~/mindforge && sed -i 's/mindforge\\.127\\.0\\.0\\.1\\.nip\\.io/${DOMAIN}/g' \
  k8s/overlays/local/configmap-domain.patch.yaml \
  k8s/overlays/local/kustomization.yaml"
success "Local overlay targets ${DOMAIN}."

# ─── 6. sysbox-ce (nested-docker lab support) ────────────────────────────────
if ssh_target "command -v sysbox-runc" &>/dev/null; then
  info "sysbox-runc already installed remotely — skipping."
else
  info "Installing sysbox-ce remotely..."
  ARCH="$(ssh_target "dpkg --print-architecture")"
  EXISTING="$(ssh_target "docker ps -aq" 2>/dev/null || true)"
  if [[ -n "$EXISTING" ]]; then
    if [[ "$FORCE_CLEAR_DOCKER" == true ]]; then
      warn "Removing existing docker containers on ${TARGET} (--force-clear-docker)."
      ssh_target "docker rm -f \$(docker ps -aq)" >/dev/null
    else
      ssh_target "docker ps -a"
      error "sysbox-ce's installer needs docker ps -a empty — see containers listed above on ${TARGET}. Re-run with --force-clear-docker to remove them, or clear them yourself first."
    fi
  fi
  LATEST_TAG="$(curl -fsSL https://api.github.com/repos/nestybox/sysbox/releases/latest | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)"
  [[ -n "$LATEST_TAG" ]] || error "Couldn't resolve latest sysbox-ce release tag from GitHub."
  DEB_VERSION="${LATEST_TAG#v}"
  DEB_URL="https://github.com/nestybox/sysbox/releases/download/${LATEST_TAG}/sysbox-ce_${DEB_VERSION}.linux_${ARCH}.deb"
  ssh_target "curl -fsSL -o /tmp/sysbox-ce.deb '${DEB_URL}' && sudo apt-get install -y /tmp/sysbox-ce.deb" >/dev/null \
    || error "sysbox-ce install failed — check the deb exists for arch ${ARCH} at ${DEB_URL}."
  ssh_target "command -v sysbox-runc" &>/dev/null || error "sysbox-ce installed but sysbox-runc still not on PATH."
  success "sysbox-ce installed."
fi

# ─── 7. One-time cluster setup (k3s Traefik Gateway, cert-manager, sysbox) ──
# Lightweight kubectl/helm/systemctl calls, not builds — safe and fast to
# always run; each step already checks-and-skips what's done.
info "Running cluster setup (k3s Gateway API + cert-manager)..."
ssh_target "cd ~/mindforge && KUBECONFIG=\$HOME/.kube/config bash scripts/setup-k3s-local.sh"
info "Running sysbox RuntimeClass wiring..."
ssh_target "cd ~/mindforge && KUBECONFIG=\$HOME/.kube/config bash scripts/setup-sysbox-local.sh"

# ─── 8. Build app images locally, import into remote containerd ─────────────
info "Building backend locally..."
docker build -t mindforge-backend:local -f backend/Dockerfile backend/
info "Building labproxy locally..."
docker build -t mindforge-labproxy:local -f backend/Dockerfile.labproxy backend/
info "Building frontend locally (NEXT_PUBLIC_* baked in for https://${DOMAIN})..."
docker build -t mindforge-frontend:local -f frontend/Dockerfile \
  --build-arg NEXT_PUBLIC_API_URL="" \
  --build-arg NEXT_PUBLIC_APP_URL="https://${DOMAIN}" \
  --build-arg NEXT_PUBLIC_MEDIA_URL="https://${DOMAIN}" \
  --build-arg NEXT_PUBLIC_LAB_PROXY_URL="wss://${DOMAIN}/lab-ws" \
  --build-arg NEXT_PUBLIC_GOOGLE_OAUTH_ENABLED="false" \
  --build-arg NEXT_PUBLIC_GITHUB_OAUTH_ENABLED="false" \
  frontend/
success "App images built locally."

import_image() {
  local image="$1" attempt ok=false
  for attempt in 1 2 3; do
    if docker save "$image" | ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes \
        "$TARGET" "sudo k3s ctr images import -"; then
      ok=true
      break
    fi
    warn "Import of ${image} attempt ${attempt}/3 failed — retrying..."
    sleep 3
  done
  [[ "$ok" == true ]] || error "Failed to import ${image} into ${TARGET}'s containerd after 3 attempts."
}
info "Importing app images into ${TARGET}'s k3s containerd..."
import_image mindforge-backend:local
import_image mindforge-labproxy:local
import_image mindforge-frontend:local
success "App images imported."

# ─── 9. Build + import lab sandbox images ────────────────────────────────────
# Tagged under the exact "localhost:5000/..." name LABS_IMAGE_REGISTRY makes
# the backend request at runtime — importing under that tag means the
# runtime "pull" is a local containerd cache hit, so no registry ever needs
# to actually be reachable.
declare -A LAB_IMAGES=(
  ["lab-images/lab-docker/Dockerfile"]="mindforge/lab-docker:27"
  ["lab-images/lab-docker/Dockerfile.sysbox"]="mindforge/lab-docker-sysbox:27"
  ["lab-images/lab-k8s/Dockerfile"]="mindforge/lab-k8s:1.31"
  ["lab-images/lab-node-web/Dockerfile"]="mindforge/lab-node-web:22"
  ["lab-images/lab-python-web/Dockerfile"]="mindforge/lab-python-web:3.12"
)
info "Building + importing lab sandbox images..."
for dockerfile in "${!LAB_IMAGES[@]}"; do
  name="${LAB_IMAGES[$dockerfile]}"
  case "$dockerfile" in
    lab-images/lab-node-web/Dockerfile|lab-images/lab-python-web/Dockerfile)
      context="lab-images" ;;
    *)
      context="$(dirname "$dockerfile")" ;;
  esac
  target="localhost:5000/${name}"
  info "Building ${target}..."
  docker build -t "$target" -f "$dockerfile" "$context"
  import_image "$target"
done
success "Lab images built and imported."

# ─── 10. Deploy ───────────────────────────────────────────────────────────────
info "Applying manifests..."
ssh_target "cd ~/mindforge && KUBECONFIG=\$HOME/.kube/config kubectl apply -k k8s/overlays/local"
success "Manifests applied."

info "Waiting for rollouts..."
for deploy in backend labproxy frontend; do
  ssh_target "KUBECONFIG=\$HOME/.kube/config kubectl rollout status deployment/${deploy} -n mindforge --timeout=180s" \
    || warn "${deploy} rollout did not complete in time — check: kubectl get pods -n mindforge"
done
ssh_target "KUBECONFIG=\$HOME/.kube/config kubectl rollout status statefulset/postgres -n mindforge --timeout=180s" || warn "postgres rollout did not complete in time"
ssh_target "KUBECONFIG=\$HOME/.kube/config kubectl rollout status statefulset/minio -n mindforge --timeout=180s" || warn "minio rollout did not complete in time"
ssh_target "KUBECONFIG=\$HOME/.kube/config kubectl rollout status deployment/piston -n mindforge-labs --timeout=180s" || warn "piston rollout did not complete in time"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  MindForge deployed to ${TARGET}${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  App: https://${DOMAIN} (accept the self-signed cert warning)"
echo "  Redeploy after code changes: $0 ${TARGET} ${DOMAIN}"
echo ""

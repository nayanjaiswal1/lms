#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/setup-k3s-local.sh — ONE-TIME cluster bootstrap for running MindForge
# on k3s inside WSL. Installs k3s (with Traefik's Gateway API provider
# enabled), Helm, cert-manager (with Gateway API support), and a local
# self-signed ClusterIssuer. Safe to re-run — every step is idempotent.
#
# Run this INSIDE WSL, from the mindforge/ directory (i.e. after rsyncing the
# repo to WSL's native filesystem — see docs/local-k3s-dev.md for why).
#
# After this: scripts/build-k3s-local-images.sh, then
#             scripts/deploy-k8s.sh local
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

[[ "$(uname -r)" == *microsoft* ]] || warn "This doesn't look like WSL — the script should still work on any bare-metal Linux box, but it was only tested under WSL2."

# ─── 1. docker group (needed to build images later without sudo) ─────────────
if ! groups | grep -q '\bdocker\b'; then
  info "Adding $USER to the docker group (needs sudo password)..."
  sudo usermod -aG docker "$USER"
  warn "Group membership only takes effect in a NEW shell — re-run this script in a fresh terminal if the next docker command fails with a permission error."
fi

# ─── 2. k3s, with Traefik's Gateway API provider enabled ─────────────────────
# k3s bundles Traefik but its Gateway API provider is off by default. This
# HelmChartConfig must exist before (or be present when re-triggering) the
# bundled Traefik chart install — k3s's helm-controller watches this directory.
if ! command -v k3s &>/dev/null; then
  info "Installing k3s..."
  sudo mkdir -p /var/lib/rancher/k3s/server/manifests
  sudo cp k8s/local-cluster-setup/traefik-gateway-helmchartconfig.yaml \
    /var/lib/rancher/k3s/server/manifests/k3s-traefik-config.yaml
  curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
  sudo INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh /tmp/k3s-install.sh
  success "k3s installed."
else
  info "k3s already installed — ensuring the Traefik Gateway HelmChartConfig is in place..."
  sudo mkdir -p /var/lib/rancher/k3s/server/manifests
  sudo cp k8s/local-cluster-setup/traefik-gateway-helmchartconfig.yaml \
    /var/lib/rancher/k3s/server/manifests/k3s-traefik-config.yaml
fi

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER" ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
if ! grep -q 'KUBECONFIG=~/.kube/config' ~/.bashrc 2>/dev/null; then
  echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
fi

info "Waiting for the node to be Ready..."
for i in $(seq 1 30); do
  kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready " && break
  sleep 2
done
kubectl get nodes --no-headers | grep -q " Ready " || error "Node never became Ready — check: sudo systemctl status k3s"
success "k3s node Ready."

# Do NOT install the standalone Gateway API CRDs yourself — Traefik's own
# traefik-crd helm chart bundles and owns a compatible copy. If both try to
# own the same CRDs, Helm refuses to "adopt" ones it didn't create and the
# traefik-crd install job fails with an ownership-metadata error.
info "Waiting for Traefik (Gateway API provider) to come up..."
for i in $(seq 1 60); do
  kubectl get gatewayclass traefik &>/dev/null && break
  sleep 3
done
kubectl get gatewayclass traefik &>/dev/null || error "GatewayClass 'traefik' never appeared — check: kubectl get pods -n kube-system"
success "Traefik GatewayClass registered."

# ─── 2b. Trust the local plain-HTTP lab-image registry ───────────────────────
# containerd refuses a plain-HTTP registry by default ("server gave HTTP
# response to HTTPS client"). scripts/push-lab-images.sh's default registry
# (localhost:5000, a `registry:2` container it starts itself — no TLS cert to
# manage for a registry with no public hostname) needs this to be pullable.
# Only touches containerd's registry trust, not the app Gateway/TLS — that's
# unrelated cert-manager config elsewhere in this script.
REGISTRIES_YAML=/etc/rancher/k3s/registries.yaml
if ! sudo test -f "$REGISTRIES_YAML" || ! sudo grep -q 'localhost:5000' "$REGISTRIES_YAML" 2>/dev/null; then
  info "Configuring k3s's containerd to trust localhost:5000 as plain HTTP..."
  sudo mkdir -p /etc/rancher/k3s
  cat <<'EOF' | sudo tee "$REGISTRIES_YAML" >/dev/null
mirrors:
  "localhost:5000":
    endpoint:
      - "http://localhost:5000"
configs:
  "localhost:5000":
    tls:
      insecure_skip_verify: true
EOF
  info "Restarting k3s to pick up registries.yaml..."
  sudo systemctl restart k3s
  info "Waiting for the node to be Ready again..."
  for i in $(seq 1 30); do
    kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready " && break
    sleep 2
  done
  kubectl get nodes --no-headers | grep -q " Ready " || error "Node never became Ready after restart — check: sudo systemctl status k3s"
  success "k3s trusts localhost:5000."
else
  info "k3s already trusts localhost:5000 — skipping."
fi

# ─── 2c. Local lab-image registry as a self-healing systemd unit ─────────────
# scripts/push-lab-images.sh can start the localhost:5000 registry container
# itself, but a plain `docker run --restart=always` only survives a
# docker/WSL restart — not an outright `docker rm` (which is exactly what
# happened once already: the container vanished mid-session with no restart,
# breaking every lab launch until someone noticed and re-ran the push script).
# A systemd unit tracks the container as its own process tree: if it's killed
# OR removed, systemd restarts ExecStart, which recreates the container from
# the named volume (mindforge-registry-data) — no manual intervention, no
# re-push needed. See k8s/local-cluster-setup/mindforge-local-registry.service.
if [[ -d /run/systemd/system ]]; then
  UNIT_PATH=/etc/systemd/system/mindforge-local-registry.service
  if ! sudo diff -q k8s/local-cluster-setup/mindforge-local-registry.service "$UNIT_PATH" &>/dev/null; then
    info "Installing mindforge-local-registry systemd unit..."
    sudo cp k8s/local-cluster-setup/mindforge-local-registry.service "$UNIT_PATH"
    sudo systemctl daemon-reload
  fi
  sudo systemctl enable --now mindforge-local-registry >/dev/null
  success "Local registry running as a systemd unit (self-heals on removal/reboot)."
else
  warn "No systemd in this environment — falling back to push-lab-images.sh's ad hoc 'docker run --restart=always', which won't survive an outright container removal."
fi

# ─── 3. Helm ──────────────────────────────────────────────────────────────────
if ! command -v helm &>/dev/null; then
  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh
  chmod +x /tmp/get_helm.sh
  sudo /tmp/get_helm.sh
  success "Helm installed."
fi

# ─── 4. cert-manager, with Gateway API support ────────────────────────────────
if ! kubectl get deploy cert-manager -n cert-manager &>/dev/null; then
  info "Installing cert-manager (with Gateway API support)..."
  helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
  helm repo update jetstack >/dev/null
  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true \
    --set config.apiVersion=controller.config.cert-manager.io/v1alpha1 \
    --set config.kind=ControllerConfiguration \
    --set config.enableGatewayAPI=true
  info "Waiting for cert-manager to be ready..."
  kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
  kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
  success "cert-manager installed."
else
  info "cert-manager already installed."
fi

# ─── 5. Local self-signed ClusterIssuer ──────────────────────────────────────
# Named "letsencrypt-prod" to match the cert-manager.io/cluster-issuer
# annotation already baked into k8s/base/gateway.yaml — so the app manifests
# need zero patching for this between local and cloud. Only the ClusterIssuer
# *implementation* differs: self-signed here (browser shows an
# untrusted-certificate warning — expected for local dev), real ACME in prod.
kubectl apply -f k8s/local-cluster-setup/selfsigned-issuer.yaml
success "Local ClusterIssuer ready."

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  k3s cluster ready for MindForge${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  Next:  bash scripts/build-k3s-local-images.sh"
echo "         bash scripts/deploy-k8s.sh local"
echo ""

#!/usr/bin/env bash
# One-shot setup of a remote Linux dev box (Debian/Ubuntu) for `make dev-k3s`.
# Idempotent. Run from the repo root after copying .env and backend/.env onto the box.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

have() { command -v "$1" >/dev/null 2>&1; }
need_file() { [[ -f "$1" ]] || { echo "missing $1 — copy it from your main machine first" >&2; exit 1; }; }

need_file .env
need_file backend/.env
chmod 600 .env backend/.env

sudo apt-get update -y
sudo apt-get install -y make git curl unzip golang-go
have bun       || curl -fsSL https://bun.sh/install | bash
grep -q ".bun/bin" ~/.bashrc || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
have kubectl   || { curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
                    && sudo install /tmp/kubectl /usr/local/bin/kubectl; }
have tailscale || curl -fsSL https://tailscale.com/install.sh | sh

if ! kubectl get ns mindforge >/dev/null 2>&1; then
  mkdir -p ~/.kube
  sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sudo chown "$USER" ~/.kube/config
  chmod 600 ~/.kube/config
fi
export KUBECONFIG="$HOME/.kube/config"
grep -q KUBECONFIG ~/.bashrc || echo 'export KUBECONFIG="$HOME/.kube/config"' >> ~/.bashrc
kubectl get pods -n mindforge >/dev/null

tailscale status >/dev/null 2>&1 || sudo tailscale up
sudo tailscale serve --bg 3000

echo "Ready. Set PISTON_URL=http://localhost:2000 and LABS_RUNTIME=kubernetes in backend/.env, then: make dev-k3s"

#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/bootstrap-k3s-local.sh — ONE command from a freshly-rsynced repo to a
# verified-working local k3s deploy. Chains the existing one-time scripts in
# the right order and, critically, VERIFIES the result instead of stopping at
# "kubectl apply didn't error" — including a real nested-docker lab smoke
# test, since "manifests applied cleanly" and "the docker course actually
# works" turned out to be two different claims (missing RuntimeClass, missing
# node label, unbounded emptyDir — see docs/local-k3s-dev.md "Bugs found and
# fixed" #11 and ENV_VARS.md). A clean run of this script means every
# verification passed, not just that no command returned nonzero.
#
# Run this INSIDE WSL, from ~/mindforge (i.e. AFTER rsyncing — see
# docs/local-k3s-dev.md "One-time setup" step 1; this script can't rsync
# itself into existence). Safe to re-run.
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

# ─── 0. PATH sanity ──────────────────────────────────────────────────────────
# Seen in the wild: a broken `export PATH=...` line in ~/.bashrc (a stray
# trailing backslash line-continuing into the next export, or a plain
# `PATH=foo` that replaces rather than extends the default) silently drops
# /bin and /usr/bin. Every command below then fails with a confusing string
# of "command not found"s that look unrelated to each other. Check once, up
# front, with a diagnosis pointing at the actual cause.
for cmd in rsync kubectl docker sudo curl helm; do
  command -v "$cmd" &>/dev/null || error "'$cmd' not found on PATH. Run: echo \$PATH — if /usr/bin or /bin is missing from it, check ~/.bashrc for a broken 'export PATH=' line (this has happened before: a trailing '\\' swallowing the next line's export)."
done
success "PATH looks sane (rsync/kubectl/docker/sudo/curl/helm all resolve)."

# ─── 1. k3s + Traefik Gateway + cert-manager ─────────────────────────────────
info "── Step 1/6: k3s cluster ──"
bash scripts/setup-k3s-local.sh

# ─── 2. sysbox-runc, only if it's actually installed on this host ──────────
# Installing sysbox-ce itself is out of scope (see setup-sysbox-local.sh) —
# this just decides whether to wire in what's already there, so a host
# without it still gets everything else working instead of a hard stop.
SYSBOX_READY=false
info "── Step 2/6: sysbox-runc RuntimeClass ──"
if command -v sysbox-runc &>/dev/null; then
  bash scripts/setup-sysbox-local.sh
  SYSBOX_READY=true
else
  warn "sysbox-runc not installed on this host — skipping. Nested-docker courses (e.g. \"docker\") will fail until it's installed: see github.com/nestybox/sysbox/releases, then re-run this script."
fi

# ─── 3. App images ────────────────────────────────────────────────────────────
info "── Step 3/6: build + import app images ──"
bash scripts/build-k3s-local-images.sh

# ─── 3b. Lab sandbox images ───────────────────────────────────────────────────
# Pushed to a registry (default: the localhost:5000 container this script
# starts) rather than imported ad hoc — see scripts/push-lab-images.sh and
# docs/local-k3s-dev.md "Bugs found and fixed" for why the old per-script
# import loop kept missing newly-added lab images (mindforge/lab-k8s:1.31
# shipped in content before anything ever imported it).
info "── Step 4/6: push lab sandbox images ──"
bash scripts/push-lab-images.sh
LABS_IMAGE_REGISTRY="${REGISTRY:-localhost:5000}"

# ─── 4. Deploy ────────────────────────────────────────────────────────────────
info "── Step 5/6: deploy ──"
bash scripts/deploy-k8s.sh local

# ─── 5. Verify — this is the step that was missing ──────────────────────────
info "── Step 6/6: verifying the deploy actually works ──"

# 5a. Rollouts genuinely Available, not just "deploy-k8s.sh didn't error"
# (deploy-k8s.sh itself only warns on a rollout timeout, so re-check as a
# hard gate here).
for deploy in backend labproxy frontend; do
  kubectl rollout status "deployment/${deploy}" -n mindforge --timeout=10s \
    || error "deployment/${deploy} is not Available — check: kubectl get pods -n mindforge; kubectl describe deployment/${deploy} -n mindforge"
done
success "backend/labproxy/frontend deployments are Available."

# 5b. A real request through the backend, not just a passing readiness probe.
info "Checking backend /health via port-forward..."
kubectl port-forward -n mindforge svc/backend 18080:8080 &>/tmp/bootstrap-pf-health.log &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
health_ok=false
for i in $(seq 1 15); do
  if curl -sf http://127.0.0.1:18080/health &>/dev/null; then health_ok=true; break; fi
  sleep 1
done
kill "$PF_PID" 2>/dev/null || true
trap - EXIT
[[ "$health_ok" == true ]] || error "Backend /health did not respond — check: kubectl logs -n mindforge -l app=backend"
success "Backend /health responded."

# 5c. Gateway/HTTPRoute actually programmed, not just applied.
gw_ok="$(kubectl get gateway mindforge -n mindforge -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || true)"
[[ "$gw_ok" == "True" ]] || warn "Gateway 'mindforge' is not Programmed yet — check: kubectl describe gateway mindforge -n mindforge (Traefik can take a few seconds after a fresh apply)."
route_ok="$(kubectl get httproute mindforge -n mindforge -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || true)"
[[ "$route_ok" == "True" ]] || warn "HTTPRoute 'mindforge' is not Accepted yet — check: kubectl describe httproute mindforge -n mindforge"
[[ "$gw_ok" == "True" && "$route_ok" == "True" ]] && success "Gateway + HTTPRoute programmed."

# 5d. The actual thing that broke twice: a real nested-docker lab pod, using
# the real course image and the real Pod shape the backend constructs (see
# backend/internal/labs/runtime_kubernetes.go, backend/internal/labs/models.go
# NestedContainerCPU/MemoryMB/DiskGB) — not a busybox stand-in. This is what
# catches "RuntimeClass exists but no node is labeled" or "emptyDir has no
# size limit" BEFORE a student does, not after.
if [[ "$SYSBOX_READY" == true ]]; then
  SYSBOX_IMAGE="${LABS_IMAGE_REGISTRY}/mindforge/lab-docker-sysbox:27"
  info "End-to-end nested-docker smoke test (${SYSBOX_IMAGE}, pulled via registry — the real path a student's session takes)..."
  kubectl delete pod sysbox-e2e-test -n mindforge-labs --ignore-not-found --now &>/dev/null
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: sysbox-e2e-test
  namespace: mindforge-labs
spec:
  runtimeClassName: sysbox-runc
  hostUsers: false
  restartPolicy: Never
  containers:
  - name: sandbox
    image: ${SYSBOX_IMAGE}
    resources:
      requests: {cpu: "2.0", memory: 1536Mi, ephemeral-storage: 10Gi}
      limits: {cpu: "2.0", memory: 1536Mi, ephemeral-storage: 10Gi}
    securityContext:
      capabilities: {drop: ["ALL"]}
      allowPrivilegeEscalation: false
      seccompProfile: {type: RuntimeDefault}
    volumeMounts:
    - {name: docker-lib, mountPath: /var/lib/docker}
  volumes:
  - name: docker-lib
    emptyDir: {sizeLimit: 10Gi}
EOF
  scheduled=false
  for i in $(seq 1 30); do
    phase="$(kubectl get pod sysbox-e2e-test -n mindforge-labs -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ "$phase" == "Running" ]] && { scheduled=true; break; }
    [[ "$phase" == "Failed" ]] && break
    sleep 2
  done
  if [[ "$scheduled" != true ]]; then
    kubectl describe pod sysbox-e2e-test -n mindforge-labs || true
    kubectl delete pod sysbox-e2e-test -n mindforge-labs --ignore-not-found --now &>/dev/null
    error "Nested-docker test Pod never reached Running — see events above (common cause: no node labeled mindforge.io/sysbox=true)."
  fi
  # Same readiness check the actual course content uses (see
  # backend/db/fixtures/docker.generated.sql) — `docker info` succeeding
  # means the nested dockerd genuinely came up under sysbox, not just that
  # the outer Pod scheduled.
  docker_ready=false
  for i in $(seq 1 70); do
    kubectl exec sysbox-e2e-test -n mindforge-labs -- docker info &>/dev/null && { docker_ready=true; break; }
    sleep 1
  done
  kubectl delete pod sysbox-e2e-test -n mindforge-labs --ignore-not-found --now &>/dev/null
  [[ "$docker_ready" == true ]] || error "Nested dockerd never came up inside the sysbox Pod — the docker course would still fail for students."
  success "Nested-docker lab verified end-to-end — the docker course actually works."
else
  warn "Skipped nested-docker verification (sysbox not installed) — the docker course is NOT usable on this deploy yet."
fi

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Bootstrap complete and verified${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  App: https://mindforge.127.0.0.1.nip.io (accept the self-signed cert warning)"
[[ "$SYSBOX_READY" == true ]] && echo "  Nested-docker courses: verified working." || echo "  Nested-docker courses: NOT working yet (sysbox not installed)."
echo "  Lab images pushed to: ${LABS_IMAGE_REGISTRY} — set LABS_IMAGE_REGISTRY=${LABS_IMAGE_REGISTRY}"
echo "  in backend/.env (native hybrid dev) or k8s/overlays/local/configmap-domain.patch.yaml"
echo "  (in-cluster backend), then restart it, if not already set."
echo ""

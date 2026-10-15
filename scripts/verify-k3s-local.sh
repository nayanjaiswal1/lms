#!/usr/bin/env bash
# scripts/verify-k3s-local.sh — checks a local k3s deploy actually works (rollouts,
# backend /health, Gateway/HTTPRoute, nested-docker lab smoke test).
# Run by bootstrap-k3s-local.sh and by the Jenkins "Verify" stage. Safe to re-run.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

SYSBOX_READY=false
command -v sysbox-runc &>/dev/null && SYSBOX_READY=true
LABS_IMAGE_REGISTRY="${REGISTRY:-localhost:5000}"

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
